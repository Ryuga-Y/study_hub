import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
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
      appBar: AppBar(
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
      ),
      body: ListView.builder(
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
                  Stack(
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
                  ),
                  SizedBox(width: 12),
                  Expanded(
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
                  ),
                  Column(
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
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
  TextEditingController _searchController = TextEditingController();
  List<ChatMessage> _filteredMessages = [];

  @override
  void initState() {
    super.initState();
    _filteredMessages = messages;
  }

  void _sendMessage({String? text, String? attachmentType}) {
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        messages.add(ChatMessage(
          text: text,
          isMe: true,
          timestamp: DateTime.now(),
          attachmentType: attachmentType,
        ));
        _filteredMessages = messages;
      });
      _messageController.clear();
      _scrollToBottom();
    } else if (attachmentType != null) {
      setState(() {
        messages.add(ChatMessage(
          text: attachmentType == 'image' ? "📷 Image sent" : "📎 File sent",
          isMe: true,
          timestamp: DateTime.now(),
          attachmentType: attachmentType,
        ));
        _filteredMessages = messages;
      });
      _scrollToBottom();
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

  void _pickImage() {
    // Simulate image picker
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image"),
          content: Text("Choose an image from gallery"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Gallery"),
              onPressed: () {
                Navigator.of(context).pop();
                _sendMessage(attachmentType: 'image');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Image selected and sent!")),
                );
              },
            ),
            TextButton(
              child: Text("Camera"),
              onPressed: () {
                Navigator.of(context).pop();
                _sendMessage(attachmentType: 'image');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Photo taken and sent!")),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _pickFile() {
    // Simulate file picker
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select File"),
          content: Text("Choose a file to send"),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text("Documents"),
              onPressed: () {
                Navigator.of(context).pop();
                _sendMessage(attachmentType: 'file');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Document selected and sent!")),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showEmojiPanel() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
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
              child: Text(
                widget.contactName[0],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    widget.isOnline ? "Active now" : widget.lastSeen,
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
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
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
                ),
                onChanged: _searchMessages,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _filteredMessages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_filteredMessages[index]);
              },
            ),
          ),
          if (_showEmojiPicker) _buildEmojiPicker(),
          _buildMessageInput(),
        ],
      ),
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
            if (message.attachmentType == 'image')
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[300],
                ),
                child: Icon(
                  Icons.image,
                  size: 50,
                  color: Colors.grey[600],
                ),
              ),
            if (message.attachmentType == 'file')
              Row(
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
            if (message.text.isNotEmpty)
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

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
            onPressed: _pickImage,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Write your message",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.emoji_emotions, color: Colors.grey[600]),
                    onPressed: _showEmojiPanel,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
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
          ),
        ],
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
      "👈", "👉", "👆", "🖕", "👇", "☝️", "👋", "🤚"
    ];

    return Container(
      height: 250,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            child: Text(
              "Tap an emoji to add it",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
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
                    setState(() {
                      _showEmojiPicker = false;
                    });
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
                        style: TextStyle(fontSize: 24),
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
                // Video call interface
                Center(
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
                ),
                // Control buttons
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
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
                      // End call button
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
                      // Camera toggle button
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String? attachmentType;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.attachmentType,
  });
}