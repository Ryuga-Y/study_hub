import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no image URL, show error widgets immediately
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return FutureBuilder<bool>(
      future: _checkAuthAndLoadImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildPlaceholder();
        }

        if (snapshot.hasError || !(snapshot.data ?? false)) {
          print('🖼️ Image load error for $imageUrl: ${snapshot.error}');
          return _buildErrorWidget();
        }

        return CachedNetworkImage(
          imageUrl: imageUrl!,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
          errorWidget: (context, url, error) {
            // Suppress excessive logging for known 404 errors
            final errorString = error.toString().toLowerCase();

            // Handle specific HTTP errors
            if (errorString.contains('403')) {
              print('❌ 403 Forbidden - Check Firebase Storage rules for: ${url.substring(0, 50)}...');
              return _buildAuthErrorWidget();
            } else if (errorString.contains('404') || errorString.contains('not found')) {
              print('🗑️ 404 Not Found - Scheduling cleanup for broken image');
              // Automatically remove broken posts for 404 errors
              _handleBrokenImage(url);
              return _buildBrokenImageWidget();
            }

            print('🖼️ Image load error: ${errorString.substring(0, 100)}...');
            return _buildErrorWidget();
          },
          fadeInDuration: Duration(milliseconds: 300),
          fadeOutDuration: Duration(milliseconds: 300),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return errorWidget ?? Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: (height != null && height! < 100) ? 24 : 48,
            color: Colors.grey[400],
          ),
          if (height == null || height! >= 60) ...[
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildBrokenImageWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: (height != null && height! < 100) ? 24 : 48,
            color: Colors.orange[400],
          ),
          if (height == null || height! >= 60) ...[
            SizedBox(height: 8),
            Text(
              'Image removed',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[600],
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAuthErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: (height != null && height! < 100) ? 24 : 48,
            color: Colors.red[400],
          ),
          if (height == null || height! >= 60) ...[
            SizedBox(height: 8),
            Text(
              'Access denied',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }

  Future<bool> _checkAuthAndLoadImage() async {
    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated for image access');
        return false;
      }

      // Get fresh token
      await user.getIdToken(true);
      return true;
    } catch (e) {
      print('❌ Auth check failed: $e');
      return false;
    }
  }

  // Add this method before the final closing brace
  void _handleBrokenImage(String url) {
    // Extract post ID from Firebase Storage URL
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Look for posts folder in path
      int postsIndex = pathSegments.indexOf('posts');
      if (postsIndex != -1 && postsIndex + 2 < pathSegments.length) {
        String userId = pathSegments[postsIndex + 1];
        String fileName = pathSegments[postsIndex + 2];

        print('🗑️ Found broken image: userId=$userId, fileName=$fileName');

        // Schedule cleanup after current build cycle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleBrokenImageCleanup(url);
        });
      }
    } catch (e) {
      print('⚠️ Error parsing broken image URL: $e');
    }
  }

  void _scheduleBrokenImageCleanup(String imageUrl) {
    // This will run cleanup in background without affecting current UI
    Future.delayed(Duration(seconds: 2), () {
      _cleanupBrokenImagePost(imageUrl);
    });
  }

  Future<void> _cleanupBrokenImagePost(String imageUrl) async {
    try {
      // Find and delete posts with broken images
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('mediaUrls', arrayContains: imageUrl)
          .get();

      for (final doc in postsQuery.docs) {
        await doc.reference.delete();
        print('🗑️ Deleted post with broken image: ${doc.id}');
      }
    } catch (e) {
      print('⚠️ Error cleaning up broken image post: $e');
    }
  }
}
