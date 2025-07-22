// chat_integrated.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/bloc.dart';
import '../community/models.dart';
import '../community/search_screen.dart';
import '../community/feed_screen.dart';
import '../community/community_services.dart';
import 'dart:async';
import 'video_call_screen.dart';
import 'chat.dart';

// Chat Models
class ChatContact {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final String chatId;
  final bool isPinned;
  final bool isStuckOnTop;

  ChatContact({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.chatId,
    this.isPinned = false,
    this.isStuckOnTop = false,
  });

  factory ChatContact.fromFriend(Friend friend, {String? lastMessage, DateTime? lastMessageTime, int unreadCount = 0, bool isPinned = false, bool isStuckOnTop = false}) {
    return ChatContact(
      userId: friend.friendId,
      name: friend.friendName,
      avatarUrl: friend.friendAvatar,
      lastMessage: lastMessage ?? "You became friends with ${friend.friendName}, let's start chatting!",
      lastMessageTime: lastMessageTime ?? friend.acceptedAt ?? friend.createdAt,
      unreadCount: unreadCount,
      isOnline: false,
      chatId: _generateChatId(FirebaseAuth.instance.currentUser!.uid, friend.friendId),
      isPinned: isPinned,
      isStuckOnTop: isStuckOnTop,
    );
  }

  static String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  final String? attachmentType;
  final List<TextOverlay>? textOverlays;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
    this.textOverlays,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      textOverlays: data['textOverlays'] != null
          ? (data['textOverlays'] as List).map((overlay) => TextOverlay.fromMap(overlay)).toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'textOverlays': textOverlays?.map((overlay) => overlay.toMap()).toList(),
    };
  }
}

// Main Chat Contact Page
class ChatContactPage extends StatefulWidget {
  @override
  _ChatContactPageState createState() => _ChatContactPageState();
}

