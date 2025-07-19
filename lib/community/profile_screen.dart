import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_hub/community/search_screen.dart';
import 'bloc.dart';
import 'community_services.dart';
import 'models.dart';

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
    _service.getFriends(status: FriendStatus.accepted).listen((allFriends) {
      if (mounted) {
        // Filter friends for the user being viewed
        final userFriends = allFriends.where((friend) =>
        friend.userId == widget.userId || friend.friendId == widget.userId
        ).toList();

        setState(() {
          _userFriends = userFriends;
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
          appBar: widget.isCurrentUser ? null : AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            title: Text(
              user.fullName,
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
                // Navigate to chat or other friend actions
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

    print('DEBUG: Displaying ${friends.length} friends for user ${widget.userId}');

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
                  // Navigate to search screen
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

        // Determine the correct friend info to display
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
                context.read<CommunityBloc>().add(RemoveFriend(displayId));
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
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take Photo'),
            onTap: () async {
              final image = await picker.pickImage(source: ImageSource.camera);
              Navigator.pop(context, image);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from Gallery'),
            onTap: () async {
              final image = await picker.pickImage(source: ImageSource.gallery);
              Navigator.pop(context, image);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Remove Photo', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );

    if (result != null) {
      context.read<CommunityBloc>().add(
        UpdateUserProfile(avatarFile: File(result.path)),
      );
    }
  }

  void _showEditProfileDialog() {
    final user = context.read<CommunityBloc>().state.currentUserProfile;
    if (user == null) return;

    final bioController = TextEditingController(text: user.bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: TextField(
          controller: bioController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Bio',
            hintText: 'Tell us about yourself...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CommunityBloc>().add(
                UpdateUserProfile(bio: bioController.text),
              );
              Navigator.pop(context);
            },
            child: Text('Save'),
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
              // Navigate to privacy settings
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