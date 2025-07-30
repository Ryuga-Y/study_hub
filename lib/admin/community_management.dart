import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart'; // Add this dependency

import '../community/bloc.dart';
import '../community/models.dart';

class CommunityManagementScreen extends StatefulWidget {
  final String organizationCode;

  const CommunityManagementScreen({
    Key? key,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _CommunityManagementScreenState createState() => _CommunityManagementScreenState();
}

class _CommunityManagementScreenState extends State<CommunityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data
    context.read<CommunityBloc>().add(LoadReportedPosts(organizationCode: widget.organizationCode));
    context.read<CommunityBloc>().add(LoadHiddenPosts(organizationCode: widget.organizationCode));
    context.read<CommunityBloc>().add(LoadAnalytics(organizationCode: widget.organizationCode));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Community Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Reported Posts'),
            Tab(text: 'Hidden Posts'),
            Tab(text: 'Analytics'),
          ],
          labelColor: Colors.purple[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.purple[600],
        ),
      ),
      body: BlocConsumer<CommunityBloc, CommunityState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildReportedPostsTab(state),
              _buildHiddenPostsTab(state),
              _buildAnalyticsTab(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportedPostsTab(CommunityState state) {
    if (state.reportedPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.flag_outlined,
        title: 'No Reported Posts',
        subtitle: 'All clear! No posts have been reported.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: state.reportedPosts.length,
      itemBuilder: (context, index) {
        final report = state.reportedPosts[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildHiddenPostsTab(CommunityState state) {
    if (state.hiddenPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.visibility_off_outlined,
        title: 'No Hidden Posts',
        subtitle: 'No posts are currently hidden.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: state.hiddenPosts.length,
      itemBuilder: (context, index) {
        final post = state.hiddenPosts[index];
        return _buildHiddenPostCard(post);
      },
    );
  }

  Widget _buildAnalyticsTab(CommunityState state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Posts',
                  value: state.analytics['totalPosts']?.toString() ?? '0',
                  icon: Icons.post_add,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Reports',
                  value: state.analytics['totalReports']?.toString() ?? '0',
                  icon: Icons.flag,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Valid Reports',
                  value: state.analytics['validReports']?.toString() ?? '0',
                  icon: Icons.check_circle,
                  color: Colors.red,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Invalid Reports',
                  value: state.analytics['invalidReports']?.toString() ?? '0',
                  icon: Icons.cancel,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildAnalyticsCard(
            title: 'Pending Reports',
            value: state.analytics['pendingReports']?.toString() ?? '0',
            icon: Icons.pending,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  // 🆕 ENHANCED: Report card with media display
  Widget _buildReportCard(PostReport report) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report header
            Row(
              children: [
                Icon(Icons.flag, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'Report #${report.id.substring(0, 8)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Reporter info
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: report.reporterAvatar != null
                      ? CachedNetworkImageProvider(report.reporterAvatar!)
                      : null,
                  child: report.reporterAvatar == null
                      ? Icon(Icons.person, size: 16)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported by ${report.reporterName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeago.format(report.reportedAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Report details
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason: ${report.reason}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (report.details.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      report.details,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),

            // 🆕 ENHANCED: Reported post preview with media
            if (report.post != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post author info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: report.post!.userAvatar != null
                              ? CachedNetworkImageProvider(report.post!.userAvatar!)
                              : null,
                          child: report.post!.userAvatar == null
                              ? Icon(Icons.person, size: 12)
                              : null,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Post by ${report.post!.userName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Text(
                          timeago.format(report.post!.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    if (report.post!.caption.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        report.post!.caption,
                        style: TextStyle(fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 🆕 NEW: Display post media
                    if (report.post!.mediaUrls.isNotEmpty) ...[
                      SizedBox(height: 12),
                      _buildPostMediaGrid(report.post!),
                    ],

                    // Post engagement stats
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: Colors.red),
                        SizedBox(width: 4),
                        Text('${report.post!.likeCount}', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 16),
                        Icon(Icons.comment, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('${report.post!.commentCount}', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 16),
                        Icon(Icons.share, size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('${report.post!.shareCount}', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Admin actions
            if (report.status == 'pending') ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(report, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Mark Invalid', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showReviewDialog(report, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Mark Valid', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],

            // Review details (if already reviewed)
            if (report.status != 'pending') ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reviewed by ${report.reviewerName ?? 'Admin'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (report.reviewedAt != null) ...[
                      SizedBox(height: 4),
                      Text(
                        timeago.format(report.reviewedAt!),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (report.adminNotes != null && report.adminNotes!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'Notes: ${report.adminNotes}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🆕 NEW: Build media grid for posts
  Widget _buildPostMediaGrid(Post post) {
    if (post.mediaUrls.isEmpty) return SizedBox.shrink();

    // Show up to 4 media items in a grid, with "+" indicator for more
    final displayCount = post.mediaUrls.length > 4 ? 4 : post.mediaUrls.length;
    final hasMore = post.mediaUrls.length > 4;

    return Container(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: displayCount > 2 ? 2 : displayCount,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: displayCount,
              itemBuilder: (context, index) {
                final isLastItem = index == displayCount - 1 && hasMore;
                return _buildMediaItem(
                  post.mediaUrls[index],
                  post.mediaTypes.length > index ? post.mediaTypes[index] : MediaType.image,
                  isLastItem ? post.mediaUrls.length - displayCount : null,
                      () => _showFullScreenMedia(post, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 NEW: Build individual media item
  Widget _buildMediaItem(String mediaUrl, MediaType mediaType, int? moreCount, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mediaType == MediaType.image
                  ? CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[600]),
                ),
              )
                  : _buildVideoThumbnail(mediaUrl),
            ),

            // Video play icon
            if (mediaType == MediaType.video)
              Center(
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
                ),
              ),

            // More items indicator
            if (moreCount != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black54,
                ),
                child: Center(
                  child: Text(
                    '+$moreCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🆕 NEW: Build video thumbnail
  Widget _buildVideoThumbnail(String videoUrl) {
    return Container(
      color: Colors.grey[300],
      child: Stack(
        fit: StackFit.expand,
        children: [
          // You can implement video thumbnail extraction here
          // For now, showing a placeholder
          Icon(Icons.video_library, color: Colors.grey[600], size: 32),
          Center(
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 NEW: Show full screen media viewer
  void _showFullScreenMedia(Post post, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMediaViewer(
          mediaUrls: post.mediaUrls,
          mediaTypes: post.mediaTypes,
          initialIndex: initialIndex,
          postAuthor: post.userName,
          postCaption: post.caption,
        ),
      ),
    );
  }

  Widget _buildHiddenPostCard(Post post) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hidden post header
            Row(
              children: [
                Icon(Icons.visibility_off, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Hidden Post',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                if (post.hiddenAt != null)
                  Text(
                    'Hidden ${timeago.format(post.hiddenAt!)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Post author info
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: post.userAvatar != null
                      ? CachedNetworkImageProvider(post.userAvatar!)
                      : null,
                  child: post.userAvatar == null
                      ? Icon(Icons.person, size: 16)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By ${post.userName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Posted ${timeago.format(post.createdAt)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Post content
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption.isNotEmpty) ...[
                    Text(
                      post.caption,
                      style: TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // 🆕 ENHANCED: Display media for hidden posts too
                  if (post.mediaUrls.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildPostMediaGrid(post),
                  ],
                ],
              ),
            ),

            // Hidden reason
            if (post.hiddenReason != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hidden Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      post.hiddenReason!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Admin actions
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showUnhideDialog(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Unhide Post', style: TextStyle(color: Colors.white)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDeleteDialog(post),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Delete Permanently', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'valid':
        return Colors.red;
      case 'invalid':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showReviewDialog(PostReport report, bool isValid) {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isValid ? 'Mark Report as Valid' : 'Mark Report as Invalid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isValid
                  ? 'This will delete the post and mark the report as valid.'
                  : 'This will hide the post and mark the report as invalid.',
            ),
            SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Admin Notes',
                hintText: 'Reason for this decision...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommunityBloc>().add(
                ReviewReport(
                  reportId: report.id,
                  postId: report.postId,
                  isValid: isValid,
                  adminNotes: notesController.text.trim(),
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.red : Colors.grey[600],
            ),
            child: Text(
              isValid ? 'Delete Post' : 'Hide Post',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnhideDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unhide Post'),
        content: Text('Are you sure you want to unhide this post? It will be visible in the feed again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommunityBloc>().add(UnhidePost(postId: post.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Unhide', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post Permanently'),
        content: Text(
          'Are you sure you want to permanently delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommunityBloc>().add(
                AdminDeletePost(
                  postId: post.id,
                  reason: 'Permanently deleted from hidden posts management',
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// 🆕 NEW: Full screen media viewer
class FullScreenMediaViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final List<MediaType> mediaTypes;
  final int initialIndex;
  final String postAuthor;
  final String postCaption;

  const FullScreenMediaViewer({
    Key? key,
    required this.mediaUrls,
    required this.mediaTypes,
    required this.initialIndex,
    required this.postAuthor,
    required this.postCaption,
  }) : super(key: key);

  @override
  _FullScreenMediaViewerState createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  Map<int, VideoPlayerController?> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialize video controller for the first video if needed
    _initializeVideoController(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoControllers.values.forEach((controller) {
      controller?.dispose();
    });
    super.dispose();
  }

  void _initializeVideoController(int index) {
    if (index < widget.mediaTypes.length &&
        widget.mediaTypes[index] == MediaType.video &&
        !_videoControllers.containsKey(index)) {

      final controller = VideoPlayerController.network(widget.mediaUrls[index]);
      _videoControllers[index] = controller;

      controller.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} of ${widget.mediaUrls.length}',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _initializeVideoController(index);
            },
            itemBuilder: (context, index) {
              final mediaType = index < widget.mediaTypes.length
                  ? widget.mediaTypes[index]
                  : MediaType.image;

              if (mediaType == MediaType.image) {
                return InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: widget.mediaUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text('Failed to load image', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return _buildVideoPlayer(index);
              }
            },
          ),

          // Bottom info panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Posted by ${widget.postAuthor}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (widget.postCaption.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      widget.postCaption,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(int index) {
    final controller = _videoControllers[index];

    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 64,
          ),
        ),
      ],
    );
  }
}