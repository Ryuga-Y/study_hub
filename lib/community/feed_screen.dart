import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:study_hub/community/post_card.dart';
import '../community/bloc.dart';
import '../community/models.dart';
import '../Authentication/auth_services.dart';
import 'media_picker.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../chat_integrated.dart';

class FeedScreen extends StatefulWidget {
  final String organizationCode;

  const FeedScreen({Key? key, required this.organizationCode}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFeed();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeFeed() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      final bloc = context.read<CommunityBloc>();

      // Load user profile first
      bloc.add(LoadUserProfile(user.uid));

      // Wait a bit for user profile to load, then load other data
      await Future.delayed(Duration(milliseconds: 499));

      _loadInitialData();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing feed: $e');
      _showError('Error initializing feed: $e');
    }
  }

  void _loadInitialData() {
    final bloc = context.read<CommunityBloc>();

    // Only load if we have an organization code
    if (widget.organizationCode.isNotEmpty) {
      bloc.add(LoadFeed(organizationCode: widget.organizationCode));
      bloc.add(LoadNotifications());
      bloc.add(LoadFriends());
      bloc.add(LoadPendingRequests());
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onScroll() {
    if (_isBottom && !context.read<CommunityBloc>().state.isLoadingMore) {
      context.read<CommunityBloc>().add(LoadMoreFeed());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
              ),
              SizedBox(height: 16),
              Text(
                'Loading community...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlocConsumer<CommunityBloc, CommunityState>(
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
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildFeedTab(state),                    // Index 0 - Home
              SearchScreen(organizationCode: widget.organizationCode), // Index 1 - Search
              ProfileScreen(                          // Index 2 - Profile (moved from index 3)
                userId: state.currentUserProfile?.uid ?? _authService.currentUser?.uid ?? '',
                isCurrentUser: true,
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavBar(state),
          floatingActionButton: _currentIndex == 0 ? _buildCreatePostButton() : null,
        );
      },
    );
  }

  Widget _buildFeedTab(CommunityState state) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'Study Hub',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                );
              },
            ),
            Spacer(),
            // Chat icon - ADD THIS BEFORE THE NOTIFICATION ICON
            IconButton(
              icon: Icon(Icons.chat_bubble_outline),
              color: Colors.black87,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatContactPage(),
                  ),
                );
              },
            ),

            // Notification icon (existing code)
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined),
                  color: Colors.black87,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchScreen(
                          organizationCode: widget.organizationCode,
                          initialTab: SearchScreenTab.notifications,
                        ),
                      ),
                    );
                  },
                ),
                if (state.unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        state.unreadNotificationCount > 99
                            ? '99+'
                            : state.unreadNotificationCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<CommunityBloc>().add(
              LoadFeed(organizationCode: widget.organizationCode, refresh: true)
          );
          await Future.delayed(Duration(seconds: 1));
        },
        child: state.isLoadingFeed && state.feedPosts.isEmpty
            ? Center(child: CircularProgressIndicator())
            : state.feedPosts.isEmpty
            ? _buildEmptyFeed()
            : ListView.builder(
          controller: _scrollController,
          itemCount: state.feedPosts.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.feedPosts.length) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final post = state.feedPosts[index];
            return PostCard(
              post: post,
              onLike: () => context.read<CommunityBloc>().add(ToggleLike(post.id)),
              onComment: () {
                // Navigate to post detail screen
                Navigator.pushNamed(
                  context,
                  '/post',
                  arguments: post,
                );
              },
              onShare: () {
                // Implement share functionality
              },
              onDelete: post.userId == state.currentUserProfile?.uid
                  ? () => _showDeletePostDialog(context, post.id)
                  : null,
              onEdit: post.userId == state.currentUserProfile?.uid
                  ? () => _showEditPostDialog(context, post)
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyFeed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePostModal,
            icon: Icon(Icons.add_photo_alternate),
            label: Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(CommunityState state) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.purple[600],
      unselectedItemColor: Colors.grey[600],
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: state.currentUserProfile?.avatarUrl != null
              ? CircleAvatar(
            radius: 12,
            backgroundImage: CachedNetworkImageProvider(
              state.currentUserProfile!.avatarUrl!,
            ),
          )
              : Icon(Icons.person_outline),
          activeIcon: state.currentUserProfile?.avatarUrl != null
              ? Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.purple[600]!,
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: CachedNetworkImageProvider(
                state.currentUserProfile!.avatarUrl!,
              ),
            ),
          )
              : Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildCreatePostButton() {
    return FloatingActionButton(
      onPressed: _showCreatePostModal,
      backgroundColor: Colors.purple[600],
      child: Icon(Icons.add, color: Colors.white),
    );
  }

  void _showCreatePostModal() {
    final state = context.read<CommunityBloc>().state;

    // Check if user profile is loaded
    if (state.currentUserProfile == null) {
      _showError('User profile not loaded. Please try again.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostModal(),
    );
  }

  void _showDeletePostDialog(BuildContext context, String postId) {
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
              context.read<CommunityBloc>().add(DeletePost(postId));
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(BuildContext context, Post post) {
    final captionController = TextEditingController(text: post.caption);
    PostPrivacy selectedPrivacy = post.privacy;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<PostPrivacy>(
                value: selectedPrivacy,
                decoration: InputDecoration(
                  labelText: 'Privacy',
                  border: OutlineInputBorder(),
                ),
                items: PostPrivacy.values.map((privacy) {
                  return DropdownMenuItem(
                    value: privacy,
                    child: Row(
                      children: [
                        Icon(
                          privacy == PostPrivacy.public
                              ? Icons.public
                              : privacy == PostPrivacy.friendsOnly
                              ? Icons.people
                              : Icons.lock,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(privacy == PostPrivacy.public
                            ? 'Public'
                            : privacy == PostPrivacy.friendsOnly
                            ? 'Friends Only'
                            : 'Private'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedPrivacy = value);
                  }
                },
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
                context.read<CommunityBloc>().add(UpdatePost(
                  postId: post.id,
                  caption: captionController.text,
                  privacy: selectedPrivacy,
                ));
                Navigator.pop(context);
              },
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}

// Create Post Modal
class CreatePostModal extends StatefulWidget {
  @override
  _CreatePostModalState createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _captionController = TextEditingController();
  List<File> _selectedMedia = [];
  List<MediaType> _mediaTypes = [];
  PostPrivacy _privacy = PostPrivacy.public;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    Text(
                      'Create Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: state.isCreatingPost || _selectedMedia.isEmpty
                          ? null
                          : () {
                        context.read<CommunityBloc>().add(CreatePost(
                          mediaFiles: _selectedMedia,
                          mediaTypes: _mediaTypes,
                          caption: _captionController.text,
                          privacy: _privacy,
                        ));
                        Navigator.pop(context);
                      },
                      child: state.isCreatingPost
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(
                        'Share',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // User info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: state.currentUserProfile?.avatarUrl != null
                                ? CachedNetworkImageProvider(
                                state.currentUserProfile!.avatarUrl!)
                                : null,
                            child: state.currentUserProfile?.avatarUrl == null
                                ? Icon(Icons.person)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.currentUserProfile?.fullName ?? 'User',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: DropdownButton<PostPrivacy>(
                                  value: _privacy,
                                  isDense: true,
                                  underline: SizedBox(),
                                  icon: Icon(Icons.arrow_drop_down, size: 18),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  items: PostPrivacy.values.map((privacy) {
                                    return DropdownMenuItem(
                                      value: privacy,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            privacy == PostPrivacy.public
                                                ? Icons.public
                                                : privacy == PostPrivacy.friendsOnly
                                                ? Icons.people
                                                : Icons.lock,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            privacy == PostPrivacy.public
                                                ? 'Public'
                                                : privacy == PostPrivacy.friendsOnly
                                                ? 'Friends'
                                                : 'Private',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _privacy = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // Caption
                      TextField(
                        controller: _captionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write a caption...',
                          border: InputBorder.none,
                        ),
                      ),

                      SizedBox(height: 16),

                      // Media picker
                      MediaPicker(
                        selectedMedia: _selectedMedia,
                        mediaTypes: _mediaTypes,
                        onMediaSelected: (files, types) {
                          setState(() {
                            _selectedMedia = files;
                            _mediaTypes = types;
                          });
                        },
                        maxMedia: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}