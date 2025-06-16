import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatManagementPage extends StatefulWidget {
  final String organizationId;

  const ChatManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _ChatManagementPageState createState() => _ChatManagementPageState();
}

class _ChatManagementPageState extends State<ChatManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chat Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Monitor and manage chat rooms and conversations',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateChatRoomDialog(),
                      icon: Icon(Icons.add),
                      label: Text('Create Chat Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search chat rooms...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Filter dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: InputDecoration(
                          labelText: 'Filter',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Chats')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'archived', child: Text('Archived')),
                          DropdownMenuItem(value: 'reported', child: Text('Reported')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statistics
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Chat Rooms',
                  '24',
                  Icons.chat_bubble,
                  Colors.blue,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  'Active Users',
                  '156',
                  Icons.people,
                  Colors.green,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  'Messages Today',
                  '1,234',
                  Icons.message,
                  Colors.orange,
                ),
                SizedBox(width: 16),
                _buildStatCard(
                  'Reported Issues',
                  '3',
                  Icons.flag,
                  Colors.red,
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.redAccent,
              unselectedLabelColor: Colors.grey[700],
              indicatorColor: Colors.redAccent,
              tabs: [
                Tab(text: 'Chat Rooms'),
                Tab(text: 'Recent Activity'),
                Tab(text: 'Reported Content'),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatRoomsList(),
                _buildRecentActivity(),
                _buildReportedContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatRoomsList() {
    // Mock data for chat rooms
    final chatRooms = [
      {
        'id': '1',
        'name': 'Computer Science General',
        'type': 'faculty',
        'members': 245,
        'lastActivity': DateTime.now().subtract(Duration(minutes: 5)),
        'isActive': true,
      },
      {
        'id': '2',
        'name': 'Study Group - Data Structures',
        'type': 'study_group',
        'members': 32,
        'lastActivity': DateTime.now().subtract(Duration(hours: 1)),
        'isActive': true,
      },
      {
        'id': '3',
        'name': 'Engineering Faculty Chat',
        'type': 'faculty',
        'members': 189,
        'lastActivity': DateTime.now().subtract(Duration(hours: 3)),
        'isActive': true,
      },
      {
        'id': '4',
        'name': 'Project Discussion - AI',
        'type': 'project',
        'members': 15,
        'lastActivity': DateTime.now().subtract(Duration(days: 1)),
        'isActive': false,
      },
    ];

    final filteredRooms = chatRooms.where((room) {
      if (_searchQuery.isNotEmpty) {
        final name = room['name'].toString().toLowerCase();
        if (!name.contains(_searchQuery)) return false;
      }

      if (_selectedFilter == 'active' && !(room['isActive'] as bool)) return false;
      if (_selectedFilter == 'archived' && (room['isActive'] as bool)) return false;

      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.3,
        ),
        itemCount: filteredRooms.length,
        itemBuilder: (context, index) {
          final room = filteredRooms[index];
          return _buildChatRoomCard(room);
        },
      ),
    );
  }

  Widget _buildChatRoomCard(Map<String, dynamic> room) {
    final isActive = room['isActive'] as bool;
    final type = room['type'] as String;
    final lastActivity = room['lastActivity'] as DateTime;

    IconData typeIcon;
    Color typeColor;
    switch (type) {
      case 'faculty':
        typeIcon = Icons.school;
        typeColor = Colors.blue;
        break;
      case 'study_group':
        typeIcon = Icons.groups;
        typeColor = Colors.green;
        break;
      case 'project':
        typeIcon = Icons.work;
        typeColor = Colors.orange;
        break;
      default:
        typeIcon = Icons.chat;
        typeColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? typeColor.withOpacity(0.1) : Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(typeIcon, color: isActive ? typeColor : Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    room['name'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isActive)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Archived',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '${room['members']} members',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Last activity: ${_formatLastActivity(lastActivity)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _viewChatRoom(room),
                        child: Text('View'),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, size: 20),
                        onPressed: () => _editChatRoom(room),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        _buildActivityItem(
          icon: Icons.message,
          title: 'New message in "Computer Science General"',
          subtitle: 'John Doe: "Can anyone help with the assignment?"',
          time: '5 minutes ago',
          color: Colors.blue,
        ),
        _buildActivityItem(
          icon: Icons.person_add,
          title: '5 new members joined "Study Group - Data Structures"',
          subtitle: 'Total members: 32',
          time: '1 hour ago',
          color: Colors.green,
        ),
        _buildActivityItem(
          icon: Icons.flag,
          title: 'Content reported in "Engineering Faculty Chat"',
          subtitle: 'Inappropriate language detected',
          time: '2 hours ago',
          color: Colors.red,
        ),
        _buildActivityItem(
          icon: Icons.archive,
          title: 'Chat room archived',
          subtitle: '"Project Discussion - AI" archived due to inactivity',
          time: '1 day ago',
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportedContent() {
    return ListView(
      padding: EdgeInsets.all(24),
      children: [
        _buildReportCard(
          reportedBy: 'Jane Smith',
          chatRoom: 'Engineering Faculty Chat',
          reason: 'Inappropriate language',
          message: 'This is an example of reported content...',
          time: '2 hours ago',
          status: 'pending',
        ),
        _buildReportCard(
          reportedBy: 'Mike Johnson',
          chatRoom: 'Study Group - Physics',
          reason: 'Spam',
          message: 'Buy cheap electronics at...',
          time: '5 hours ago',
          status: 'resolved',
        ),
        _buildReportCard(
          reportedBy: 'Sarah Lee',
          chatRoom: 'Computer Science General',
          reason: 'Harassment',
          message: 'Offensive comment towards...',
          time: '1 day ago',
          status: 'investigating',
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String reportedBy,
    required String chatRoom,
    required String reason,
    required String message,
    required String time,
    required String status,
  }) {
    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending Review';
        break;
      case 'investigating':
        statusColor = Colors.blue;
        statusText = 'Investigating';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusText = 'Resolved';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.flag, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Reported by $reportedBy • $time',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      chatRoom,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending') ...[
                      TextButton(
                        onPressed: () {},
                        child: Text('Dismiss'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('Take Action'),
                      ),
                    ] else if (status == 'investigating') ...[
                      ElevatedButton(
                        onPressed: () {},
                        child: Text('View Details'),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () {},
                        child: Text('View Resolution'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastActivity(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  void _showCreateChatRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Chat Room'),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Chat Room Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'faculty', child: Text('Faculty Chat')),
                  DropdownMenuItem(value: 'study_group', child: Text('Study Group')),
                  DropdownMenuItem(value: 'project', child: Text('Project Discussion')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (value) {},
              ),
              SizedBox(height: 16),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat room created successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  void _viewChatRoom(Map<String, dynamic> room) {
    // Navigate to chat room details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing chat room: ${room['name']}'),
      ),
    );
  }

  void _editChatRoom(Map<String, dynamic> room) {
    // Show edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing chat room: ${room['name']}'),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}