import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:study_hub/community/poll_widget.dart';
import 'package:study_hub/community/post_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/bloc.dart';
import '../community/models.dart';
import 'edit_dialogs.dart';

class PostScreen extends StatefulWidget {
  final Post post;

  const PostScreen({Key? key, required this.post}) : super(key: key);

  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    // Load comments for this post
    context.read<CommunityBloc>().add(LoadComments(widget.post.id));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        final comments = state.postComments[widget.post.id] ?? [];
        final currentUserId = state.currentUserProfile?.uid;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: IconThemeData(color: Colors.black),
            title: Text(
              'Post',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              if (widget.post.userId == currentUserId)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit Post'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Post', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditPostDialog();
                    } else if (value == 'delete') {
                      _showDeletePostDialog();
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Post content
                      PostCard(
                        post: widget.post,
                        isDetailView: true,
                        onLike: () => context.read<CommunityBloc>().add(
                          ToggleLike(widget.post.id),
                        ),
                        onComment: () {
                          _commentFocusNode.requestFocus();
                        },
                        onShare: () {
                          // Implement share
                        },
                      ),if (widget.post.hasPoll && widget.post.pollId != null)
                        PollWidget(
                          pollId: widget.post.pollId!,
                          postId: widget.post.id,
                          isPostOwner: widget.post.userId == currentUserId,
                        ),

                      Divider(height: 1),

                      // Comments section
                      if (comments.isEmpty)
                        _buildEmptyComments()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return _buildCommentTile(comment, state);
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Comment input
              _buildCommentInput(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyComments() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to comment!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment, CommunityState state) {
    final isReply = comment.parentId != null;
    final currentUserId = state.currentUserProfile?.uid;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ).copyWith(
        left: isReply ? 48 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: isReply ? 16 : 20,
            backgroundImage: comment.userAvatar != null
                ? CachedNetworkImageProvider(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? Icon(Icons.person, size: isReply ? 16 : 20)
                : null,
          ),

          SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and time
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: TextStyle(fontSize: 14),
                ),

                SizedBox(height: 8),

                // Actions
                Row(
                  children: [
                    // Like button
                    InkWell(
                      onTap: () {
                        // Implement comment like
                      },
                      child: Row(
                        children: [
                          Icon(
                            comment.likedBy.contains(currentUserId)
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            size: 16,
                            color: comment.likedBy.contains(currentUserId)
                                ? Colors.red
                                : Colors.grey[600],
                          ),
                          if (comment.likeCount > 0) ...[
                            SizedBox(width: 4),
                            Text(
                              comment.likeCount.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(width: 16),

                    // Reply button
                    if (!isReply)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _replyingToCommentId = comment.id;
                            _replyingToUserName = comment.userName;
                          });
                          _commentFocusNode.requestFocus();
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    Spacer(),

                    // More options
                    if (comment.userId == currentUserId)
                      InkWell(
                        onTap: () => _showCommentOptions(comment),
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(CommunityState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Column(
        children: [
          if (_replyingToCommentId != null)
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    'Replying to $_replyingToUserName',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  Spacer(),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _replyingToCommentId = null;
                        _replyingToUserName = null;
                      });
                    },
                    child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 18,
                backgroundImage: state.currentUserProfile?.avatarUrl != null
                    ? CachedNetworkImageProvider(
                    state.currentUserProfile!.avatarUrl!)
                    : null,
                child: state.currentUserProfile?.avatarUrl == null
                    ? Icon(Icons.person, size: 18)
                    : null,
              ),

              SizedBox(width: 12),

              // Input field
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send, color: Colors.purple[600]),
                      onPressed: _postComment,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _postComment(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _postComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    context.read<CommunityBloc>().add(AddComment(
      postId: widget.post.id,
      content: text,
      parentId: _replyingToCommentId,
    ));

    _commentController.clear();
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });

    FocusScope.of(context).unfocus();
  }

  void _showCommentOptions(Comment comment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Comment', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteCommentDialog(comment);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentDialog(Comment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Comment'),
        content: Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CommunityBloc>().add(DeleteComment(
                commentId: comment.id,
                postId: widget.post.id,
              ));
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog() {
    showDialog(
      context: context,
      builder: (context) => EnhancedEditPostDialog(post: widget.post),
    );
  }

  void _showDeletePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CommunityBloc>().add(DeletePost(widget.post.id));
              Navigator.pop(context);
              Navigator.pop(context); // Go back to feed
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}