class _ChatContactPageState extends State<ChatContactPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ChatContact> _contacts = [];
  List<ChatContact> _filteredContacts = [];
  bool _isLoading = true;
  bool _hasFriends = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFriendsAsContacts();
    _setupRealtimeContactUpdates();
    _startPeriodicRefresh();
    _listenForIncomingCalls();
  }

  void _setupRealtimeContactUpdates() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _firestore
        .collection('friends')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
      print('🔄 Friends collection changed, refreshing contacts...');
      _loadFriendsAsContacts();
    });

    _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      print('🔄 Chat documents changed, refreshing contacts...');
      _loadFriendsAsContacts();
    });
  }

  Future<void> _loadFriendsAsContacts() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final friendsSnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      _hasFriends = friendsSnapshot.docs.isNotEmpty;
      List<ChatContact> contacts = [];

      for (final doc in friendsSnapshot.docs) {
        final friend = Friend.fromFirestore(doc);

        final isFriend = await _verifyMutualFriendship(currentUserId, friend.friendId);
        if (!isFriend) {
          print('⚠️ Skipping non-mutual friend: ${friend.friendName}');
          continue;
        }

        final chatId = ChatContact._generateChatId(currentUserId, friend.friendId);
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
          await _createChat(currentUserId, friend);
        }

        final chatData = chatDoc.data();
        String lastMessage;
        DateTime lastMessageTime;
        int unreadCount;
        bool isPinned = false;
        bool isStuckOnTop = false;

        if (chatData != null) {
          lastMessage = chatData['lastMessage'] ?? "I've accepted your friend request. Now let's chat!";
          lastMessageTime = chatData['lastMessageTime'] != null
              ? (chatData['lastMessageTime'] as Timestamp).toDate()
              : friend.acceptedAt ?? friend.createdAt;
          unreadCount = chatData['unreadCount']?[currentUserId] ?? 0;
          isPinned = chatData['isPinned'] ?? false;
          isStuckOnTop = chatData['isStuckOnTop'] ?? false;
        } else {
          lastMessage = "You became friends with ${friend.friendName}";
          lastMessageTime = friend.acceptedAt ?? friend.createdAt;
          unreadCount = 0;
          isPinned = false;
          isStuckOnTop = false;
        }

        contacts.add(ChatContact.fromFriend(
          friend,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          unreadCount: unreadCount,
          isPinned: isPinned,
          isStuckOnTop: isStuckOnTop,
        ));
      }

      contacts.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading friends as contacts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> forceRefresh() async {
    print('🔄 Force refreshing chat contacts...');
    setState(() {
      _isLoading = true;
    });
    await _loadFriendsAsContacts();
  }

  void _startPeriodicRefresh() {
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadFriendsAsContacts();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _createChat(String currentUserId, Friend friend) async {
    final chatId = ChatContact._generateChatId(currentUserId, friend.friendId);

    try {
      final existingChat = await _firestore.collection('chats').doc(chatId).get();
      if (existingChat.exists) {
        print('💬 Chat already exists: $chatId');
        return;
      }

      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['fullName'] ?? 'You';
      final welcomeMessage = "You became friends with ${friend.friendName}, let's start chatting!";

      await _firestore.collection('chats').doc(chatId).set({
        'participants': [currentUserId, friend.friendId],
        'participantNames': {
          currentUserId: currentUserName,
          friend.friendId: friend.friendName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': welcomeMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUserId: 0,
          friend.friendId: 0,
        },
        'chatType': 'friend_chat',
      }, SetOptions(merge: true));

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': welcomeMessage,
        'senderId': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
        'isSystemMessage': true,
      });
    } catch (e) {
      print('Error creating chat: $e');
    }
  }

  Future<bool> _verifyMutualFriendship(String userId1, String userId2) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for friendship verification');
        return false;
      }

      try {
        await user.getIdToken(true);
      } catch (authError) {
        print('⚠️ Auth refresh failed: $authError');
      }

      final query1 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .where('status', isEqualTo: 'accepted')
          .get();

      final query2 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId2)
          .where('friendId', isEqualTo: userId1)
          .where('status', isEqualTo: 'accepted')
          .get();

      bool areFriends = query1.docs.isNotEmpty && query2.docs.isNotEmpty;
      print('🔍 Friendship verification: $userId1 <-> $userId2 = $areFriends');

      return areFriends;
    } catch (e) {
      print('❌ Error verifying friendship: $e');
      return false;
    }
  }

  Future<void> refreshContacts() async {
    print('🔄 Manually refreshing contacts...');
    await _loadFriendsAsContacts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _loadFriendsAsContacts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? _buildEmptyState()
          : _buildContactsList(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: _isSearching
          ? TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey),
        ),
        style: TextStyle(color: Colors.black),
        onChanged: (value) {
          setState(() {
            _filteredContacts = _contacts
                .where((contact) =>
                contact.name.toLowerCase().contains(value.toLowerCase()))
                .toList();
          });
        },
      )
          : Text(
        'Messages',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _filteredContacts = _contacts;
              }
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            _hasFriends ? 'No messages yet' : 'No friends yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _hasFriends
                ? 'Start a conversation with your friends!'
                : 'Add friends to start chatting!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          if (!_hasFriends) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final userDoc = await _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .get();

                  final organizationCode = userDoc.data()?['organizationCode'] ?? '';

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedScreen(
                        organizationCode: organizationCode,
                        initialTab: 1,
                      ),
                    ),
                        (route) => false,
                  );
                } catch (e) {
                  print('Error navigating to find friends: $e');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchScreen(
                        organizationCode: '',
                        initialTab: SearchScreenTab.search,
                      ),
                    ),
                  );
                }
              },
              icon: Icon(Icons.person_add),
              label: Text('Find Friends'),
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
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    final displayContacts = _isSearching ? _filteredContacts : _contacts;

    displayContacts.sort((a, b) {
      if (a.isStuckOnTop && !b.isStuckOnTop) return -1;
      if (!a.isStuckOnTop && b.isStuckOnTop) return 1;
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return ListView.builder(
      itemCount: displayContacts.length,
      itemBuilder: (context, index) {
        final contact = displayContacts[index];
        return _buildContactTile(contact);
      },
    );
  }

  Widget _buildContactTile(ChatContact contact) {
    return Dismissible(
      key: Key(contact.chatId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: contact.isPinned ? Colors.orange : Colors.blue,
        child: Icon(
          contact.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        await _togglePinChat(contact.chatId, !contact.isPinned);
        return false;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: contact.isStuckOnTop
            ? Colors.grey[200]
            : contact.isPinned
            ? Colors.grey[50]
            : null,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  contactId: contact.userId,
                  contactName: contact.name,
                  contactAvatar: contact.avatarUrl,
                  isOnline: contact.isOnline,
                  chatId: contact.chatId,
                ),
              ),
            ).then((_) => _loadFriendsAsContacts());
          },
          onLongPress: () => _showChatOptions(contact),
          child: Row(
            children: [
              _buildContactAvatar(contact),
              SizedBox(width: 12),
              _buildContactInfo(contact),
              _buildContactMeta(contact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactAvatar(ChatContact contact) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[300],
          backgroundImage: contact.avatarUrl != null
              ? CachedNetworkImageProvider(contact.avatarUrl!)
              : null,
          child: contact.avatarUrl == null
              ? Text(
            contact.name[0],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          )
              : null,
        ),
        if (contact.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactInfo(ChatContact contact) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            contact.lastMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContactMeta(ChatContact contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          timeago.format(contact.lastMessageTime),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        SizedBox(height: 4),
        if (contact.unreadCount > 0)
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Text(
              contact.unreadCount.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _togglePinChat(String chatId, bool isPinned) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'isPinned': isPinned,
        'pinnedAt': isPinned ? FieldValue.serverTimestamp() : null,
      });
      _loadFriendsAsContacts();
    } catch (e) {
      print('Error toggling pin: $e');
    }
  }

  void _showChatOptions(ChatContact contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                contact.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: contact.isPinned ? Colors.orange : Colors.blue,
              ),
              title: Text(contact.isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                Navigator.pop(context);
                _togglePinChat(contact.chatId, !contact.isPinned);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                _deleteChat(contact.chatId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    // Implement delete chat functionality
  }

  // ✅ INCOMING CALL METHODS - INSIDE THE CLASS
  void _listenForIncomingCalls() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _firestore
        .collection('videoCalls')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final callData = change.doc.data() as Map<String, dynamic>;
          _showIncomingCallDialog(
            callData['callId'],
            callData['callerId'],
            callData['callerName'] ?? 'Unknown',
          );
        }
      }
    });
  }

  void _showIncomingCallDialog(String callId, String callerId, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Incoming Video Call'),
        content: Text('$callerName is calling you'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _firestore.collection('videoCalls').doc(callId).update({
                'status': 'declined',
              });
            },
            child: Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    contactName: callerName,
                    callId: callId,
                    isIncoming: true,
                  ),
                ),
              );
            },
            child: Text('Answer'),
          ),
        ],
      ),
    );
  }
}

