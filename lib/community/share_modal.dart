import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models.dart';
import 'bloc.dart';

class SharePostModal extends StatefulWidget {
  final Post post;

  const SharePostModal({Key? key, required this.post}) : super(key: key);

  @override
  _SharePostModalState createState() => _SharePostModalState();
}

class _SharePostModalState extends State<SharePostModal> {
  final TextEditingController _commentController = TextEditingController();
  PostPrivacy _selectedPrivacy = PostPrivacy.public;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Share Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                BlocBuilder<CommunityBloc, CommunityState>(
                  builder: (context, state) {
                    return TextButton(
                      onPressed: state.isCreatingPost ? null : _sharePost,
                      child: state.isCreatingPost
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comment section
                  Text(
                    'Add a comment (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'What do you want to say about this?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Privacy section
                  Text(
                    'Who can see this?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildPrivacyOptions(),

                  SizedBox(height: 24),

                  // Original post preview
                  Text(
                    'Sharing this post:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildPostPreview(),

                  SizedBox(height: 24),

                  // Share externally section
                  Divider(),
                  SizedBox(height: 16),
                  Text(
                    'Share outside the app',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildExternalShareButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOptions() {
    return Column(
      children: [
        _buildPrivacyOption(
          icon: Icons.public,
          title: 'Public',
          subtitle: 'Anyone in your organization can see this',
          privacy: PostPrivacy.public,
        ),
        _buildPrivacyOption(
          icon: Icons.people,
          title: 'Friends',
          subtitle: 'Only your friends can see this',
          privacy: PostPrivacy.friendsOnly,
        ),
        _buildPrivacyOption(
          icon: Icons.lock,
          title: 'Only me',
          subtitle: 'Only you can see this',
          privacy: PostPrivacy.private,
        ),
      ],
    );
  }

  Widget _buildPrivacyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required PostPrivacy privacy,
  }) {
    final isSelected = _selectedPrivacy == privacy;

    return InkWell(
      onTap: () => setState(() => _selectedPrivacy = privacy),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue[50] : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey[600],
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.post.userAvatar != null
                    ? CachedNetworkImageProvider(widget.post.userAvatar!)
                    : null,
                child: widget.post.userAvatar == null
                    ? Icon(Icons.person, size: 16)
                    : null,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        widget.post.privacy == PostPrivacy.public
                            ? Icons.public
                            : widget.post.privacy == PostPrivacy.friendsOnly
                            ? Icons.people
                            : Icons.lock,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        _getPrivacyLabel(widget.post.privacy),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Caption
          if (widget.post.caption.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              widget.post.caption,
              style: TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Media preview
          if (widget.post.mediaUrls.isNotEmpty) ...[
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: widget.post.mediaTypes.first == MediaType.video
                    ? Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                )
                    : CachedNetworkImage(
                  imageUrl: widget.post.mediaUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.post.mediaUrls.length > 1)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '+${widget.post.mediaUrls.length - 1} more',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildExternalShareButton() {
    return Container(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<CommunityBloc>().add(ExternalSharePost(widget.post));
        },
        icon: Icon(Icons.share_outlined),
        label: Text('Share to other apps'),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _getPrivacyLabel(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return 'Public';
      case PostPrivacy.friendsOnly:
        return 'Friends';
      case PostPrivacy.private:
        return 'Private';
    }
  }

  void _sharePost() {
    final comment = _commentController.text.trim();

    context.read<CommunityBloc>().add(
      SharePost(
        postId: widget.post.id,
        comment: comment.isEmpty ? null : comment,
        privacy: _selectedPrivacy,
      ),
    );

    Navigator.pop(context);
  }
}