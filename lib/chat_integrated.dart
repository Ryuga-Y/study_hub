// chat_integrated.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../community/models.dart';
import '../community/search_screen.dart';
import '../community/feed_screen.dart';
import 'dart:async';
import 'video_call_screen.dart';
import 'chat.dart' show TextOverlay, CameraScreen, PhotoEditScreen;
import 'incoming_call_screen.dart';
import 'video_call_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;

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
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';
    print('🔧 Generated chat ID: $chatId for users: $userId1, $userId2');
    return chatId;
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
  final int? videoDuration;
  final String? messageType;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
    this.textOverlays,
    this.videoDuration,
    this.messageType,
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
      videoDuration: data['videoDuration'],
      messageType: data['messageType'], // ADD THIS LINE
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'text': text,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (attachmentUrl != null) map['attachmentUrl'] = attachmentUrl;
    if (attachmentType != null) map['attachmentType'] = attachmentType;
    if (textOverlays != null) map['textOverlays'] = textOverlays!.map((overlay) => overlay.toMap()).toList();
    if (videoDuration != null) map['videoDuration'] = videoDuration;

    return map;
  }
}

// Main Chat Contact Page
class ChatContactPage extends StatefulWidget {
  @override
  _ChatContactPageState createState() => _ChatContactPageState();
}

class _ChatContactPageState extends State<ChatContactPage> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ChatContact> _contacts = [];
  List<ChatContact> _filteredContacts = [];
  bool _isLoading = true;
  bool _hasFriends = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Add these new variables
  Timer? _refreshTimer;
  StreamSubscription? _friendsSubscription;
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _incomingCallSubscription; // ADD THIS LINE

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ADD THIS LINE
    _loadFriendsAsContacts();
    _setupRealtimeContactUpdates();
    _startPeriodicRefresh();
    _listenForIncomingCalls();
    _cleanupOldCalls();
  }

  Future<void> _cleanupOldCalls() async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(minutes: 2));
      final oldCalls = await _firestore
          .collection('videoCalls')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .where('status', whereIn: ['calling', 'answered'])
          .get();

      final batch = _firestore.batch();
      for (final doc in oldCalls.docs) {
        batch.delete(doc.reference);
      }

      if (oldCalls.docs.isNotEmpty) {
        await batch.commit();
        print('🗑️ Cleaned up ${oldCalls.docs.length} old call documents');
      }
    } catch (e) {
      print('Error cleaning up old calls: $e');
    }
  }

  void _setupRealtimeContactUpdates() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Cancel existing subscriptions
    _friendsSubscription?.cancel();
    _chatsSubscription?.cancel();

    _friendsSubscription = _firestore
        .collection('friends')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) {
      print('🔄 Friends collection changed, refreshing contacts...');
      if (mounted) {
        _loadFriendsAsContacts();
      }
    });

    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      print('🔄 Chat documents changed, refreshing contacts...');
      if (mounted) {
        _loadFriendsAsContacts();
      }
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

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading friends as contacts: $e');if (mounted) {
        setState(() => _isLoading = false);
      }
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
  _refreshTimer?.cancel(); // Cancel any existing timer
  _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
    if (mounted) {
      _loadFriendsAsContacts();
    } else {
      timer.cancel();
    }
  });
}

  Future<void> _createChat(String currentUserId, Friend friend) async {
    final chatId = ChatContact._generateChatId(currentUserId, friend.friendId);
    print('🔧 Creating chat with ID: $chatId');

    try {
      final existingChat = await _firestore.collection('chats').doc(chatId).get();
      if (existingChat.exists) {
        print('💬 Chat already exists: $chatId');
        return; // Don't create system message again
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat'),
        content: Text('Are you sure you want to delete this chat? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performChatDeletion(chatId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performChatDeletion(String chatId) async {
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
                Text('Deleting chat...'),
              ],
            ),
          ),
        ),
      );

      // Delete all messages in batches
      const int batchSize = 500;
      bool hasMore = true;

      while (hasMore) {
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .limit(batchSize)
            .get();

        if (messagesSnapshot.docs.isEmpty) {
          hasMore = false;
          continue;
        }

        final batch = _firestore.batch();
        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        hasMore = messagesSnapshot.docs.length == batchSize;
      }

      // Delete the chat document itself
      await _firestore.collection('chats').doc(chatId).delete();

      Navigator.pop(context); // Close loading dialog
      _loadFriendsAsContacts(); // Refresh the contact list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chat deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('Error deleting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete chat: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ✅ INCOMING CALL METHODS - INSIDE THE CLASS