// ✅ SINGLE ChatScreen CLASS
class ChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactAvatar;
  final bool isOnline;
  final String chatId;

  ChatScreen({
    required this.contactId,
    required this.contactName,
    this.contactAvatar,
    required this.isOnline,
    required this.chatId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _showEmojiPicker = false;
  bool _isVerifiedFriend = false;
  ChatMessage? _replyingToMessage;
  bool _isReplying = false;
  bool _isSearching = false;
  String _searchQuery = '';
  List<ChatMessage> _searchResults = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verifyFriendshipBeforeChat();
  }

  Future<void> _verifyFriendshipBeforeChat() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.pop(context);
      return;
    }

    final isFriend = await _verifyMutualFriendship(currentUserId, widget.contactId);

    if (!isFriend) {
      print('❌ Cannot chat - not mutual friends');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can only chat with friends')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isVerifiedFriend = true;
    });

    _markMessagesAsRead();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  Future<bool> _verifyMutualFriendship(String userId1, String userId2) async {
    try {
      final query1 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .where('status', isEqualTo: 'accepted')
          .get();

      final query2 = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: userId2)
          .where('friendId', isEqualTo: userId1)
          .where('status', isEqualTo: 'accepted')
          .get();

      return query1.docs.isNotEmpty && query2.docs.isNotEmpty;
    } catch (e) {
      print('Error verifying friendship: $e');
      return false;
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['senderId'] != currentUserId) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      batch.update(
        _firestore.collection('chats').doc(widget.chatId),
        {'unreadCount.${currentUserId}': 0},
      );

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVerifiedFriend) {
      return Scaffold(
        appBar: AppBar(title: Text('Verifying...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true,
      appBar: _buildChatAppBar(),
      body: GestureDetector(
        onTap: () {
          _focusNode.unfocus();
          setState(() {
            _showEmojiPicker = false;
          });
        },
        child: Column(
          children: [
            if (_isSearching) _buildSearchBar(),
            Expanded(child: _buildMessagesList()),
            if (_showEmojiPicker) _buildEmojiPicker(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  AppBar _buildChatAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: widget.contactAvatar != null
                ? CachedNetworkImageProvider(widget.contactAvatar!)
                : null,
            child: widget.contactAvatar == null
                ? Text(
              widget.contactName[0],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.isOnline ? "Active now" : "Offline",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.videocam, color: Colors.blue),
          onPressed: () => _initiateVideoCall(),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.black),
          onSelected: (value) {
            switch (value) {
              case 'search':
                _toggleSearch();
                break;
              case 'stick_top':
                _toggleStickOnTop();
                break;
              case 'clear_chat':
                _showClearChatDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Search Messages'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'stick_top',
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('chats').doc(widget.chatId).snapshots(),
                builder: (context, snapshot) {
                  bool isStuckOnTop = false;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    isStuckOnTop = data?['isStuckOnTop'] ?? false;
                  }
                  return Row(
                    children: [
                      Icon(Icons.push_pin, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Stick on Top'),
                      Spacer(),
                      Switch(
                        value: isStuckOnTop,
                        onChanged: (value) {
                          Navigator.pop(context);
                          _toggleStickOnTop();
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  );
                },
              ),
            ),
            PopupMenuItem(
              value: 'clear_chat',
              child: Row(
                children: [
                  Icon(Icons.clear_all, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Clear Chat'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _searchResults.clear();
      }
    });
  }

  Future<void> _toggleStickOnTop() async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      final currentStickStatus = chatDoc.data()?['isStuckOnTop'] ?? false;

      await _firestore.collection('chats').doc(widget.chatId).update({
        'isStuckOnTop': !currentStickStatus,
        'stuckOnTopAt': !currentStickStatus ? FieldValue.serverTimestamp() : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentStickStatus
              ? 'Chat stuck on top'
              : 'Chat unstuck from top'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error toggling stick on top: $e');
    }
  }

  void _searchMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[100],
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: _toggleSearch,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          fillColor: Colors.white,
          filled: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _searchMessages,
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Chat'),
        content: Text('Are you sure you want to clear all messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllMessages();
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllMessages() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Clearing chat...'),
              ],
            ),
          ),
        ),
      );

      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.update(
        _firestore.collection('chats').doc(widget.chatId),
        {
          'lastMessage': 'Chat cleared',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount.${_auth.currentUser?.uid}': 0,
          'unreadCount.${widget.contactId}': 0,
        },
      );

      await batch.commit();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat cleared successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print('Error clearing chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear chat: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var messages = snapshot.data!.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList();

        if (_isSearching && _searchQuery.isNotEmpty) {
          messages = messages.where((message) =>
              message.text.toLowerCase().contains(_searchQuery)).toList();
        }

        if (messages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Say hi!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == _auth.currentUser?.uid;
            final isSystemMessage = message.senderId == 'system';

            if (isSystemMessage) {
              return _buildSystemMessage(message);
            }

            return _buildMessageBubble(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message, isMe),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.attachmentType == 'image')
                _buildImageMessage(message),
              if (message.attachmentType == 'file')
                _buildFileMessage(message, isMe),
              if (message.text.isNotEmpty &&
                  message.text != "📷 Photo" &&
                  message.attachmentType != 'image')
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: message.isRead ? Colors.blue[200] : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message, bool isMe) {
    setState(() {
      _showEmojiPicker = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.reply, color: Colors.blue),
              title: Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(Duration(milliseconds: 200), () {
                  _replyToMessage(message);
                });
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: Icon(Icons.edit, color: Colors.orange),
                title: Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _replyToMessage(ChatMessage message) {
    setState(() {
      _replyingToMessage = message;
      _isReplying = true;
    });

    Future.delayed(Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  void _editMessage(ChatMessage message) {
    setState(() {
      _messageController.text = message.text;
    });
    _focusNode.requestFocus();
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .doc(message.id)
                    .delete();
              } catch (e) {
                print('Error deleting message: $e');
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
      _isReplying = false;
    });
  }

  Widget _buildImageMessage(ChatMessage message) {
    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[300],
          ),
          child: Center(
            child: Icon(
              Icons.image,
              size: 50,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage(ChatMessage message, bool isMe) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 16,
            color: isMe ? Colors.white : Colors.black,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              "document.pdf",
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      children: [
        if (_isReplying) _buildReplyPreview(),
        Container(
          padding: EdgeInsets.all(8),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                  onPressed: () => _showFileOptions(),
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                  onPressed: () => _openCamera(),
                ),
                Expanded(child: _buildTextInputField()),
                SizedBox(width: 8),
                _buildSendButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingToMessage == null) return SizedBox.shrink();

    final isMyMessage = _replyingToMessage!.senderId == _auth.currentUser?.uid;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12),
          Icon(Icons.reply, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMyMessage ? 'You' : widget.contactName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _replyingToMessage!.text.length > 30
                      ? '${_replyingToMessage!.text.substring(0, 30)}...'
                      : _replyingToMessage!.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Write your message",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                _sendMessage(text: text);
              },
            ),
          ),
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
              color: Colors.grey[600],
            ),
            onPressed: () {
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
              });
              if (_showEmojiPicker) {
                _focusNode.unfocus();
              } else {
                _focusNode.requestFocus();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: () => _sendMessage(text: _messageController.text),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    List<String> emojis = [
      "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣",
      "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰",
      "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜",
      "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏",
      "👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙",
      "👈", "👉", "👆", "🖕", "👇", "☝️", "👋", "🤚",
      "❤️", "💙", "💚", "💛", "🧡", "💜", "🖤", "🤍"
    ];

    return Container(
      height: 250,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Text(
                  "Tap an emoji to add it",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.backspace, color: Colors.grey[600]),
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _messageController.text = _messageController.text
                          .substring(0, _messageController.text.length - 1);
                      _messageController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _messageController.text.length),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _messageController.text += emojis[index];
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    margin: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Center(
                      child: Text(
                        emojis[index],
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage({required String text, String? attachmentType, List<TextOverlay>? textOverlays}) async {
    if (text.trim().isEmpty && attachmentType == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      Map<String, dynamic> messageData = {
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'attachmentType': attachmentType,
        'textOverlays': textOverlays?.map((overlay) => overlay.toMap()).toList(),
      };

      if (_isReplying && _replyingToMessage != null) {
        messageData['replyTo'] = {
          'messageId': _replyingToMessage!.id,
          'text': _replyingToMessage!.text,
          'senderId': _replyingToMessage!.senderId,
          'timestamp': _replyingToMessage!.timestamp.toIso8601String(),
        };
      }

      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': attachmentType != null ? '${attachmentType == 'image' ? '📷' : '📎'} ${text.trim()}' : text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.contactId}': FieldValue.increment(1),
      });

      _messageController.clear();
      _cancelReply();
      _scrollToBottom();
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          onImageCaptured: (text, textOverlays) {
            _sendMessage(
              text: text.isNotEmpty ? text : '📷 Photo',
              attachmentType: 'image',
              textOverlays: textOverlays,
            );
          },
        ),
      ),
    );
  }

  void _initiateVideoCall() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.videocam, color: Colors.blue),
            SizedBox(width: 8),
            Text('Video Call'),
          ],
        ),
        content: Text('Start a video call with ${widget.contactName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    contactName: widget.contactName,
                    contactAvatar: widget.contactAvatar,
                    targetUserId: widget.contactId,
                    isIncoming: false,
                  ),
                ),
              );
            },
            child: Text('Call'),
          ),
        ],
      ),
    );
  }

  void _showFileOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: Colors.blue),
              title: Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _sendFileMessage('document', 'document.pdf');
              },
            ),
            ListTile(
              leading: Icon(Icons.image, color: Colors.green),
              title: Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _sendFileMessage('image', 'photo.jpg');
              },
            ),
            ListTile(
              leading: Icon(Icons.audiotrack, color: Colors.orange),
              title: Text('Audio'),
              onTap: () {
                Navigator.pop(context);
                _sendFileMessage('audio', 'audio.mp3');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendFileMessage(String type, String fileName) {
    _sendMessage(
      text: fileName,
      attachmentType: type,
    );
  }
}