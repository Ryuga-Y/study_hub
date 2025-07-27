import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:study_hub/community/post_card.dart';
import '../community/bloc.dart';
import '../community/models.dart';
import '../Authentication/auth_services.dart';
import 'edit_dialogs.dart';
import 'media_picker.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../chat_integrated.dart';
import '../community/community_services.dart';
import 'package:rxdart/rxdart.dart';

class FeedScreen extends StatefulWidget {
  final String organizationCode;
  final int initialTab;

  const FeedScreen({
    Key? key,
    required this.organizationCode,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

bool _hasRunCleanup = false;

class _FeedScreenState extends State<FeedScreen> {
  late int _currentIndex;
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkAuthenticationStatus();
    _initializeFeed();
    _scrollController.addListener(_onScroll);

    Future.delayed(Duration(seconds: 3), () => _debugBellIconData());
  }

  void _debugAuthState() {
    final user = FirebaseAuth.instance.currentUser;
    print('🔐 Auth Debug:');
    print('   User: ${user?.uid}');
    print('   Email: ${user?.email}');
    print('   IsAnonymous: ${user?.isAnonymous}');

    user?.getIdToken().then((token) {
      print('   Token length: ${token?.length ?? 0}');
      print('   Token preview: ${token?.substring(0, 50) ?? 'null'}...');
    }).catchError((e) {
      print('   Token error: $e');
    });
  }

  Future<void> _initializeFeed() async {
    try {
      _debugAuthState();

      final user = _authService.currentUser;
      if (user == null) {
        _showError('User not authenticated');
        return;
      }

      await context.read<CommunityBloc>().state.currentUserProfile != null
          ? Future.delayed(Duration.zero)
          : _refreshAuthentication();

      final bloc = context.read<CommunityBloc>();
      bloc.add(LoadUserProfile(user.uid));

      await Future.delayed(Duration(milliseconds: 500));
      _loadInitialData();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing feed: $e');
      _showError('Error initializing feed: $e');
    }
  }

  Future<void> _refreshAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
        print('✅ Authentication token refreshed');
      }
    } catch (e) {
      print('❌ Failed to refresh authentication: $e');
    }
  }

  void _loadInitialData() {
    final bloc = context.read<CommunityBloc>();

    if (widget.organizationCode.isNotEmpty) {
      bloc.add(LoadFeed(organizationCode: widget.organizationCode));
      bloc.add(LoadNotifications());
      bloc.add(LoadFriends());
      bloc.add(LoadPendingRequests());
      _scheduleCleanup();
    }
  }

  void _scheduleCleanup() {
    if (_hasRunCleanup) return;
    _hasRunCleanup = true;

    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        final service = CommunityService();
        service.cleanupBrokenImagePosts().catchError((e) {
          print('Cleanup error (suppressed): Network/Storage issue');
        });
      }
    });
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

  void _checkAuthenticationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    print('=== AUTHENTICATION DEBUG ===');
    print('User: ${user?.uid}');
    print('Email: ${user?.email}');
    print('Email Verified: ${user?.emailVerified}');

    if (user != null) {
      try {
        final token = await user.getIdToken();
        print('Token obtained: ${token?.length ?? 0} characters');

        final testDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        print('Firestore access: ${testDoc.exists ? 'SUCCESS' : 'FAILED'}');
      } catch (e) {
        print('Auth error: $e');
      }
    }
    print('=== END AUTH DEBUG ===');
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

  Stream<int> _getTotalUnreadCountStream() {
    return Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
      try {
        final currentUserId = _authService.currentUser?.uid;
        if (currentUserId == null) return 0;

        // Get EXACT same count as shown in Messages tab
        final state = context.read<CommunityBloc>().state;
        final communityCount = state.unreadNotificationCount;

        // Get EXACT same count as shown in Chat tab
        final chatsSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .get();

        int chatCount = 0;
        for (final doc in chatsSnapshot.docs) {
          final data = doc.data();
          final unreadCount = data['unreadCount']?[currentUserId] ?? 0;
          chatCount += unreadCount as int;
        }

        final total = communityCount + chatCount;
        print('🔔 Bell Icon Debug:');
        print('   Messages tab count: $communityCount');
        print('   Chat tab count: $chatCount');
        print('   Total for bell: $total');

        return total;
      } catch (e) {
        print('❌ Error in bell icon count: $e');
        return 0;
      }
    }).distinct();
  }

  Future<void> _debugBellIconData() async {
    final currentUserId = _authService.currentUser?.uid;
    print('🔍 BELL ICON DEBUG:');
    print('   Current User ID: $currentUserId');

    if (currentUserId != null) {
      // Check BLoC state
      final state = context.read<CommunityBloc>().state;
      print('   BLoC unread notifications: ${state.unreadNotificationCount}');

      // Check chat directly
      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      int chatTotal = 0;
      for (final doc in chats.docs) {
        final data = doc.data();
        final unread = data['unreadCount']?[currentUserId] ?? 0;
        chatTotal += unread as int;
        print('   Chat ${doc.id}: unread = $unread');
      }
      print('   Total chat unread: $chatTotal');
      print('   SHOULD SHOW: ${state.unreadNotificationCount + chatTotal}');
    }
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
              _buildFeedTab(state),
              SearchScreen(organizationCode: widget.organizationCode),
              ProfileScreen(
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
            Icon(
              Icons.school,
              color: Colors.purple[400],
              size: 30,
            ),
            SizedBox(width: 10),
            Text(
              'Community',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
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
            StreamBuilder<int>(
              stream: _getTotalUnreadCountStream(),
              builder: (context, snapshot) {
                final totalUnread = snapshot.hasData ? snapshot.data! : 0;
                print('🔔 UI Bell Icon Update - Showing: $totalUnread, hasData: ${snapshot.hasData}');

                return Stack(
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
                    if (totalUnread > 0)
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
                            totalUnread > 99 ? '99+' : totalUnread.toString(),
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
                );
              },
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
                Navigator.pushNamed(
                  context,
                  '/post',
                  arguments: post,
                );
              },
              onShare: () {},
              onDelete: post.userId == state.currentUserProfile?.uid
                  ? () => _showDeletePostDialog(context, post.id)
                  : null,
              onEdit: post.userId == state.currentUserProfile?.uid
                  ? () => _showEditPostDialog(post)  // Updated to pass the post
                  : null,
            )
            ;
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

  void _showEditPostDialog(Post post) {
    showDialog(
      context: context,
      builder: (context) => EnhancedEditPostDialog(post: post),
    );
  }
}

// Enhanced Create Post Modal with merged functionality
class CreatePostModal extends StatefulWidget {
  @override
  _CreatePostModalState createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _captionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<File> _selectedMedia = [];
  List<MediaType> _mediaTypes = [];
  PostPrivacy _privacy = PostPrivacy.public;
  bool _hasPoll = false;

  // Poll data
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  DateTime? _pollEndsAt;
  bool _pollIsAnonymous = false;

  @override
  void dispose() {
    _captionController.dispose();
    _pollQuestionController.dispose();
    _scrollController.dispose();
    for (final controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 6) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
      // Scroll to bottom when adding new option
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers[index].dispose();
        _pollOptionControllers.removeAt(index);
      });
    }
  }

  bool _canCreate() {
    // Check if we have media or poll with valid data
    bool hasMedia = _selectedMedia.isNotEmpty;
    bool hasValidPoll = false;

    if (_hasPoll) {
      final validOptions = _pollOptionControllers
          .where((controller) => controller.text.trim().isNotEmpty)
          .length;
      hasValidPoll = _pollQuestionController.text.trim().isNotEmpty && validOptions >= 2;
    }

    // Allow creation if we have media, valid poll, or both
    return hasMedia || hasValidPoll;
  }

  void _createPost(CommunityState state) {
    // Determine if we have a valid poll
    bool hasValidPoll = false;
    List<String>? validOptions;

    if (_hasPoll) {
      validOptions = _pollOptionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      hasValidPoll = _pollQuestionController.text.trim().isNotEmpty && validOptions.length >= 2;
    }

    // Create post with appropriate event based on content
    if (_selectedMedia.isNotEmpty && hasValidPoll) {
      // Post with both media and poll
      context.read<CommunityBloc>().add(CreatePostWithMediaAndPoll(
        mediaFiles: _selectedMedia,
        mediaTypes: _mediaTypes,
        caption: _captionController.text,
        privacy: _privacy,
        pollQuestion: _pollQuestionController.text,
        pollOptions: validOptions,
        allowMultipleVotes: false,
        pollEndsAt: _pollEndsAt,
        pollIsAnonymous: _pollIsAnonymous,
      ));
    } else if (_selectedMedia.isNotEmpty) {
      // Regular post with media only
      context.read<CommunityBloc>().add(CreatePost(
        mediaFiles: _selectedMedia,
        mediaTypes: _mediaTypes,
        caption: _captionController.text,
        privacy: _privacy,
      ));
    } else if (hasValidPoll) {
      // Post with poll only
      context.read<CommunityBloc>().add(CreatePostWithPoll(
        caption: _captionController.text.isEmpty
            ? _pollQuestionController.text
            : _captionController.text,
        privacy: _privacy,
        pollQuestion: _pollQuestionController.text,
        pollOptions: validOptions!,
        allowMultipleVotes: false,
        endsAt: _pollEndsAt,
        isAnonymous: _pollIsAnonymous,
      ));
    }

    Navigator.pop(context);
  }

  Future<void> _selectPollEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _pollEndsAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

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
                      onPressed: state.isCreatingPost || !_canCreate()
                          ? null
                          : () => _createPost(state),
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
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    // Add extra padding at bottom for keyboard
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
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
                                child: _buildPrivacyDropdown(),
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

                      // Always show media picker first
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

                      SizedBox(height: 16),

                      // Poll toggle
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CheckboxListTile(
                                title: Text('Add Poll'),
                                secondary: Icon(Icons.poll, color: Colors.purple[600]),
                                value: _hasPoll,
                                onChanged: (value) {
                                  setState(() {
                                    _hasPoll = value ?? false;
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Show poll creation if enabled
                      if (_hasPoll) ...[
                        SizedBox(height: 16),
                        _buildPollCreation(),
                      ],
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

  Widget _buildPrivacyDropdown() {
    return DropdownButton<PostPrivacy>(
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
    );
  }

  Widget _buildPollCreation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poll question
        TextField(
          controller: _pollQuestionController,
          decoration: InputDecoration(
            hintText: 'Ask a question...',
            border: OutlineInputBorder(),
            labelText: 'Poll Question',
          ),
          maxLines: 2,
        ),

        SizedBox(height: 16),

        Text(
          'Options',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),

        // Poll options
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _pollOptionControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollOptionControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  if (_pollOptionControllers.length > 2)
                    IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removePollOption(index),
                    ),
                ],
              ),
            );
          },
        ),

        if (_pollOptionControllers.length < 6)
          TextButton.icon(
            onPressed: _addPollOption,
            icon: Icon(Icons.add),
            label: Text('Add Option'),
          ),

        SizedBox(height: 16),

        // Poll settings
        Column(
          children: [
            InkWell(
              onTap: () => _selectPollEndTime(),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 20, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pollEndsAt != null
                            ? 'Ends ${_formatDate(_pollEndsAt!)}'
                            : 'Set End Time (Optional)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CheckboxListTile(
                title: Text('Anonymous voting', style: TextStyle(fontSize: 14)),
                value: _pollIsAnonymous,
                onChanged: (value) {
                  setState(() => _pollIsAnonymous = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ),
      ],
    );
  }
}