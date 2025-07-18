import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_hub/community/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/models.dart';
import '../community/bloc.dart';

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
    if (widget.post.mediaUrls.length > 1) {
      _pageController = PageController();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
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
              _buildHeader(),

              // Caption
              if (widget.post.caption.isNotEmpty)
                _buildCaption(),

              // Media
              if (widget.post.mediaUrls.isNotEmpty)
                _buildMediaSection(),

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

  Widget _buildHeader() {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        final currentUserId = state.currentUserProfile?.uid;

        return Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: widget.post.userId,
                        isCurrentUser: widget.post.userId == currentUserId,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.post.userAvatar != null
                      ? CachedNetworkImageProvider(widget.post.userAvatar!)
                      : null,
                  child: widget.post.userAvatar == null
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: widget.post.userId,
                                  isCurrentUser: widget.post.userId == currentUserId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            widget.post.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (widget.post.isEdited)
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
                        Text(
                          timeago.format(widget.post.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          widget.post.privacy == PostPrivacy.public
                              ? Icons.public
                              : widget.post.privacy == PostPrivacy.friendsOnly
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

              // More button
              if (widget.post.userId == currentUserId &&
                  (widget.onDelete != null || widget.onEdit != null))
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[700]),
                  itemBuilder: (context) => [
                    if (widget.onEdit != null)
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
                    if (value == 'edit' && widget.onEdit != null) {
                      widget.onEdit!();
                    } else if (value == 'delete' && widget.onDelete != null) {
                      widget.onDelete!();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaption() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 12),
      child: Text(
        widget.post.caption,
        style: TextStyle(fontSize: 15),
        maxLines: widget.isDetailView ? null : 3,
        overflow: widget.isDetailView ? null : TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMediaSection() {
    if (widget.post.mediaUrls.length == 1) {
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
            itemCount: widget.post.mediaUrls.length,
            itemBuilder: (context, index) {
              return _buildSingleMedia(index);
            },
          ),
        ),

        // Page indicators
        if (widget.post.mediaUrls.length > 1)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.post.mediaUrls.length,
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
    final mediaUrl = widget.post.mediaUrls[index];
    final mediaType = widget.post.mediaTypes[index];

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
            onTap: widget.onShare,
          ),
        ],
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
                // Show emoji instead of icon for reactions
                Text(
                  label,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(width: 4),
                Text(
                  'React',
                  style: TextStyle(
                    fontSize: 14,
                    color: color ?? Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Icon(
                  icon,
                  size: 20,
                  color: color ?? Colors.grey[700],
                ),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color ?? Colors.grey[700],
                    fontWeight: FontWeight.w500,
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