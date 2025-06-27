import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  runApp(MyApp());
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

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? attachmentType;
  final List<TextOverlay>? textOverlays;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.attachmentType,
    this.textOverlays,
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChatContactPage(),
    );
  }
}

class ChatContactPage extends StatefulWidget {
  @override
  _ChatContactPageState createState() => _ChatContactPageState();
}

class _ChatContactPageState extends State<ChatContactPage> {
  List<Map<String, dynamic>> contacts = [
    {
      "name": "James",
      "message": "Hello, I'm fine, how can I help you?",
      "unread": 2,
      "avatar": "assets/james.jpg",
      "isOnline": true,
      "lastSeen": "Active now"
    },
    {
      "name": "Anna",
      "message": "Let's meet tomorrow to discuss the plan.",
      "unread": 1,
      "avatar": "assets/anna.jpg",
      "isOnline": false,
      "lastSeen": "2 hours ago"
    },
    {
      "name": "John",
      "message": "Can you send me the report by today?",
      "unread": 0,
      "avatar": "assets/john.jpg",
      "isOnline": true,
      "lastSeen": "Active now"
    },
    {
      "name": "Emily",
      "message": "Please review the document I sent.",
      "unread": 3,
      "avatar": "assets/emily.jpg",
      "isOnline": false,
      "lastSeen": "1 day ago"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildContactsList(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Text(
        'Chat',
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

  Widget _buildContactsList() {
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    contactName: contacts[index]['name'],
                    isOnline: contacts[index]['isOnline'],
                    lastSeen: contacts[index]['lastSeen'],
                  ),
                ),
              );
            },
            child: Row(
              children: [
                _buildContactAvatar(index),
                SizedBox(width: 12),
                _buildContactInfo(index),
                _buildContactMeta(index),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactAvatar(int index) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[300],
          child: Text(
            contacts[index]['name'][0],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        if (contacts[index]['isOnline'])
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

  Widget _buildContactInfo(int index) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contacts[index]['name'],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            contacts[index]['message'],
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

  Widget _buildContactMeta(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "12:30 PM",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        SizedBox(height: 4),
        if (contacts[index]['unread'] > 0)
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Text(
              contacts[index]['unread'].toString(),
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

class ChatScreen extends StatefulWidget {
  final String contactName;
  final bool isOnline;
  final String lastSeen;

  ChatScreen({
    required this.contactName,
    required this.isOnline,
    required this.lastSeen,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  List<ChatMessage> messages = [
    ChatMessage(
      text: "Hello, I'm fine, how can I help you?",
      isMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
    ChatMessage(
      text: "What is the best programming language?",
      isMe: true,
      timestamp: DateTime.now().subtract(Duration(minutes: 3)),
    ),
    ChatMessage(
      text: "There are many programming languages in the market that are used in designing and building websites.",
      isMe: false,
      timestamp: DateTime.now().subtract(Duration(minutes: 2)),
    ),
    ChatMessage(
      text: "So explain to me more",
      isMe: true,
      timestamp: DateTime.now().subtract(Duration(minutes: 1)),
    ),
  ];

  bool _showEmojiPicker = false;
  bool _isSearching = false;
  List<ChatMessage> _filteredMessages = [];

  @override
  void initState() {
    super.initState();
    _filteredMessages = messages;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
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
          _buildContactAvatarInChat(),
          SizedBox(width: 12),
          _buildContactInfoInChat(),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _filteredMessages = messages;
              }
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.videocam, color: Colors.blue),
          onPressed: () {
            _showVideoCallDialog();
          },
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildContactAvatarInChat() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[300],
          child: Text(
            widget.contactName[0],
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (widget.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactInfoInChat() {
    return Expanded(
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
            widget.isOnline ? "Active now" : widget.lastSeen,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search messages...",
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _searchMessages,
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _filteredMessages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(_filteredMessages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue : Colors.white,
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
            if (message.attachmentType == 'image') _buildImageMessage(message),
            if (message.attachmentType == 'file') _buildFileMessage(message),
            if (message.text.isNotEmpty &&
                message.text != "📷 Photo" &&
                message.attachmentType != 'image')
              Text(
                message.text,
                style: TextStyle(
                  color: message.isMe ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
            SizedBox(height: 4),
            Text(
              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: message.isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(ChatMessage message) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _viewImage(message),
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
                Center(
                  child: Icon(
                    Icons.image,
                    size: 50,
                    color: Colors.grey[600],
                  ),
                ),
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
        if (message.text.isNotEmpty && message.text != "📷 Photo")
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: message.isMe
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileMessage(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 16,
            color: message.isMe ? Colors.white : Colors.black,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              "document.pdf",
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black,
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
              onPressed: _simulateFilePicker,
            ),
            IconButton(
              icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
              onPressed: _showImagePickerOptions,
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
              onTap: () {
                setState(() {
                  _showEmojiPicker = false;
                });
                Future.delayed(Duration(milliseconds: 300), () {
                  _scrollToBottom();
                });
              },
            ),
          ),
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
              color: Colors.grey[600],
            ),
            onPressed: _showEmojiPanel,
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
          _buildEmojiHeader(),
          Expanded(child: _buildEmojiGrid(emojis)),
        ],
      ),
    );
  }

  Widget _buildEmojiHeader() {
    return Container(
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
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
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
    );
  }

  void _sendMessage({String? text, String? attachmentType, List<TextOverlay>? textOverlays}) {
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        messages.add(ChatMessage(
          text: text,
          isMe: true,
          timestamp: DateTime.now(),
          attachmentType: attachmentType,
          textOverlays: textOverlays,
        ));
        _filteredMessages = messages;
      });
      _messageController.clear();
      _scrollToBottom();
      HapticFeedback.lightImpact();
    } else if (attachmentType != null) {
      setState(() {
        messages.add(ChatMessage(
          text: attachmentType == 'image' ? "📷 Photo" : "📎 File sent",
          isMe: true,
          timestamp: DateTime.now(),
          attachmentType: attachmentType,
          textOverlays: textOverlays,
        ));
        _filteredMessages = messages;
      });
      _scrollToBottom();
      HapticFeedback.lightImpact();
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

  void _searchMessages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMessages = messages;
      } else {
        _filteredMessages = messages
            .where((message) =>
            message.text.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _viewImage(ChatMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewScreen(
          message: message,
          contactName: widget.contactName,
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    _focusNode.unfocus();
    setState(() {
      _showEmojiPicker = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.all(20),
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
                Text(
                  'Select Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPhotoOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _simulateImagePicker('gallery');
                      },
                    ),
                    _buildPhotoOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraScreen(
                              onImageCaptured: (caption, textOverlays) {
                                if (caption.isNotEmpty) {
                                  _sendMessage(text: caption, attachmentType: 'image', textOverlays: textOverlays);
                                } else {
                                  _sendMessage(attachmentType: 'image', textOverlays: textOverlays);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Photo sent!')),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                color: Colors.blue,
                size: 30,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateImagePicker(String source) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
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
                Text(
                  'Loading from gallery...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context);
      _sendMessage(attachmentType: 'image');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image selected from gallery!'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _simulateFilePicker() {
    _focusNode.unfocus();
    setState(() {
      _showEmojiPicker = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue),
              SizedBox(width: 8),
              Text("Select File"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Choose a file type to simulate:"),
              SizedBox(height: 16),
              ...[
                {'icon': Icons.description, 'label': 'Document (PDF)', 'type': 'document'},
                {'icon': Icons.image, 'label': 'Image File', 'type': 'image'},
                {'icon': Icons.audiotrack, 'label': 'Audio File', 'type': 'audio'},
                {'icon': Icons.videocam, 'label': 'Video File', 'type': 'video'},
              ].map((item) => ListTile(
                leading: Icon(item['icon'] as IconData, color: Colors.blue),
                title: Text(item['label'] as String),
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(attachmentType: 'file');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${item['label']} selected and sent!")),
                  );
                },
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showEmojiPanel() {
    _focusNode.unfocus();
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _showVideoCallDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.videocam, color: Colors.blue),
              SizedBox(width: 8),
              Text("Video Call"),
            ],
          ),
          content: Text("Start a video call with ${widget.contactName}?"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text("Call"),
              onPressed: () {
                Navigator.of(context).pop();
                _showVideoCallScreen();
              },
            ),
          ],
        );
      },
    );
  }

  void _showVideoCallScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                _buildVideoCallContent(),
                _buildVideoCallControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoCallContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            child: Text(
              widget.contactName[0],
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            widget.contactName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Calling...",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCallControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.mic_off, color: Colors.white, size: 30),
              onPressed: () {},
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.call_end, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Call ended")),
                );
              },
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.videocam_off, color: Colors.white, size: 30),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class ImageViewScreen extends StatelessWidget {
  final ChatMessage message;
  final String contactName;

  ImageViewScreen({
    required this.message,
    required this.contactName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildImageViewAppBar(context),
      body: _buildImageViewContent(context),
    );
  }

  AppBar _buildImageViewAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        message.isMe ? "You" : contactName,
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
    );
  }

  Widget _buildImageViewContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildImageContainer(context),
          SizedBox(height: 20),
          if (message.text.isNotEmpty && message.text != "📷 Photo")
            _buildCaption(),
          SizedBox(height: 20),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildImageContainer(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.6,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Center(
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
                  "Photo",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (message.textOverlays != null)
            ...message.textOverlays!.map((overlay) {
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
    );
  }

  Widget _buildCaption() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimestamp() {
    return Text(
      "${message.timestamp.day}/${message.timestamp.month}/${message.timestamp.year} at ${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 14,
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final Function(String, List<TextOverlay>?) onImageCaptured;

  CameraScreen({required this.onImageCaptured});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildTopControls(),
          _buildBottomControls(),
          _buildFocusFrame(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 100,
              color: Colors.white54,
            ),
            SizedBox(height: 20),
            Text(
              _isFrontCamera ? "Front Camera" : "Back Camera",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              IconButton(
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                  });
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildGalleryButton(),
              _buildCaptureButton(),
              _buildCameraSwitchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Icon(
        Icons.photo_library,
        color: Colors.white,
        size: 25,
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: () {
        _capturePhoto();
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          margin: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isFrontCamera = !_isFrontCamera;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Icon(
          Icons.flip_camera_ios,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }

  Widget _buildFocusFrame() {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        child: Stack(
          children: [
            _buildCorner(0, 0, true, true),
            _buildCorner(0, null, true, false),
            _buildCorner(null, 0, false, true),
            _buildCorner(null, null, false, false),
            Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(double? top, double? bottom, bool left, bool isTop) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            left: left ? BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            right: !left ? BorderSide(color: Colors.white, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _capturePhoto() {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      builder: (context) => Container(),
    );

    Future.delayed(Duration(milliseconds: 100), () {
      Navigator.pop(context);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoEditScreen(
            imagePath: "captured_image_path",
            onImageSent: (caption, textOverlays) {
              widget.onImageCaptured(caption, textOverlays);
            },
          ),
        ),
      );
    });
  }
}

class PhotoEditScreen extends StatefulWidget {
  final String imagePath;
  final Function(String, List<TextOverlay>?) onImageSent;

  PhotoEditScreen({
    required this.imagePath,
    required this.onImageSent,
  });

  @override
  _PhotoEditScreenState createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textOverlayController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _overlayFocusNode = FocusNode();

  List<TextOverlay> _textOverlays = [];
  bool _isAddingText = false;
  bool _showTextInput = false;
  int? _selectedTextIndex;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() {
      setState(() {
        // This will trigger a rebuild to update the helper text
      });
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _textOverlayController.dispose();
    _focusNode.dispose();
    _overlayFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          _focusNode.unfocus();
          _overlayFocusNode.unfocus();
          setState(() {
            _selectedTextIndex = null;
          });
        },
        child: Stack(
          children: [
            _buildImageArea(context),
            _buildCloseButton(),
            _buildAddTextButton(),
            if (_showTextInput) _buildTextInputOverlay(),
            _buildBottomCaptionArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
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
                    "Captured Photo",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.2),
          ),
          ..._buildTextOverlays(),
        ],
      ),
    );
  }

  List<Widget> _buildTextOverlays() {
    return _textOverlays.asMap().entries.map((entry) {
      int index = entry.key;
      TextOverlay overlay = entry.value;
      bool isSelected = _selectedTextIndex == index;

      return Positioned(
        left: overlay.position.dx,
        top: overlay.position.dy,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedTextIndex = isSelected ? null : index;
            });
          },
          onPanUpdate: (details) {
            _updateTextPosition(index, overlay.position + details.delta);
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black.withOpacity(0.6) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (isSelected) ...[
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _deleteTextOverlay(index),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: SafeArea(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTextButton() {
    return Positioned(
      top: 50,
      right: 20,
      child: SafeArea(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showTextInput = !_showTextInput;
              _isAddingText = !_isAddingText;
            });
            if (_showTextInput) {
              Future.delayed(Duration(milliseconds: 100), () {
                _overlayFocusNode.requestFocus();
              });
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isAddingText ? Colors.blue : Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.text_fields,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputOverlay() {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              TextField(
                controller: _textOverlayController,
                focusNode: _overlayFocusNode,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: "Enter text to add on image...",
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                onSubmitted: (text) {
                  _addTextOverlay();
                },
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showTextInput = false;
                          _isAddingText = false;
                          _textOverlayController.clear();
                        });
                        _overlayFocusNode.unfocus();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addTextOverlay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Add Text",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCaptionArea() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _captionController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "Add a caption (optional)...",
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    _sendPhoto();
                  },
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _sendPhoto,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendPhoto() {
    String caption = _captionController.text.trim();
    Navigator.of(context).pop();
    Future.delayed(Duration(milliseconds: 100), () {
      widget.onImageSent(caption, _textOverlays.isNotEmpty ? _textOverlays : null);
    });
  }

  void _addTextOverlay() {
    if (_textOverlayController.text.trim().isNotEmpty) {
      setState(() {
        _textOverlays.add(
          TextOverlay(
            text: _textOverlayController.text.trim(),
            position: Offset(100, 200),
            fontSize: 24,
            color: Colors.white,
          ),
        );
        _textOverlayController.clear();
        _showTextInput = false;
        _isAddingText = false;
      });
      _overlayFocusNode.unfocus();
    }
  }

  void _deleteTextOverlay(int index) {
    setState(() {
      _textOverlays.removeAt(index);
      _selectedTextIndex = null;
    });
  }

  void _updateTextPosition(int index, Offset newPosition) {
    setState(() {
      _textOverlays[index] = _textOverlays[index].copyWith(position: newPosition);
    });
  }
}