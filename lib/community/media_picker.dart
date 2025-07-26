import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class MediaPicker extends StatefulWidget {
  final List<File> selectedMedia;
  final List<MediaType> mediaTypes;
  final Function(List<File>, List<MediaType>) onMediaSelected;
  final int maxMedia;

  const MediaPicker({
    Key? key,
    required this.selectedMedia,
    required this.mediaTypes,
    required this.onMediaSelected,
    this.maxMedia = 10,
  }) : super(key: key);

  @override
  _MediaPickerState createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    if (widget.selectedMedia.length >= widget.maxMedia) {
      _showMaxMediaAlert();
      return;
    }

    try {
      if (isVideo) {
        final XFile? video = await _picker.pickVideo(source: source);
        if (video != null) {
          _addMedia(File(video.path), MediaType.video);
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (image != null) {
          _addMedia(File(image.path), MediaType.image);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking media: $e')),
      );
    }
  }

  Future<void> _pickMultipleImages() async {
    if (widget.selectedMedia.length >= widget.maxMedia) {
      _showMaxMediaAlert();
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      final remainingSlots = widget.maxMedia - widget.selectedMedia.length;
      final imagesToAdd = images.take(remainingSlots).toList();

      if (imagesToAdd.isNotEmpty) {
        final List<File> newMedia = List.from(widget.selectedMedia);
        final List<MediaType> newTypes = List.from(widget.mediaTypes);

        for (final image in imagesToAdd) {
          newMedia.add(File(image.path));
          newTypes.add(MediaType.image);
        }

        widget.onMediaSelected(newMedia, newTypes);
      }

      if (images.length > remainingSlots) {
        _showMaxMediaAlert();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _addMedia(File file, MediaType type) {
    final List<File> newMedia = List.from(widget.selectedMedia)..add(file);
    final List<MediaType> newTypes = List.from(widget.mediaTypes)..add(type);
    widget.onMediaSelected(newMedia, newTypes);
  }

  void _removeMedia(int index) {
    final List<File> newMedia = List.from(widget.selectedMedia)..removeAt(index);
    final List<MediaType> newTypes = List.from(widget.mediaTypes)..removeAt(index);
    widget.onMediaSelected(newMedia, newTypes);
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final List<File> newMedia = List.from(widget.selectedMedia);
    final List<MediaType> newTypes = List.from(widget.mediaTypes);

    final File media = newMedia.removeAt(oldIndex);
    final MediaType type = newTypes.removeAt(oldIndex);

    newMedia.insert(newIndex, media);
    newTypes.insert(newIndex, type);

    widget.onMediaSelected(newMedia, newTypes);
  }

  void _showMaxMediaAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.maxMedia} media items allowed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selectedMedia.isEmpty)
          _buildMediaButtons()
        else
          _buildSelectedMedia(),
      ],
    );
  }

  Widget _buildMediaButtons() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMediaOption(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: () => _showMediaOptions(ImageSource.gallery),
            ),
            _buildMediaOption(
              icon: Icons.camera_alt,
              label: 'Camera',
              onTap: () => _showMediaOptions(ImageSource.camera),
            ),
            _buildMediaOption(
              icon: Icons.collections,
              label: 'Multiple',
              onTap: _pickMultipleImages,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.purple[600]),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMedia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media grid
        Container(
          height: 120,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.selectedMedia.length,
            onReorder: _reorderMedia,
            itemBuilder: (context, index) {
              return _buildMediaThumbnail(index);
            },
          ),
        ),

        SizedBox(height: 16),

        // Add more button
        if (widget.selectedMedia.length < widget.maxMedia)
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _showAddMediaOptions(),
              icon: Icon(Icons.add_photo_alternate),
              label: Text('Add More'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.purple[600]!),
                foregroundColor: Colors.purple[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaThumbnail(int index) {
    final file = widget.selectedMedia[index];
    final type = widget.mediaTypes[index];

    return Container(
      key: ValueKey(file.path),
      width: 120,
      margin: EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          // Thumbnail
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: type == MediaType.image
                  ? Image.file(
                file,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              )
                  : Container(
                width: 120,
                height: 120,
                color: Colors.black87,
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Media type indicator
          if (type == MediaType.video)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Reorder handle
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.drag_handle,
                size: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaOptions(ImageSource source) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo),
            title: Text('Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(source);
            },
          ),
          ListTile(
            leading: Icon(Icons.videocam),
            title: Text('Video'),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(source, isVideo: true);
            },
          ),
        ],
      ),
    );
  }

  void _showAddMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _showMediaOptions(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take Photo/Video'),
            onTap: () {
              Navigator.pop(context);
              _showMediaOptions(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.collections),
            title: Text('Select Multiple'),
            onTap: () {
              Navigator.pop(context);
              _pickMultipleImages();
            },
          ),
        ],
      ),
    );
  }
}

// Simple media grid for selecting from gallery
class MediaGalleryPicker extends StatelessWidget {
  final Function(List<File>, List<MediaType>) onMediaSelected;
  final int maxSelection;

  const MediaGalleryPicker({
    Key? key,
    required this.onMediaSelected,
    this.maxSelection = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This would typically integrate with platform-specific media galleries
    // For now, returning a placeholder
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Media'),
        actions: [
          TextButton(
            onPressed: () {
              // Handle selection
              Navigator.pop(context);
            },
            child: Text('Done'),
          ),
        ],
      ),
      body: Center(
        child: Text('Media gallery picker implementation'),
      ),
    );
  }
}