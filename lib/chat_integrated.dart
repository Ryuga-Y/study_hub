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

  ChatContact({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.chatId,
  });

  factory ChatContact.fromFriend(Friend friend, {String? lastMessage, DateTime? lastMessageTime, int unreadCount = 0}) {
    return ChatContact(
      userId: friend.friendId,
      name: friend.friendName,
      avatarUrl: friend.friendAvatar,
      lastMessage: lastMessage ?? "You became friends with ${friend.friendName}, let's start chatting!",
      lastMessageTime: lastMessageTime ?? friend.acceptedAt ?? friend.createdAt,
      unreadCount: unreadCount,
      isOnline: false,
      chatId: _generateChatId(FirebaseAuth.instance.currentUser!.uid, friend.friendId),
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
      timestamp: (data['timestamp'] as Timestamp).toDate(),
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

// Text Overlay Model
class TextOverlay {
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;

  TextOverlay({
    required this.text,
    required this.position,
    this.fontSize = 24,
    this.color = Colors.white,
  });

  TextOverlay copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'positionX': position.dx,
      'positionY': position.dy,
      'fontSize': fontSize,
      'colorValue': color.value,
    };
  }

  factory TextOverlay.fromMap(Map<String, dynamic> map) {
    return TextOverlay(
      text: map['text'],
      position: Offset(map['positionX'], map['positionY']),
      fontSize: map['fontSize'],
      color: Color(map['colorValue']),
    );
  }
}

// Main Chat Contact Page
class ChatContactPage extends StatefulWidget {
  @override
  _ChatContactPageState createState() => _ChatContactPageState();
}

// FIXED: Only one class declaration
class _ChatContactPageState extends State<ChatContactPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ChatContact> _contacts = [];
  bool _isLoading = true;
  bool _hasFriends = false;

  @override
  void initState() {
    super.initState();
    _loadFriendsAsContacts();
  }

  Future<void> _loadFriendsAsContacts() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Get accepted friends
      final friendsSnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Set hasFriends flag
      _hasFriends = friendsSnapshot.docs.isNotEmpty;

      List<ChatContact> contacts = [];

      for (final doc in friendsSnapshot.docs) {
        final friend = Friend.fromFirestore(doc);
        final chatId = ChatContact._generateChatId(currentUserId, friend.friendId);

        // Check if chat exists
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();

        if (!chatDoc.exists) {
          // Create new chat
          await _createChat(currentUserId, friend);
        }

        // Get last message info
        final chatData = chatDoc.data();
        final lastMessage = chatData?['lastMessage'] ?? "You became friends with ${friend.friendName}, let's start chatting!";
        final lastMessageTime = chatData?['lastMessageTime'] != null
            ? (chatData!['lastMessageTime'] as Timestamp).toDate()
            : friend.acceptedAt ?? friend.createdAt;
        final unreadCount = chatData?['unreadCount']?[currentUserId] ?? 0;

        contacts.add(ChatContact.fromFriend(
          friend,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          unreadCount: unreadCount,
        ));
      }

      // Sort by last message time
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

  Future<void> _createChat(String currentUserId, Friend friend) async {
    final chatId = ChatContact._generateChatId(currentUserId, friend.friendId);

    // Get current user's name
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final currentUserName = currentUserDoc.data()?['fullName'] ?? 'You';

    // Welcome message
    final welcomeMessage = "You became friends with ${friend.friendName}, let's start chatting!";

    // Create chat document
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
        currentUserId: 0,  // Current user has seen it
        friend.friendId: 0, // Friend has also seen it (since it's a system message)
      },
    });

    // Add welcome message
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'text': welcomeMessage,
      'senderId': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': true,  // Mark as read for system messages
      'isSystemMessage': true,
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
      title: Text(
        'Messages',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: Colors.black),
          onPressed: () {
            // Search functionality
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {
            // More options
          },
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
          if (!_hasFriends) ...[  // Only show if no friends
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Get the current user's organization code
                  final userDoc = await _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .get();

                  final organizationCode = userDoc.data()?['organizationCode'] ?? '';

                  // Navigate to feed screen and then to search tab
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedScreen(
                        organizationCode: organizationCode,
                        initialTab: 1, // Set to search tab index
                      ),
                    ),
                        (route) => false, // Remove all previous routes
                  );
                } catch (e) {
                  print('Error navigating to find friends: $e');
                  // Fallback navigation
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
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return _buildContactTile(contact);
      },
    );
  }

  Widget _buildContactTile(ChatContact contact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          ).then((_) => _loadFriendsAsContacts()); // Refresh on return
        },
        child: Row(
          children: [
            _buildContactAvatar(contact),
            SizedBox(width: 12),
            _buildContactInfo(contact),
            _buildContactMeta(contact),
          ],
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
}

// Rest of the ChatScreen and other classes remain the same...

// Chat Screen
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

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Mark all messages as read
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in messagesSnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count
    batch.update(
      _firestore.collection('chats').doc(widget.chatId),
      {'unreadCount.${currentUserId}': 0},
    );

    await batch.commit();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () {
            // Video call functionality
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
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

        final messages = snapshot.data!.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList();

        if (messages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Say hi!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        // Auto scroll to bottom
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
    );
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
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: Colors.grey[600]),
              onPressed: () {
                // File picker
              },
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
              onPressed: () {
                // Camera
              },
            ),
            Expanded(child: _buildTextInputField()),
            SizedBox(width: 8),
            _buildSendButton(),
          ],
        ),
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

  Future<void> _sendMessage({required String text}) async {
    if (text.trim().isEmpty) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': text.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat metadata
      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.contactId}': FieldValue.increment(1),
      });

      _messageController.clear();
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
}