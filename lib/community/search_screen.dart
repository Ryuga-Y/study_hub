import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/bloc.dart';
import '../community/models.dart';
import 'profile_screen.dart';

enum SearchScreenTab { search, friendRequests, notifications }

class SearchScreen extends StatefulWidget {
  final String organizationCode;
  final SearchScreenTab initialTab;

  const SearchScreen({
    Key? key,
    required this.organizationCode,
    this.initialTab = SearchScreenTab.search,
  }) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );

    // Load initial data
    _loadInitialData();
  }

  void _loadInitialData() {
    final bloc = context.read<CommunityBloc>();
    bloc.add(LoadPendingRequests());
    bloc.add(LoadNotifications());
    bloc.add(LoadFriends());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityBloc, CommunityState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            title: _isSearching && _tabController.index == 0
                ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search users...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              onChanged: (query) {
                if (query.isNotEmpty) {
                  context.read<CommunityBloc>().add(
                    SearchUsers(
                      query: query,
                      organizationCode: widget.organizationCode,
                    ),
                  );
                }
              },
            )
                : Text(
              _tabController.index == 0
                  ? 'Discover'
                  : _tabController.index == 1
                  ? 'Friend Requests'
                  : 'Notifications',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              if (_tabController.index == 0)
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        context.read<CommunityBloc>().add(
                          SearchUsers(query: '', organizationCode: widget.organizationCode),
                        );
                      } else {
                        _searchFocusNode.requestFocus();
                      }
                    });
                  },
                ),
              if (_tabController.index == 2 && state.notifications.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.done_all),
                  onPressed: () {
                    context.read<CommunityBloc>().add(MarkAllNotificationsRead());
                  },
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.purple[600],
              labelColor: Colors.purple[600],
              unselectedLabelColor: Colors.grey[600],
              onTap: (index) {
                if (index != 0 && _isSearching) {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                }
              },
              tabs: [
                Tab(text: 'Search'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Requests'),
                      if (state.pendingRequests.isNotEmpty) ...[
                        SizedBox(width: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            state.pendingRequests.length.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Notifications'),
                      if (state.unreadNotificationCount > 0) ...[
                        SizedBox(width: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
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
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSearchTab(state),
              _buildFriendRequestsTab(state),
              _buildNotificationsTab(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchTab(CommunityState state) {
    if (_searchController.text.isEmpty) {
      return _buildSuggestedFriends(state);
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with a different name',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) {
        final user = state.searchResults[index];
        return _buildUserTile(user, state);
      },
    );
  }

  Widget _buildSuggestedFriends(CommunityState state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested for You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'People you may know',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),

          // Placeholder for suggested friends
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16),
                Text(
                  'No suggestions yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Start searching to find friends',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(CommunityUser user, CommunityState state) {
    final isFriend = state.friends.any((f) => f.friendId == user.uid);
    final hasPendingRequest = state.pendingRequests.any((r) => r.friendId == user.uid);
    final currentUserId = state.currentUserProfile?.uid;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: user.uid,
                isCurrentUser: user.uid == currentUserId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Icon(Icons.person, size: 28)
                    : null,
              ),

              SizedBox(width: 12),

              // User info
              Expanded(
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
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        SizedBox(width: 8),
                        Text(
                          '${user.friendCount} friends',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action button
              if (user.uid != currentUserId)
                _buildUserActionButton(user, isFriend, hasPendingRequest),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserActionButton(CommunityUser user, bool isFriend, bool hasPendingRequest) {
    if (isFriend) {
      return OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: user.uid,
                isCurrentUser: false,
              ),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Friends',
          style: TextStyle(color: Colors.black87),
        ),
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
          'Pending',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: () {
          context.read<CommunityBloc>().add(SendFriendRequest(user.uid));
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

  Widget _buildFriendRequestsTab(CommunityState state) {
    if (state.pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_disabled,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No friend requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When someone sends you a friend request,\nit will appear here',
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

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: state.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = state.pendingRequests[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: request.friendAvatar != null
                          ? CachedNetworkImageProvider(request.friendAvatar!)
                          : null,
                      child: request.friendAvatar == null
                          ? Icon(Icons.person, size: 32)
                          : null,
                    ),

                    SizedBox(width: 12),

                    // Request info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.friendName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sent ${timeago.format(request.createdAt)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (request.mutualFriends.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              '${request.mutualFriends.length} mutual friends',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<CommunityBloc>().add(
                            AcceptFriendRequest(request.id),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Accept',style: TextStyle(color: Colors.white ),),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          context.read<CommunityBloc>().add(
                            DeclineFriendRequest(request.id),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Decline',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTab(CommunityState state) {
    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your notifications will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: state.notifications.length,
      itemBuilder: (context, index) {
        final notification = state.notifications[index];
        return _buildNotificationTile(notification);
      },
    );
  }

  Widget _buildNotificationTile(CommunityNotification notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.like:
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case NotificationType.comment:
        iconData = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case NotificationType.friendRequest:
        iconData = Icons.person_add;
        iconColor = Colors.green;
        break;
      case NotificationType.friendAccepted:
        iconData = Icons.people;
        iconColor = Colors.purple;
        break;
      case NotificationType.mention:
        iconData = Icons.alternate_email;
        iconColor = Colors.orange;
        break;
      case NotificationType.newPost:
        iconData = Icons.photo;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return InkWell(
      onTap: () {
        // Mark as read
        if (!notification.isRead) {
          context.read<CommunityBloc>().add(MarkNotificationRead(notification.id));
        }

        // Navigate based on notification type
        if (notification.postId != null) {
          // Navigate to post
          // You would need to fetch the post data first
        } else if (notification.actionUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(
                userId: notification.actionUserId!,
                isCurrentUser: false,
              ),
            ),
          );
        }
      },
      child: Container(
        color: notification.isRead ? Colors.white : Colors.purple[50],
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 24,
              ),
            ),

            SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      children: [
                        if (notification.actionUserName != null)
                          TextSpan(
                            text: notification.actionUserName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        TextSpan(text: ' '),
                        TextSpan(text: notification.message),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    timeago.format(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // User avatar (if available)
            if (notification.actionUserAvatar != null) ...[
              SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(
                  notification.actionUserAvatar!,
                ),
              ),
            ],
          ],
        ),
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