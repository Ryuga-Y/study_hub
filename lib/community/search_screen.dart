import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/bloc.dart';
import '../community/models.dart';
import 'profile_screen.dart';
import '../chat_integrated.dart' show ChatScreen;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_screen.dart';

enum SearchScreenTab { search, friendRequests, notifications, chat }

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
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
                  onPressed: () async {
                    context.read<CommunityBloc>().add(MarkAllNotificationsRead());

                    // Also update Firestore directly for real-time updates
                    try {
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUserId != null) {
                        final batch = FirebaseFirestore.instance.batch();
                        final unreadNotifications = await FirebaseFirestore.instance
                            .collection('notifications')
                            .where('userId', isEqualTo: currentUserId)
                            .where('isRead', isEqualTo: false)
                            .get();

                        for (final doc in unreadNotifications.docs) {
                          batch.update(doc.reference, {'isRead': true});
                        }

                        await batch.commit();
                      }
                    } catch (e) {
                      print('Error marking all notifications as read: $e');
                    }
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
                      Flexible(
                        child: Text(
                          'Requests',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.pendingRequests.isNotEmpty) ...[
                        SizedBox(width: 2),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: BoxConstraints(minWidth: 16),
                          child: Text(
                            state.pendingRequests.length > 9 ? '9+' : state.pendingRequests.length.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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
                      Flexible(
                        child: Text(
                          'Messages',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.unreadNotificationCount > 0) ...[
                        SizedBox(width: 2),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: BoxConstraints(minWidth: 16),
                          child: Text(
                            state.unreadNotificationCount > 99
                                ? '99+'
                                : state.unreadNotificationCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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
                      Text('Chat'),
                      // Add chat unread count here if needed
                      StreamBuilder<int>(
                        stream: _getChatUnreadCountStream(),
                        builder: (context, snapshot) {
                          final chatUnread = snapshot.data ?? 0;
                          if (chatUnread > 0) {
                            return Row(
                              children: [
                                SizedBox(width: 2),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    chatUnread > 99 ? '99+' : chatUnread.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
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
              _buildChatTab(state),
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
            Icon(Icons.person_add_disabled, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text('No friend requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text('When someone sends you a friend request,\nit will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: state.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = state.pendingRequests[index];

        // Add debug logging
        print('DEBUG: UI - Rendering request: ${request.id}');
        print('DEBUG: UI - Request data: userId=${request.userId}, friendId=${request.friendId}, isReceived=${request.isReceived}');

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      child: request.friendAvatar == null ? Icon(Icons.person, size: 32) : null,
                    ),
                    SizedBox(width: 12),
                    // Request info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.friendName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Sent ${timeago.format(request.createdAt)}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          if (request.mutualFriends.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text('${request.mutualFriends.length} mutual friends', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
                        // Replace the problematic onPressed handler with this fixed version:

                        onPressed: () async {
                          print('DEBUG: UI - Accept button pressed for request: ${request.id}');
                          context.read<CommunityBloc>().add(AcceptFriendRequest(request.id));

                          // Wait for the request to be processed
                          await Future.delayed(Duration(milliseconds: 1500));

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Friend request accepted! You can now chat.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                                action: SnackBarAction(
                                  label: 'Go to Chat',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    // Option 1: Switch to the Chat tab in this screen
                                    _tabController.animateTo(3); // Chat tab is index 3
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Accept', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          print('DEBUG: UI - Decline button pressed for request: ${request.id}');
                          context.read<CommunityBloc>().add(DeclineFriendRequest(request.id));
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Decline', style: TextStyle(color: Colors.black87)),
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
    // Only show community notifications, NOT chat notifications
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
      onTap: () async {
        // Mark as read immediately for better UX
        if (!notification.isRead) {
          context.read<CommunityBloc>().add(MarkNotificationRead(notification.id));

          // Also update Firestore directly for real-time updates
          try {
            await FirebaseFirestore.instance
                .collection('notifications')
                .doc(notification.id)
                .update({'isRead': true});
          } catch (e) {
            print('Error marking notification as read: $e');
          }
        }

        // Navigate based on notification type
        if (notification.postId != null) {
          // Navigate to post
          try {
            // Fetch the post data
            final postDoc = await FirebaseFirestore.instance
                .collection('posts')
                .doc(notification.postId)
                .get();

            if (postDoc.exists) {
              final post = Post.fromFirestore(postDoc);
              Navigator.pushNamed(
                context,
                '/post',
                arguments: post,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Post not found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            print('Error loading post: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load post'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

  Widget _buildChatNotificationTile(Map<String, dynamic> chatNotif) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              contactId: chatNotif['otherUserId'],
              contactName: chatNotif['senderName'],
              contactAvatar: chatNotif['senderAvatar'],
              isOnline: false,
              chatId: chatNotif['chatId'],
            ),
          ),
        );
      },
      child: Container(
        color: chatNotif['unreadCount'] > 0 ? Colors.blue[50] : Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.message,
                color: Colors.blue,
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
                        TextSpan(
                          text: chatNotif['senderName'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' sent you a message'),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    chatNotif['message'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    timeago.format(chatNotif['timestamp']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // User avatar
            if (chatNotif['senderAvatar'] != null) ...[
              SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(
                  chatNotif['senderAvatar'],
                ),
              ),
            ],
            // Unread badge
            if (chatNotif['unreadCount'] > 0) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  chatNotif['unreadCount'].toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildChatTab(CommunityState state) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Center(child: Text('Please log in to see chat notifications'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final chatDocs = snapshot.data?.docs ?? [];

        if (chatDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 16),
                Text(
                  'No chat notifications yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Chat notifications will appear here',
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
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final chatData = chatDocs[index].data() as Map<String, dynamic>;
            final chatId = chatDocs[index].id;
            return _buildChatNotificationTileFromStream(chatData, chatId, currentUserId);
          },
        );
      },
    );
  }

  Stream<int> _getChatUnreadCountStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount']?[currentUserId] ?? 0;
        totalUnread += (unreadCount as num).toInt();
      }
      return totalUnread;
    });
  }

  Future<List<Map<String, dynamic>>> _getChatNotifications() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      print('🔍 Getting chat notifications for user: $currentUserId');

      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .limit(50)
          .get();

      print('📱 Found ${chatsSnapshot.docs.length} chats');

      // Sort in Dart to avoid index requirement
      final sortedDocs = chatsSnapshot.docs;
      sortedDocs.sort((a, b) {
        final aTime = a.data()['lastMessageTime'] as Timestamp?;
        final bTime = b.data()['lastMessageTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      final limitedDocs = sortedDocs.take(20).toList();

      print('📱 Found ${chatsSnapshot.docs.length} chats');

      List<Map<String, dynamic>> notifications = [];

      for (final doc in limitedDocs) {
        final data = doc.data();
        final unreadCount = data['unreadCount']?[currentUserId] ?? 0;

        print('💬 Chat ${doc.id}: unread = $unreadCount');

        // Show all recent chats with messages, including unread ones and recent activity
        if (data['lastMessage'] != null &&
            data['lastMessage'].toString().isNotEmpty &&
            data['lastMessage'].toString() != '0') {
          final participants = List<String>.from(data['participants'] ?? []);
          final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');

          print('👤 Other user: $otherUserId');

          if (otherUserId.isNotEmpty) {
            try {
              // Get other user's name with error handling
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get();

              if (!userDoc.exists) {
                print('⚠️ User document not found for: $otherUserId');
                continue;
              }

              final userData = userDoc.data();
              final userName = userData?['fullName'] ?? 'Unknown User';
              final userAvatar = userData?['avatarUrl'];
              final lastMessage = data['lastMessage']?.toString() ?? '';
              final lastMessageTime = data['lastMessageTime'] as Timestamp?;

              // Skip if message is empty or invalid
              if (lastMessage.isEmpty || lastMessage == '0') {
                print('⚠️ Skipping chat with empty/invalid message');
                continue;
              }

              print('✅ Adding notification: $userName - $lastMessage (unread: $unreadCount)');

              notifications.add({
                'id': doc.id,
                'senderName': userName,
                'senderAvatar': userAvatar,
                'message': lastMessage,
                'unreadCount': unreadCount,
                'timestamp': lastMessageTime?.toDate() ?? DateTime.now(),
                'chatId': doc.id,
                'otherUserId': otherUserId,
                'hasUnread': unreadCount > 0,
                'isRecentActivity': lastMessageTime != null &&
                    DateTime.now().difference(lastMessageTime.toDate()).inHours < 24,
              });
            } catch (e) {
              print('❌ Error processing chat ${doc.id}: $e');
              continue;
            }
          }
        }
      }

      print('📋 Total notifications: ${notifications.length}');
      return notifications;
    } catch (e) {
      print('❌ Error getting chat notifications: $e');
      return [];
    }
  }

  Widget _buildChatNotificationTileFromStream(
  Map<String, dynamic> chatData,
  String chatId,
  String currentUserId,
  ) {
  final participants = List<String>.from(chatData['participants'] ?? []);
  final otherUserId = participants.firstWhere(
  (id) => id != currentUserId,
  orElse: () => '',
  );

  if (otherUserId.isEmpty) return SizedBox.shrink();

  final unreadCount = chatData['unreadCount']?[currentUserId] ?? 0;
  final lastMessage = chatData['lastMessage']?.toString() ?? '';
  final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;

  // Skip invalid or empty messages
  if (lastMessage.isEmpty || lastMessage == '0') return SizedBox.shrink();

  return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
  builder: (context, userSnapshot) {
  if (!userSnapshot.hasData) return SizedBox.shrink();

  final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
  final userName = userData?['fullName'] ?? 'Unknown User';
  final userAvatar = userData?['avatarUrl'];

  return InkWell(
  onTap: () {
  Navigator.push(
  context,
  MaterialPageRoute(
  builder: (context) => ChatScreen(
  contactId: otherUserId,
  contactName: userName,
  contactAvatar: userAvatar,
  isOnline: false,
  chatId: chatId,
  ),
  ),
  );
  },
  child: Container(
  color: unreadCount > 0 ? Colors.blue[50] : Colors.white,
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Row(
  children: [
  userAvatar != null
  ? CircleAvatar(
  radius: 24,
  backgroundImage: CachedNetworkImageProvider(userAvatar),
  )
      : Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
  color: Colors.blue[100],
  shape: BoxShape.circle,
  ),
  child: Icon(Icons.person, color: Colors.blue, size: 24),
  ),
  SizedBox(width: 12),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  if (lastMessageTime != null)
  Text(timeago.format(lastMessageTime.toDate()),
  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  if (lastMessage.isNotEmpty)
  Text(lastMessage,
  style: TextStyle(fontSize: 14,
  color: unreadCount > 0 ? Colors.black87 : Colors.grey[700]),
  maxLines: 2, overflow: TextOverflow.ellipsis),
  ],
  ),
  ),
  if (unreadCount > 0)
  Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
  child: Text(unreadCount > 99 ? '99+' : unreadCount.toString(),
  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
  ),
  ],
  ),
  ),
  );
  },
  );
  }
}