import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_hub/community/poll_widget.dart';
import 'package:study_hub/community/profile_screen.dart';
import 'package:study_hub/community/share_modal.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/models.dart';
import '../community/bloc.dart';
import 'edit_dialogs.dart';


class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isDetailView;

  const PostCard({
    Key? key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onDelete,
    this.onEdit,
    this.isDetailView = false,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  PageController? _pageController;
  int _currentPage = 0;
  bool _showReactions = false;

  @override
  void initState() {
    super.initState();
    final mediaUrls = _getMediaUrls();
    if (mediaUrls.length > 1) {
      _pageController = PageController();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  // Helper method to get media URLs from either repost or original post
  List<String> _getMediaUrls() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.mediaUrls;
    }
    return widget.post.mediaUrls;
  }

  // Helper method to get media types from either repost or original post
  List<MediaType> _getMediaTypes() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.mediaTypes;
    }
    return widget.post.mediaTypes;
  }

  // Helper method to get the correct avatar
  ImageProvider? _getPostAvatar() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.userAvatar != null
          ? CachedNetworkImageProvider(widget.post.originalPost!.userAvatar!)
          : null;
    }
    return widget.post.userAvatar != null
        ? CachedNetworkImageProvider(widget.post.userAvatar!)
        : null;
  }

  // Helper method to get the correct user name
  String _getPostUserName() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.userName;
    }
    return widget.post.userName;
  }

  // Helper method to get the correct user ID
  String _getPostUserId() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.userId;
    }
    return widget.post.userId;
  }

  // Helper method to get the correct caption
  String _getPostCaption() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.caption;
    }
    return widget.post.caption;
  }

  // Helper method to get the correct created date
  DateTime _getPostCreatedAt() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.createdAt;
    }
    return widget.post.createdAt;
  }

  // Helper method to get the correct privacy
  PostPrivacy _getPostPrivacy() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.privacy;
    }
    return widget.post.privacy;
  }

  // Helper method to check if the post is edited
  bool _isPostEdited() {
    if (widget.post.isRepost && widget.post.originalPost != null) {
      return widget.post.originalPost!.isEdited;
    }
    return widget.post.isEdited;
  }

  // 🆕 NEW: Helper method to check if user is a friend
  bool _isUserFriend(CommunityState state) {
    final postUserId = _getPostUserId();
    final currentUserId = state.currentUserProfile?.uid;

    // If it's the current user's post, don't show friend tag
    if (postUserId == currentUserId) {
      return false;
    }

    // Check if the post author is in the current user's friends list
    return state.friends.any((friend) => friend.friendId == postUserId);
  }

  bool _shouldRoundBottom() {
    final hasMedia = _getMediaUrls().isNotEmpty;
    final hasOriginalPostPoll = widget.post.originalPost != null &&
        widget.post.originalPost!.hasPoll &&
        widget.post.originalPost!.pollId != null;

    // If there's a poll after media, don't round the bottom of media
    return !hasOriginalPostPoll;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        final currentUserId = state.currentUserProfile?.uid;

        return Container(
          color: Colors.white,
          margin: EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(state),

              // Repost comment (if it's a repost with a comment)
              if (widget.post.isRepost &&
                  widget.post.repostComment != null &&
                  widget.post.repostComment!.isNotEmpty)
                _buildRepostComment(),

              // Original post container for reposts
              if (widget.post.isRepost)
                _buildOriginalPostContainer(),

              // Regular post content (for non-reposts)
              if (!widget.post.isRepost) ...[
                // Caption
                if (_getPostCaption().isNotEmpty)
                  _buildCaption(),

                // Media
                if (_getMediaUrls().isNotEmpty)
                  _buildMediaSection(),

                // Poll Widget for regular posts
                if (widget.post.hasPoll && widget.post.pollId != null)
                  PollWidget(
                    pollId: widget.post.pollId!,
                    postId: widget.post.id,
                    isPostOwner: widget.post.userId == currentUserId,
                  ),
              ],

              // Poll Widget for reposts (check original post)
              if (widget.post.isRepost &&
                  widget.post.originalPost != null &&
                  widget.post.originalPost!.hasPoll &&
                  widget.post.originalPost!.pollId != null)
                PollWidget(
                  pollId: widget.post.originalPost!.pollId!,
                  postId: widget.post.originalPost!.id,
                  isPostOwner: widget.post.originalPost!.userId == currentUserId,
                ),

              // Stats
              _buildStats(),

              // Actions
              _buildActions(currentUserId),

              // Reactions overlay
              if (_showReactions)
                _buildReactionsOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(CommunityState state) {
    final currentUserId = state.currentUserProfile?.uid;
    final isUserFriend = _isUserFriend(state); // 🆕 Check if user is friend

    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show repost indicator
          if (widget.post.isRepost) ...[
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  '${widget.post.userName} shared',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],

          // Original post info (or regular post info if not a repost)
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () {
                  final userToNavigate = _getPostUserId();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: userToNavigate,
                        isCurrentUser: userToNavigate == currentUserId,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: _getPostAvatar(),
                  child: _getPostAvatar() == null
                      ? Icon(Icons.person)
                      : null,
                ),
              ),

              SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final userToNavigate = _getPostUserId();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: userToNavigate,
                                  isCurrentUser: userToNavigate == currentUserId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            _getPostUserName(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),

                        // 🆕 NEW: Friend tag
                        if (isUserFriend) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 12,
                                  color: Colors.blue[600],
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Friend',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(width: 8),
                        if (_isPostEdited())
                          Text(
                            '• edited',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        if (!widget.post.isRepost) // Don't show time for reposts here (shown above)
                          Text(
                            timeago.format(_getPostCreatedAt()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (!widget.post.isRepost)
                          SizedBox(width: 8),
                        Icon(
                          _getPostPrivacy() == PostPrivacy.public
                              ? Icons.public
                              : _getPostPrivacy() == PostPrivacy.friendsOnly
                              ? Icons.people
                              : Icons.lock,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // More button (only for the current user's posts)
              if (widget.post.userId == currentUserId &&
                  (widget.onDelete != null || widget.onEdit != null))
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[700]),
                  itemBuilder: (context) => [
                    if (widget.onEdit != null && !widget.post.isRepost)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    if (widget.onDelete != null)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEnhancedEditDialog(context, widget.post);
                    } else if (value == 'delete' && widget.onDelete != null) {
                      widget.onDelete!();
                    }
                  },
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepostComment() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 12),
      child: Text(
        widget.post.repostComment!,
        style: TextStyle(fontSize: 15),
        maxLines: widget.isDetailView ? null : 3,
        overflow: widget.isDetailView ? null : TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildOriginalPostContainer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original post caption
          if (_getPostCaption().isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                _getPostCaption(),
                style: TextStyle(fontSize: 15),
                maxLines: widget.isDetailView ? null : 3,
                overflow: widget.isDetailView ? null : TextOverflow.ellipsis,
              ),
            ),

          // Original post media
          if (_getMediaUrls().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: _shouldRoundBottom() ? Radius.circular(12) : Radius.zero,
                bottomRight: _shouldRoundBottom() ? Radius.circular(12) : Radius.zero,
                topLeft: _getPostCaption().isEmpty ? Radius.circular(12) : Radius.zero,
                topRight: _getPostCaption().isEmpty ? Radius.circular(12) : Radius.zero,
              ),
              child: _buildMediaSection(),
            ),

          // 🆕 NEW: Poll Widget for original post in repost
          if (widget.post.originalPost != null &&
              widget.post.originalPost!.hasPoll &&
              widget.post.originalPost!.pollId != null)
            Padding(
              padding: EdgeInsets.all(8),
              child: PollWidget(
                pollId: widget.post.originalPost!.pollId!,
                postId: widget.post.originalPost!.id,
                isPostOwner: false, // User can't be owner of original post in repost context
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 12),
      child: Text(
        _getPostCaption(),
        style: TextStyle(fontSize: 15),
        maxLines: widget.isDetailView ? null : 3,
        overflow: widget.isDetailView ? null : TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMediaSection() {
    final mediaUrls = _getMediaUrls();
    final mediaTypes = _getMediaTypes();

    if (mediaUrls.length == 1) {
      return _buildSingleMedia(0);
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: mediaUrls.length,
            itemBuilder: (context, index) {
              return _buildSingleMedia(index);
            },
          ),
        ),

        // Page indicators
        if (mediaUrls.length > 1)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                mediaUrls.length,
                    (index) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.purple[600]
                        : Colors.grey[300],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleMedia(int index) {
    final mediaUrls = _getMediaUrls();
    final mediaTypes = _getMediaTypes();

    final mediaUrl = mediaUrls[index];
    final mediaType = mediaTypes[index];

    if (mediaType == MediaType.video) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onDoubleTap: widget.onLike,
      child: CachedNetworkImage(
        imageUrl: mediaUrl,
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
    );
  }

  Widget _buildStats() {
    if (widget.post.likeCount == 0 && widget.post.commentCount == 0) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (widget.post.likeCount > 0) ...[
            // Show reaction emojis
            if (widget.post.reactions.isNotEmpty)
              Row(
                children: [
                  // Show up to 3 most used reactions
                  ...widget.post.reactions.entries
                      .toList()
                      .take(3)
                      .map((entry) => Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(entry.key, style: TextStyle(fontSize: 16)),
                  )),
                  SizedBox(width: 4),
                ],
              ),
            Text(
              '${widget.post.likeCount}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          Spacer(),
          if (widget.post.commentCount > 0)
            Text(
              '${widget.post.commentCount} comment${widget.post.commentCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(String? currentUserId) {
    final userReaction = currentUserId != null
        ? widget.post.userReactions[currentUserId]
        : null;
    final hasReacted = userReaction != null;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Like/React button
          _buildActionButton(
            icon: hasReacted ? Icons.favorite : Icons.favorite_outline,
            label: hasReacted ? userReaction : 'Like',
            color: hasReacted ? Colors.red : null,
            showEmoji: hasReacted,
            onTap: () {
              // Quick tap toggles current reaction or adds default like
              if (hasReacted) {
                // Remove reaction by sending the same reaction
                context.read<CommunityBloc>().add(
                  AddReaction(postId: widget.post.id, reaction: userReaction),
                );
              } else {
                // Add default like
                widget.onLike();
              }
            },
            onLongPress: () {
              setState(() => _showReactions = true);
            },
          ),

          // Comment button
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'Comment',
            onTap: widget.onComment,
          ),

          // Share button
          _buildActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SharePostModal(post: widget.post),
              );
            },
          ),

          // Report button - NEW (don't show for own posts)
          if (widget.post.userId != currentUserId)
            _buildActionButton(
              icon: Icons.flag_outlined,
              label: 'Report',
              onTap: () => _showReportDialog(context),
            ),
        ],
      ),
    );
  }

  void _showEnhancedEditDialog(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => EnhancedEditPostDialog(post: post),
    );
  }

  void _showReportDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'inappropriate';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Report Post'),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you reporting this post?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),
                // Reason dropdown
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'inappropriate',
                      child: Text('Inappropriate content'),
                    ),
                    DropdownMenuItem(
                      value: 'spam',
                      child: Text('Spam or misleading'),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text('Harassment or bullying'),
                    ),
                    DropdownMenuItem(
                      value: 'violence',
                      child: Text('Violence or dangerous content'),
                    ),
                    DropdownMenuItem(
                      value: 'misinformation',
                      child: Text('False information'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedReason = value);
                    }
                  },
                ),
                SizedBox(height: 16),
                // Additional details
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Additional details (optional)',
                    hintText: 'Please provide more information...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'False reports may result in action being taken against your account.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _submitReport(
                  context,
                  selectedReason,
                  reasonController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport(BuildContext context, String reason, String details) {
    context.read<CommunityBloc>().add(
      ReportPost(
        postId: widget.post.id,
        reason: reason,
        details: details,
      ),
    );
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Report submitted. Thank you for helping keep our community safe.'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? color,
    bool showEmoji = false,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showEmoji && label != 'Like') ...[
                // Use Flexible for emoji + text combination
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'React',
                          style: TextStyle(
                            fontSize: 14,
                            color: color ?? Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Use Flexible for icon + text combination
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: color ?? Colors.grey[700],
                      ),
                      SizedBox(width: 6), // Reduced spacing
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: color ?? Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showReactions = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ReactionType.all.map((reaction) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _showReactions = false);
                    // Handle reaction selection
                    context.read<CommunityBloc>().add(
                      AddReaction(postId: widget.post.id, reaction: reaction),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reaction,
                          style: TextStyle(fontSize: 28),
                        ),
                        // Show count if exists
                        if (widget.post.reactions[reaction] != null)
                          Text(
                            '${widget.post.reactions[reaction]!.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}