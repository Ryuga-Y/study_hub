import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_hub/community/profile_change_notifier.dart';
import 'package:study_hub/community/search_screen.dart';
import 'bloc.dart';
import 'community_services.dart';
import 'models.dart';
import '../chat_integrated.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    Key? key,
    required this.userId,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<Post> _userPosts = [];
  List<Friend> _userFriends = [];
  bool _isLoadingPosts = true;
  bool _isLoadingFriends = true;
  FriendStatus? _friendStatus;
  final CommunityService _service = CommunityService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  void _loadUserData() {
    // Load user profile
    context.read<CommunityBloc>().add(LoadUserProfile(widget.userId));

    // Load posts
    _service.getUserPosts(widget.userId).listen((posts) {
      if (mounted) {
        setState(() {
          _userPosts = posts;
          _isLoadingPosts = false;
        });
      }
    });

    // Load friends - Fixed logic
    if (widget.isCurrentUser) {
      // For current user, load from bloc state
      context.read<CommunityBloc>().add(LoadFriends());
      _isLoadingFriends = false;
    } else {
      // For other users, load their friends directly
      _loadUserFriends();
    }

    // Check friend status if viewing another user
    if (!widget.isCurrentUser) {
      _checkFriendStatus();
    }
  }

  void _loadUserFriends() {
    // Load friends for the user being viewed (not current user)
    _service.getFriends(status: FriendStatus.accepted, userId: widget.userId).listen((userFriends) {
      if (mounted) {
        setState(() {
          _userFriends = userFriends;
          _isLoadingFriends = false;
        });
      }
    }, onError: (error) {
      print('Error loading user friends: $error');
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    });
  }

  Future<void> _checkFriendStatus() async {
    try {
      final currentUser = _service.currentUserId;
      if (currentUser == null) return;

      // Check if already friends
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .where('userId', isEqualTo: currentUser)
          .where('friendId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (friendsSnapshot.docs.isNotEmpty) {
        setState(() => _friendStatus = FriendStatus.accepted);
        return;
      }

      // Check for pending request
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .where('userId', isEqualTo: currentUser)
          .where('friendId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingSnapshot.docs.isNotEmpty) {
        setState(() => _friendStatus = FriendStatus.pending);
      }
    } catch (e) {
      print('Error checking friend status: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        final user = widget.isCurrentUser
            ? state.currentUserProfile
            : state.viewingUserProfile;

        if (user == null) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            title: Text(
              widget.isCurrentUser ? 'Profile' : user.fullName,
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              if (!widget.isCurrentUser)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Block User'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Report'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    // Handle menu actions
                  },
                ),
            ],
          ),
          body: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(user, state),
                ),
                SliverPersistentHeader(
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.purple[600],
                      labelColor: Colors.purple[600],
                      unselectedLabelColor: Colors.grey[600],
                      tabs: [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.people)),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsGrid(),
                _buildFriendsList(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(CommunityUser user, CommunityState state) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile info row
          Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: widget.isCurrentUser ? _changeAvatar : null,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user.avatarUrl != null
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Icon(Icons.person, size: 40)
                          : null,
                    ),
                    if (widget.isCurrentUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.purple[600],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(user.postCount, 'Posts'),
                    _buildStatColumn(user.friendCount, 'Friends'),
                    _buildStatColumn(
                        _userPosts.fold<int>(
                            0,
                                (sum, post) => sum + post.likeCount
                        ),
                        'Likes'
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Name and bio
          Container(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.bio != null) ...[
                  SizedBox(height: 4),
                  Text(
                    user.bio!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.substring(0, 1).toUpperCase() + user.role.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getRoleColor(user.role),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Action buttons
          if (widget.isCurrentUser)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showEditProfileDialog,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _showSettingsDialog,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Icon(Icons.settings, color: Colors.black87),
                ),
              ],
            )
          else
            _buildFriendActionButton(state),
        ],
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendActionButton(CommunityState state) {
    // Check if already friends or if request is pending
    final isFriend = state.friends.any((f) => f.friendId == widget.userId);
    final hasPendingRequest = state.pendingRequests.any((r) => r.friendId == widget.userId);

    if (isFriend) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // UPDATED: Navigate to chat screen
                final currentUserId = _service.currentUserId;
                if (currentUserId != null) {
                  // Generate chat ID locally
                  final sortedIds = [currentUserId, widget.userId]..sort();
                  final chatId = '${sortedIds[0]}_${sortedIds[1]}';

                  // Get user data from state - ADD THIS LINE HERE
                  final user = widget.isCurrentUser
                      ? state.currentUserProfile
                      : state.viewingUserProfile;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        contactId: widget.userId,
                        contactName: user?.fullName ?? 'Unknown User',
                        contactAvatar: user?.avatarUrl,
                        isOnline: false,
                        chatId: chatId,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Message'),
            ),
          ),
          SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _showUnfriendDialog(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(Icons.person_remove, color: Colors.black87),
          ),
        ],
      );
    } else if (hasPendingRequest) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Request Sent',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: () {
          context.read<CommunityBloc>().add(SendFriendRequest(widget.userId));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text('Add Friend',style: TextStyle(color: Colors.white),),
      );
    }
  }

  Widget _buildPostsGrid() {
    if (_isLoadingPosts) {
      return Center(child: CircularProgressIndicator());
    }

    if (_userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(1),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/post',
              arguments: post,
            );
          },
          child: Container(
            color: Colors.grey[200],
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (post.mediaUrls.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: post.mediaUrls.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.broken_image, color: Colors.grey[500]),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        post.caption,
                        style: TextStyle(fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Multi-media indicator
                if (post.mediaUrls.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.collections, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '${post.mediaUrls.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Video indicator
                if (post.mediaTypes.contains(MediaType.video))
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(CommunityState state) {
    if (_isLoadingFriends) {
      return Center(child: CircularProgressIndicator());
    }

    final friends = widget.isCurrentUser ? state.friends : _userFriends;
    final user = widget.isCurrentUser ? state.currentUserProfile : state.viewingUserProfile;

    // Check if the current viewer can see the friends list
    return FutureBuilder<bool>(
      future: _checkCanViewFriendsList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final canView = snapshot.data ?? false;

        if (!canView) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16),
                Text(
                  'Friends list is private',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  user?.friendsListPrivacy == FriendsListPrivacy.friendsOnly
                      ? 'Only friends can see this list'
                      : 'This list is private',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                if (widget.isCurrentUser) ...[
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchScreen(
                            organizationCode: state.currentUserProfile?.organizationCode ?? '',
                          ),
                        ),
                      );
                    },
                    child: Text('Find Friends'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final displayId = friend.userId == widget.userId ? friend.friendId : friend.userId;
            final displayName = friend.userId == widget.userId ? friend.friendName : friend.friendName;
            final displayAvatar = friend.userId == widget.userId ? friend.friendAvatar : friend.friendAvatar;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: displayAvatar != null
                    ? CachedNetworkImageProvider(displayAvatar)
                    : null,
                child: displayAvatar == null
                    ? Icon(Icons.person)
                    : null,
              ),
              title: Text(displayName),
              subtitle: friend.mutualFriends.isNotEmpty
                  ? Text('${friend.mutualFriends.length} mutual friends')
                  : null,
              trailing: widget.isCurrentUser
                  ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'unfriend',
                    child: Text('Unfriend'),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Text('Block'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'unfriend') {
                    _showUnfriendConfirmDialog(context, displayId, displayName);
                  }
                },
              )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: displayId,
                      isCurrentUser: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _checkCanViewFriendsList() async {
    if (widget.isCurrentUser) return true;

    final service = CommunityService();
    return await service.canViewFriendsList(widget.userId);
  }

  void _showUnfriendConfirmDialog(BuildContext context, String friendId, String friendName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Friend'),
        content: Text('Are you sure you want to remove $friendName as a friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first

              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Removing friend...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Dispatch the remove friend action
                context.read<CommunityBloc>().add(RemoveFriend(friendId));

              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to remove friend: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);  // Pop first
              _pickAvatarImage(ImageSource.camera);  // Then do async operation
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);  // Pop first
              _pickAvatarImage(ImageSource.gallery);  // Then do async operation
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Remove Photo', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);  // Pop first
              _removeAvatar();  // Then remove avatar
            },
          ),
          ListTile(
            leading: Icon(Icons.cancel),
            title: Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatarImage(ImageSource source) async {
    final picker = ImagePicker();

    try {
      final XFile? imageFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imageFile != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Updating profile picture...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );

        context.read<CommunityBloc>().add(
          UpdateUserProfile(avatarFile: File(imageFile.path)),
        );

        // Listen for the update completion
        final subscription = context.read<CommunityBloc>().stream.listen((state) {
          if (state.successMessage != null || state.error != null) {
            Navigator.pop(context); // Close loading dialog

            if (state.successMessage != null) {
              // Notify other parts of the app about the avatar change
              final user = state.currentUserProfile;
              if (user != null) {
                ProfileChangeNotifier().notifyProfileUpdate({
                  'fullName': user.fullName,
                  'bio': user.bio,
                  'avatarUrl': user.avatarUrl,
                });
              }
            }
          }
        });

        // Cancel subscription after 10 seconds to prevent memory leaks
        Timer(Duration(seconds: 10), () {
          subscription.cancel();
        });
      }
    } catch (e) {
      print('Error picking image: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeAvatar() {
    context.read<CommunityBloc>().add(
      UpdateUserProfile(removeAvatar: true),
    );
  }

  void _showEditProfileDialog() {
    final user = context.read<CommunityBloc>().state.currentUserProfile;
    if (user == null) return;

    final nameController = TextEditingController(text: user.fullName);
    final bioController = TextEditingController(text: user.bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 16),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
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
              final newName = nameController.text.trim();
              final newBio = bioController.text.trim();

              // Only update if there are changes
              bool hasChanges = false;

              if (newName != user.fullName && newName.isNotEmpty) {
                hasChanges = true;
              }

              if (newBio != (user.bio ?? '')) {
                hasChanges = true;
              }

              if (hasChanges) {
                context.read<CommunityBloc>().add(
                  UpdateUserProfile(
                    fullName: newName.isNotEmpty ? newName : null,
                    bio: newBio.isNotEmpty ? newBio : null,
                  ),
                );

                // Notify other parts of the app about the profile change
                ProfileChangeNotifier().notifyProfileUpdate({
                  'fullName': newName,
                  'bio': newBio,
                  'avatarUrl': user.avatarUrl,
                });
              }

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.privacy_tip),
            title: Text('Privacy Settings'),
            onTap: () {
              Navigator.pop(context);
              _showPrivacySettingsDialog();
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notification Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to notification settings
            },
          ),
          ListTile(
            leading: Icon(Icons.block),
            title: Text('Blocked Users'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to blocked users
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showSignOutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacySettingsDialog() {
    final user = context.read<CommunityBloc>().state.currentUserProfile;
    if (user == null) return;

    FriendsListPrivacy selectedPrivacy = user.friendsListPrivacy;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Privacy Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who can see your friends list?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              RadioListTile<FriendsListPrivacy>(
                title: Text('Everyone'),
                subtitle: Text('Anyone can see your friends list'),
                value: FriendsListPrivacy.public,
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  setState(() => selectedPrivacy = value!);
                },
              ),
              RadioListTile<FriendsListPrivacy>(
                title: Text('Friends Only'),
                subtitle: Text('Only your friends can see your friends list'),
                value: FriendsListPrivacy.friendsOnly,
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  setState(() => selectedPrivacy = value!);
                },
              ),
              RadioListTile<FriendsListPrivacy>(
                title: Text('Only Me'),
                subtitle: Text('Nobody can see your friends list'),
                value: FriendsListPrivacy.private,
                groupValue: selectedPrivacy,
                onChanged: (value) {
                  setState(() => selectedPrivacy = value!);
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
                context.read<CommunityBloc>().add(
                  UpdateUserProfile(friendsListPrivacy: selectedPrivacy),
                );
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Sign out logic
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                    (route) => false,
              );
            },
            child: Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUnfriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Friend'),
        content: Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CommunityBloc>().add(RemoveFriend(widget.userId));
              Navigator.pop(context);
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'lecturer':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// Custom sliver delegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}