// ADD THIS as a class-level variable at the top of _ChatContactPageState
  Set<String> _handledCallIds = Set<String>();

  void _listenForIncomingCalls() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _incomingCallSubscription?.cancel();

    _incomingCallSubscription = _firestore
        .collection('videoCalls')
        .where('targetId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // Only handle added documents, not modified ones
        if (change.type == DocumentChangeType.added) {
          final callData = change.doc.data() as Map<String, dynamic>?;
          if (callData == null) continue;

          // Check status again to ensure it's still 'calling'
          if (callData['status'] != 'calling') {
            print('⚠️ Ignoring call with status: ${callData['status']}');
            continue;
          }

          final callId = callData['callId'];
          final callerId = callData['callerId'];

          // Prevent self-calling
          if (callerId == currentUserId) {
            print('⚠️ Ignoring self-initiated call: $callId');
            continue;
          }

          // Skip if already handled
          if (_handledCallIds.contains(callId)) {
            print('⚠️ Call already handled: $callId');
            continue;
          }

          // Check if call is recent (within 30 seconds)
          final createdAt = callData['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final callTime = createdAt.toDate();
            final timeDifference = DateTime.now().difference(callTime).inSeconds;

            if (timeDifference <= 30) {
              _handledCallIds.add(callId);
              _showIncomingCallDialog(callId, callerId, callData['callerName'] ?? 'Unknown');
            } else {
              print('⚠️ Ignoring old call: $timeDifference seconds old');
              _handledCallIds.add(callId);
            }
          } else {
            print('⚠️ Ignoring call without timestamp: $callId');
            _handledCallIds.add(callId);
          }
        }
      }
    }, onError: (error) {
      print('Error listening for incoming calls: $error');
    });

    // Add cleanup timer
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final oldCallIds = <String>[];

      for (final callId in _handledCallIds) {
        final parts = callId.split('_');
        if (parts.length >= 2) {
          final timestamp = int.tryParse(parts.last);
          if (timestamp != null) {
            final callTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            if (now.difference(callTime).inMinutes > 5) {
              oldCallIds.add(callId);
            }
          }
        }
      }

      for (final oldId in oldCallIds) {
        _handledCallIds.remove(oldId);
      }

      if (oldCallIds.isNotEmpty) {
        print('🧹 Cleaned up ${oldCallIds.length} old handled call IDs');
      }
    });
  }

  void _showIncomingCallDialog(String callId, String callerId, String callerName) {
    print('📞 Showing incoming call from: $callerName (ID: $callerId)');

    if (!mounted) {
      print('⚠️ Widget unmounted, skipping incoming call dialog');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          onAccept: () {
            print('✅ Call accepted');
            Navigator.pushReplacement(
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
          onDecline: () async {
            print('❌ Call declined');
            try {
              await _firestore.collection('videoCalls').doc(callId).update({
                'status': 'declined',
                'declinedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              print('Error declining call: $e');
              // If update fails, try to delete
              try {
                await _firestore.collection('videoCalls').doc(callId).delete();
              } catch (e2) {
                print('Error deleting call: $e2');
              }
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _friendsSubscription?.cancel();
    _chatsSubscription?.cancel();
    // DON'T cancel incoming call subscription on dispose
    // Only cancel if widget is being permanently removed
    if (!mounted) {
      _incomingCallSubscription?.cancel();
    }

    // Clear handled calls to prevent memory leaks
    _handledCallIds.clear();

    WidgetsBinding.instance.removeObserver(this); // ADD THIS LINE

    super.dispose();
  }

// Add this method to restart listening when returning from video call
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Restart listening when app resumes
      _listenForIncomingCalls();
    }
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
    // Remove any _listenForIncomingCalls() call from here if it exists
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

    // Ensure chat document exists before marking messages as read
    try {
      final chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
      if (!chatDoc.exists) {
        print('⚠️ Chat document does not exist, creating it first');
        await _ensureChatExists(currentUserId);
      }
    } catch (e) {
      print('Error checking chat existence: $e');
    }

    _markMessagesAsRead();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });

    // ✅ ADD THIS: Auto-scroll to bottom when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _ensureChatExists(String currentUserId) async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).set({
        'participants': [currentUserId, widget.contactId],
        'participantNames': {
          currentUserId: 'You',
          widget.contactId: widget.contactName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUserId: 0,
          widget.contactId: 0,
        },
        'chatType': 'friend_chat',
      }, SetOptions(merge: true));

      print('✅ Chat document created/updated: ${widget.chatId}');
    } catch (e) {
      print('Error ensuring chat exists: $e');
    }
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

      // Delete all messages in batches (Firestore batch limit is 500)
      const int batchSize = 500;
      bool hasMore = true;

      while (hasMore) {
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .limit(batchSize)
            .get();

        if (messagesSnapshot.docs.isEmpty) {
          hasMore = false;
          continue;
        }

        final batch = _firestore.batch();

        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        // Check if there are more messages
        hasMore = messagesSnapshot.docs.length == batchSize;
      }

      // Update the chat document with system message
      final currentUserId = _auth.currentUser?.uid;
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserName = currentUserDoc.data()?['fullName'] ?? 'Someone';

      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': '$currentUserName cleared the chat',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.$currentUserId': 0,
        'unreadCount.${widget.contactId}': 0,
      });

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

        // ✅ Auto-scroll to bottom for new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            // Add a small delay to ensure messages are fully rendered
            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted && _scrollController.hasClients) {
                _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
              }
            });
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(16),
          reverse: false,  // ✅ Show messages in normal order
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
              if (message.attachmentType == 'video')
                _buildVideoMessage(message, isMe),
              if (message.attachmentType == 'file')
                _buildFileMessage(message, isMe),
              if (message.text.isNotEmpty &&
                  message.text != "📷 Photo" &&
                  message.text != "🎥 Video" &&
                  message.attachmentType != 'image')
                _buildMessageText(message, isMe),
              SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                      ),
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

  // ADD THIS METHOD RIGHT AFTER _buildMessageBubble method in _ChatScreenState class
  Widget _buildMessageText(ChatMessage message, bool isMe) {
    // Check if it's a call record by looking for "Video call" pattern
    if (message.text.startsWith('Video call\n') || message.messageType == 'call_record') {
      final lines = message.text.split('\n');
      return Container(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.videocam,
                    size: 16,
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  lines[0], // "Video call"
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (lines.length > 1)
              Padding(
                padding: EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  lines[1].replaceAll(RegExp(r' • \d+ joined'), ''), // Remove "• X joined" part
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Regular text message
    return Text(
      message.text,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black,
        fontSize: 16,
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
                // Delete the message document
                await _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .doc(message.id)
                    .delete();

                // Update last message in chat if this was the last message
                final messagesSnapshot = await _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get();

                if (messagesSnapshot.docs.isNotEmpty) {
                  final lastMessage = ChatMessage.fromFirestore(messagesSnapshot.docs.first);
                  await _firestore.collection('chats').doc(widget.chatId).update({
                    'lastMessage': lastMessage.text.isNotEmpty ? lastMessage.text :
                    (lastMessage.attachmentType == 'image' ? '📷 Photo' :
                    lastMessage.attachmentType == 'video' ? '🎥 Video' : '📎 File'),
                    'lastMessageTime': lastMessage.timestamp,
                  });
                } else {
                  // No messages left
                  await _firestore.collection('chats').doc(widget.chatId).update({
                    'lastMessage': 'No messages',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message deleted'), backgroundColor: Colors.green),
                );
              } catch (e) {
                print('Error deleting message: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete message'), backgroundColor: Colors.red),
                );
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
        GestureDetector(
          onTap: () => _viewFullImage(message),
          child: Container(
            height: 150,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[300],
            ),
            child: Stack(
              children: [
                // ✅ SHOW ACTUAL IMAGE IF URL EXISTS
                if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: message.attachmentUrl!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[600],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                // Fallback placeholder
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Photo',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Text overlays
                if (message.textOverlays != null)
                  ...message.textOverlays!.map((overlay) {
                    double scale = 0.3;
                    return Positioned(
                      left: overlay.position.dx * scale,
                      top: overlay.position.dy * scale,
                      child: Text(
                        overlay.text,
                        style: TextStyle(
                          fontSize: overlay.fontSize * scale,
                          color: overlay.color,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 1,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                // View icon overlay
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildVideoMessage(ChatMessage message, bool isMe) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _playVideo(message),
          child: Container(
            height: 150,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[300],
            ),
            child: Stack(
              children: [
                if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 50,
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Video${message.videoDuration != null ? ' (${message.videoDuration}s)' : ''}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Video${message.videoDuration != null ? ' (${message.videoDuration}s)' : ''}',
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
          ),
        ),
      ],
    );
  }

  void _playVideo(ChatMessage message) {
    // Implement video player functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video Player'),
        content: Text('Video playback functionality will be implemented here.\nVideo URL: ${message.attachmentUrl ?? 'No URL'}\nDuration: ${message.videoDuration ?? 'Unknown'} seconds'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add this new method
  void _viewFullImage(ChatMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageViewer(
          imageUrl: message.attachmentUrl,
          caption: message.text != '📷 Photo' && message.text.isNotEmpty ? message.text : null,
          senderName: message.senderId == _auth.currentUser?.uid ? 'You' : widget.contactName,
          timestamp: message.timestamp,
          textOverlays: message.textOverlays,
        ),
      ),
    );
  }

  Widget _buildFileMessage(ChatMessage message, bool isMe) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            _getFileIcon(message.text),
            size: 16,
            color: isMe ? Colors.white : Colors.black,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              message.text.isNotEmpty ? message.text : "document.pdf",
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

  Widget _buildSimpleVideoPreview() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: Colors.white,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Video Ready to Send',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Duration: 0 seconds', // FIXED: Removed widget.recordingDuration
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Preview not available',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get file icon
  IconData _getFileIcon(String fileName) {
    String ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.attach_file;
    }
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
                      String currentText = _messageController.text;

                      // Use Flutter's built-in method to handle complex Unicode characters
                      final textSelection = _messageController.selection;
                      final newSelection = textSelection.copyWith(
                        baseOffset: textSelection.start,
                        extentOffset: textSelection.end,
                      );

                      if (newSelection.start > 0) {
                        final newText = currentText.replaceRange(
                          newSelection.start - 1,
                          newSelection.end,
                          '',
                        );

                        _messageController.value = _messageController.value.copyWith(
                          text: newText,
                          selection: TextSelection.collapsed(offset: newSelection.start - 1),
                        );
                      }
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

  Future<void> _sendMessage({required String text, String? attachmentType, String? attachmentUrl, List<TextOverlay>? textOverlays, int? videoDuration}) async {
    if (text.trim().isEmpty && attachmentType == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Base message data - always include these fields
      Map<String, dynamic> messageData = {
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add optional fields based on message type
      if (attachmentType != null) {
        messageData['attachmentType'] = attachmentType;

        // Add type-specific fields with null safety
        switch (attachmentType) {
          case 'image':
            if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
              messageData['attachmentUrl'] = attachmentUrl;
            }
            if (textOverlays != null && textOverlays.isNotEmpty) {
              try {
                messageData['textOverlays'] = textOverlays.map((overlay) => overlay.toMap()).toList();
              } catch (e) {
                print('Error serializing textOverlays: $e');
              }
            }
            break;
          case 'video':
            if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
              messageData['attachmentUrl'] = attachmentUrl;
            }
            if (videoDuration != null && videoDuration > 0) {
              messageData['videoDuration'] = videoDuration;
            }
            break;
          case 'file':
            if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
              messageData['attachmentUrl'] = attachmentUrl;
            }
            // Add file metadata
            messageData['fileName'] = 'document.pdf'; // You can make this dynamic
            break;
        }
      }

      if (_isReplying && _replyingToMessage != null) {
        messageData['replyTo'] = {
          'messageId': _replyingToMessage!.id,
          'text': _replyingToMessage!.text,
          'senderId': _replyingToMessage!.senderId,
          'timestamp': _replyingToMessage!.timestamp.toIso8601String(),
        };
      }

      final docRef = await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      await _markMessageAsReadAfterCreation(docRef.id);

      String displayText = text.trim();
      if (attachmentType != null) {
        switch (attachmentType) {
          case 'image':
            displayText = text.trim().isNotEmpty ? '📷 ${text.trim()}' : '📷 Photo';
            break;
          case 'video':
            displayText = text.trim().isNotEmpty ? '🎥 ${text.trim()}' : '🎥 Video';
            break;
          case 'file':
            displayText = text.trim().isNotEmpty ? '📎 ${text.trim()}' : '📎 File';
            break;
        }
      }

      // ✅ ADD THIS: Update the chat document with last message info
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': displayText,
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

  Future<void> _markMessageAsReadAfterCreation(String messageId) async {
    try {
      // Don't update isRead to false for messages we just sent
      // The message should remain unread for the recipient
      print('Message created with ID: $messageId');
    } catch (e) {
      print('Error in message creation callback: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,  // ✅ Correct direction
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
          onImageCaptured: (text, textOverlays, imageUrl) {
            // Check if it's a video or image based on content
            if (text.contains('🎥') || text.toLowerCase().contains('video')) {
              // Extract duration if it's in the text
              int? duration;
              RegExp durationRegex = RegExp(r'\((\d+)s\)');
              Match? match = durationRegex.firstMatch(text);
              if (match != null) {
                duration = int.tryParse(match.group(1) ?? '');
              }

              _sendMessage(
                text: text.isNotEmpty ? text : '🎥 Video',
                attachmentType: 'video',
                attachmentUrl: imageUrl, // ✅ ADD THIS BACK
                videoDuration: duration,
              );
            } else {
              _sendMessage(
                text: text.isNotEmpty ? text : '📷 Photo',
                attachmentType: 'image',
                attachmentUrl: imageUrl, // ✅ ADD THIS BACK
                textOverlays: textOverlays,
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _initiateVideoCall() async {
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
            onPressed: () async {
              Navigator.pop(context);

              // Create call document in Firebase first
              final callId = await _createOutgoingCall();
              if (callId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoCallScreen(
                      contactName: widget.contactName,
                      contactAvatar: widget.contactAvatar,
                      targetUserId: widget.contactId,
                      callId: callId,
                      isIncoming: false,
                    ),
                  ),
                );
              }
            },
            child: Text('Call'),
          ),
        ],
      ),
    );
  }

  Future<String?> _createOutgoingCall() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('❌ No current user for video call');
        return null;
      }

      final callId = _firestore.collection('videoCalls').doc().id;
      print('🔧 Creating video call: $callId from ${currentUser.uid} to ${widget.contactId}');

      await _firestore.collection('videoCalls').doc(callId).set({
        'callId': callId,
        'callerId': currentUser.uid,
        'callerName': currentUser.displayName ?? 'Unknown',
        'targetId': widget.contactId,
        'targetName': widget.contactName,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return callId;
    } catch (e) {
      print('Error creating call: $e');
      return null;
    }
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
                _pickDocument();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo, color: Colors.green),
              title: Text('Photo'),
              subtitle: Text('From Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: Colors.purple),
              title: Text('Video'),
              subtitle: Text('From Drive'),
              onTap: () {
                Navigator.pop(context);
                _pickVideoFromDrive();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideoFromDrive() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 50MB for videos)
        if (file.size > 50 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video size exceeds 50MB limit'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Show loading
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
                  Text('Uploading video...'),
                  SizedBox(height: 8),
                  Text(
                    'Max duration: 1 minute',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        // Upload video
        final downloadUrl = await _uploadFileToStorage(file, 'videos');
        Navigator.pop(context); // Close loading dialog

        if (downloadUrl != null) {
          // Send message with video
          await _sendMessage(
            text: '🎥 Video from drive',
            attachmentType: 'video',
            attachmentUrl: downloadUrl,
            videoDuration: 0, // Duration unknown from drive picker
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      print('Error picking video from drive: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add this method inside the _ChatScreenState class, after the _pickVideoFromDrive() method

  Future<void> _pickImageFromGallery() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 10MB for images)
        if (file.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image size exceeds 10MB limit'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Show loading
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
                  Text('Uploading image...'),
                ],
              ),
            ),
          ),
        );

        // Upload image
        final downloadUrl = await _uploadFileToStorage(file, 'images');
        Navigator.pop(context); // Close loading dialog

        if (downloadUrl != null) {
          // Send message with image
          await _sendMessage(
            text: '📷 Photo from gallery',
            attachmentType: 'image',
            attachmentUrl: downloadUrl,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      print('Error picking image from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendFileMessage(String type, String fileName, [String? fileUrl]) {
    String displayText;
    switch (type) {
      case 'image':
        displayText = '📷 Photo';
        break;
      case 'video':
        displayText = '🎥 Video';
        break;
      case 'audio':
        displayText = '🎵 Audio';
        break;
      default:
        displayText = '📎 $fileName';
    }

    _sendMessage(
      text: displayText,
      attachmentType: type,
      // Remove fileUrl to avoid network errors
    );
  }

  // Real file picker for documents
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'xls', 'xlsx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size exceeds 10MB limit'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Show loading
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
                  Text('Uploading ${file.name}...'),
                ],
              ),
            ),
          ),
        );

        // Upload file
        final downloadUrl = await _uploadFileToStorage(file, 'documents');
        Navigator.pop(context); // Close loading dialog

        if (downloadUrl != null) {
          // Send message with file
          await _sendMessage(
            text: file.name,
            attachmentType: 'file',
            attachmentUrl: downloadUrl,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      print('Error picking document: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name.toLowerCase();

        // Determine if it's image or video
        bool isImage = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') ||
            fileName.endsWith('.png') || fileName.endsWith('.gif') ||
            fileName.endsWith('.bmp') || fileName.endsWith('.webp');
        bool isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mov') ||
            fileName.endsWith('.avi') || fileName.endsWith('.mkv') ||
            fileName.endsWith('.3gp') || fileName.endsWith('.webm');

        if (!isImage && !isVideo) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select an image or video file'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Check file size
        int maxSize = isVideo ? 50 * 1024 * 1024 : 10 * 1024 * 1024; // 50MB for video, 10MB for image
        if (file.size > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isVideo ? "Video" : "Image"} size exceeds ${isVideo ? "50MB" : "10MB"} limit'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Show loading
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
                  Text('Uploading ${isVideo ? "video" : "image"}...'),
                  if (isVideo) ...[
                    SizedBox(height: 8),
                    Text(
                      'Videos longer than 1 minute may not play properly',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        // Upload file
        final downloadUrl = await _uploadFileToStorage(file, isVideo ? 'videos' : 'images');
        Navigator.pop(context); // Close loading dialog

        if (downloadUrl != null) {
          if (isVideo) {
            // Send message with video
            await _sendMessage(
              text: '🎥 Video from gallery',
              attachmentType: 'video',
              attachmentUrl: downloadUrl,
              videoDuration: 0, // Duration unknown from gallery picker
            );
          } else {
            // Send message with image
            await _sendMessage(
              text: '📷 Photo from gallery',
              attachmentType: 'image',
              attachmentUrl: downloadUrl,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${isVideo ? "Video" : "Image"} sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      print('Error picking media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting media: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickGalleryVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (max 50MB for videos)
        if (file.size > 50 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video size exceeds 50MB limit'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Check video duration (max 1 minute = 60 seconds)
        // Note: FilePicker doesn't provide duration info, so we'll upload and let user know if it's too long

        // Show loading
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
                  Text('Processing video...'),
                  SizedBox(height: 8),
                  Text(
                    'Videos longer than 1 minute will be rejected',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        // Upload video
        final downloadUrl = await _uploadFileToStorage(file, 'videos');
        Navigator.pop(context); // Close loading dialog

        if (downloadUrl != null) {
          // Send message with video
          await _sendMessage(
            text: '🎥 Video from gallery',
            attachmentType: 'video',
            attachmentUrl: downloadUrl,
            videoDuration: 0, // Duration unknown from picker
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if open
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Upload file to Firebase Storage
  Future<String?> _uploadFileToStorage(PlatformFile file, String folder) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to upload files');
      }

      // Create unique file name
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      String storagePath = 'chat_files/$folder/${widget.chatId}/$fileName';

      // Create file reference
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(file.extension ?? ''),
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'originalName': file.name,
          'chatId': widget.chatId,
          'type': 'chat_attachment',
        },
      );

      // Upload file
      final uploadTask = ref.putData(file.bytes!, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload file: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Get content type for file
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}

// ✅ PROPERLY PLACED OUTSIDE ALL OTHER CLASSES
class FullImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? caption;
  final String senderName;
  final DateTime timestamp;
  final List<TextOverlay>? textOverlays;

  const FullImageViewer({
    Key? key,
    this.imageUrl,
    this.caption,
    required this.senderName,
    required this.timestamp,
    this.textOverlays,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          senderName,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show options like save, share, etc.
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.6,
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  // Display actual image if URL exists
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[400],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 100,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Failed to load image",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                  // Fallback placeholder when no URL
                    Container(
                      color: Colors.grey[400],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 100,
                              color: Colors.grey[600],
                            ),
                            SizedBox(height: 10),
                            Text(
                              "No image available",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Text overlays
                  if (textOverlays != null)
                    ...textOverlays!.map((overlay) {
                      return Positioned(
                        left: overlay.position.dx,
                        top: overlay.position.dy,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            overlay.text,
                            style: TextStyle(
                              fontSize: overlay.fontSize,
                              color: overlay.color,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            SizedBox(height: 20),
            if (caption != null && caption!.isNotEmpty)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  caption!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 20),
            Text(
              "${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}