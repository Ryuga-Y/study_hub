import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../Authentication/auth_services.dart';

class UserManagementPage extends StatefulWidget {
  final String organizationId;

  const UserManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _authService = AuthService();
  String _searchQuery = '';
  bool _showInactiveUsers = false;
  bool _isOrganizationCreator = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        setState(() {
          _currentUserId = user.uid;
          _isOrganizationCreator = userData['isOrganizationCreator'] ?? false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _showInactiveUsers = !_showInactiveUsers),
                          icon: Icon(
                            _showInactiveUsers ? Icons.visibility : Icons.visibility_off,
                            size: 16,
                          ),
                          label: Text(
                            _showInactiveUsers ? 'Inactive' : 'Active Only',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Search bar
                Container(
                  width: MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name or email...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey[600],
              tabs: [
                Tab(text: 'All Users'),
                Tab(text: 'Students'),
                Tab(text: 'Lecturers'),
                Tab(text: 'Admins'),
              ],
              onTap: (index) {
                // Tab switching is handled by TabController
              },
            ),
          ),

          // User List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList('all'),
                _buildUserList('student'),
                _buildUserList('lecturer'),
                _buildAdminList(), // Special handling for admins
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminList() {
    return Column(
      children: [
        // Pending Admins Quick Actions Section (only for organization creators)
        if (_isOrganizationCreator) ...[
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('organizationCode', isEqualTo: widget.organizationId)
                .where('role', isEqualTo: 'admin')
                .where('requiresActivation', isEqualTo: true)
                .where('isActive', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SizedBox.shrink();
              }

              final pendingAdmins = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'uid': doc.id,
                  'email': data['email'],
                  'fullName': data['fullName'],
                  'createdAt': data['createdAt'],
                };
              }).toList();

              return Container(
                color: Colors.orange[50],
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Quick Actions - Pending Admin Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingAdmins.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: pendingAdmins.map((admin) => Container(
                          width: 300,
                          margin: EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange[100],
                                  child: Icon(Icons.person, color: Colors.orange[700]),
                                  radius: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        admin['fullName'],
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        admin['email'],
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _activateAdmin(admin['uid']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Text('Activate', style: TextStyle(fontSize: 12, color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // All Admins List (including pending ones)
        Expanded(
          child: _buildUserList('admin', showPendingAdmins: true),
        ),
      ],
    );
  }

  Widget _buildUserList(String role, {bool showPendingAdmins = false}) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('organizationCode', isEqualTo: widget.organizationId);

    if (role != 'all') {
      query = query.where('role', isEqualTo: role);
    }

    // For admin list, we want to show all admins regardless of status when showPendingAdmins is true
    // For other roles, respect the active filter
    if (!_showInactiveUsers && !showPendingAdmins) {
      query = query.where('isActive', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(role);
        }

        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['fullName']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';

          // Apply search filter
          bool matchesSearch = name.contains(_searchQuery) || email.contains(_searchQuery);

          // For non-admin roles or when not showing pending admins,
          // filter out inactive users unless specifically showing inactive
          if (!showPendingAdmins && !_showInactiveUsers) {
            return matchesSearch && (data['isActive'] ?? true);
          }

          return matchesSearch;
        }).toList();

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No users match your search',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;
            return _buildUserCard(user.id, data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String role) {
    final roleText = role == 'all' ? 'users' : '${role}s';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No $roleText found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _showInactiveUsers ? 'No $roleText in your organization' : 'No active $roleText',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showInviteDialog(context),
            icon: Icon(Icons.person_add, color: Colors.white),
            label: Text('Invite User', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;
    final role = data['role'] ?? 'unknown';
    final isCurrentUser = userId == _currentUserId;
    final isCreator = data['isOrganizationCreator'] ?? false;
    // Check both requiresActivation and isActive to determine pending status
    final isPendingActivation = (data['requiresActivation'] ?? false) && !isActive;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPendingActivation
              ? Colors.orange[300]!
              : isCreator
              ? Colors.blue[200]!
              : Colors.grey[200]!,
          width: isPendingActivation || isCreator ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPendingActivation
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // User Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isPendingActivation
                      ? Colors.orange
                      : isCreator
                      ? Colors.blue
                      : _getRoleColor(role),
                  child: isPendingActivation
                      ? Icon(Icons.hourglass_empty, color: Colors.white, size: 28)
                      : isCreator
                      ? Icon(Icons.star, color: Colors.white, size: 28)
                      : Text(
                    data['fullName']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            data['fullName'] ?? 'Unknown User',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (isCreator)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Organization Creator',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (isPendingActivation)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_empty, size: 12, color: Colors.orange[700]),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pending Activation',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getRoleColor(role).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.substring(0, 1).toUpperCase() + role.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                color: _getRoleColor(role),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isPendingActivation)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle : Icons.cancel,
                                    size: 12,
                                    color: isActive ? Colors.green[700] : Colors.red[700],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isActive ? Colors.green[700] : Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (data['emailVerified'] == false)
                            Tooltip(
                              message: 'Email not verified',
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        data['email'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (role == 'student' || role == 'lecturer') ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.school, size: 14, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${data['facultyName'] ?? 'Unknown Faculty'}${role == 'student' && data['programName'] != null ? ' • ${data['programName']}' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                if (!isCurrentUser && !isCreator) ...[
                  if (isPendingActivation && _isOrganizationCreator) ...[
                    // Quick activate button for pending admins
                    ElevatedButton.icon(
                      onPressed: () => _activateAdmin(userId),
                      icon: Icon(Icons.check_circle, size: 16, color: Colors.white),
                      label: Text('Activate', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 12),
                            Text('Edit User'),
                          ],
                        ),
                      ),
                      if (role == 'admin' && _isOrganizationCreator && !isPendingActivation) ...[
                        PopupMenuItem(
                          value: isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                isActive ? Icons.block : Icons.check_circle,
                                size: 18,
                                color: isActive ? Colors.orange : Colors.green,
                              ),
                              SizedBox(width: 12),
                              Text(isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                      ] else if (role != 'admin') ...[
                        PopupMenuItem(
                          value: isActive ? 'deactivate' : 'activate',
                          child: Row(
                            children: [
                              Icon(
                                isActive ? Icons.block : Icons.check_circle,
                                size: 18,
                                color: isActive ? Colors.orange : Colors.green,
                              ),
                              SizedBox(width: 12),
                              Text(isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                        ),
                      ],
                      PopupMenuItem(
                        value: 'reset_password',
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset, size: 18),
                            SizedBox(width: 12),
                            Text('Reset Password'),
                          ],
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete User', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditDialog(context, userId, data);
                          break;
                        case 'activate':
                        case 'deactivate':
                          if (role == 'admin' && _isOrganizationCreator) {
                            _toggleAdminStatus(userId, !isActive, data);
                          } else {
                            _toggleUserStatus(userId, !isActive, data);
                          }
                          break;
                        case 'reset_password':
                          _sendPasswordReset(data['email']);
                          break;
                        case 'delete':
                          _showDeleteDialog(context, userId, data['fullName'], data);
                          break;
                      }
                    },
                  ),
                ],
              ],
            ),

            // Mobile layout for actions on very small screens
            if (!isCurrentUser && !isCreator && MediaQuery.of(context).size.width < 400) ...[
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditDialog(context, userId, data),
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Edit'),
                  ),
                  if (!isPendingActivation)
                    TextButton.icon(
                      onPressed: () => _toggleUserStatus(userId, !isActive, data),
                      icon: Icon(
                        isActive ? Icons.block : Icons.check_circle,
                        size: 16,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      label: Text(isActive ? 'Deactivate' : 'Activate'),
                    ),
                ],
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

  Future<void> _activateAdmin(String adminId) async {
    final result = await _authService.activateAdmin(adminId, widget.organizationId);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin activated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleAdminStatus(String userId, bool isActive, Map<String, dynamic> userData) async {
    if (isActive) {
      // Regular activation
      _toggleUserStatus(userId, isActive, userData);
    } else {
      // Use special deactivation for admins if current user is org creator
      final result = await _authService.deactivateAdmin(userId, widget.organizationId);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin deactivated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Invite User'),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'To invite new users to your organization:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Share your organization code:', style: TextStyle(fontSize: 14)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            widget.organizationId,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.copy, color: Colors.blue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.organizationId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Organization code copied!')),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('2. Users can sign up with this code', style: TextStyle(fontSize: 14)),
                    SizedBox(height: 8),
                    Text('3. They will automatically join your organization', style: TextStyle(fontSize: 14)),
                    if (_tabController.index == 3) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: New admins will require activation from the organization creator',
                                style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String userId, Map<String, dynamic> userData) {
    bool isActive = userData['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Edit User'),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: userData['fullName']),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  enabled: false,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: userData['email']),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  enabled: false,
                ),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Active Status'),
                  subtitle: Text('Inactive users cannot access the system'),
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  activeColor: Colors.green,
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
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'isActive': isActive,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // Create audit log for status change
                  if (isActive != (userData['isActive'] ?? true)) {
                    await AuthService.createManagementAuditLog(
                      organizationCode: widget.organizationId,
                      action: isActive ? 'user_activated' : 'user_deactivated',
                      details: {
                        'userId': userId,
                        'userName': userData['fullName'],
                        'userEmail': userData['email'],
                        'userRole': userData['role'],
                        'newStatus': isActive ? 'active' : 'inactive',
                      },
                    );
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating user: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(String userId, bool isActive, Map<String, dynamic> userData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusChangedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Create audit log
      await AuthService.createManagementAuditLog(
        organizationCode: widget.organizationId,
        action: isActive ? 'user_activated' : 'user_deactivated',
        details: {
          'userId': userId,
          'userName': userData['fullName'],
          'userEmail': userData['email'],
          'userRole': userData['role'],
          'newStatus': isActive ? 'active' : 'inactive',
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'User activated successfully' : 'User deactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      // Create audit log
      await AuthService.createManagementAuditLog(
        organizationCode: widget.organizationId,
        action: 'password_reset_sent',
        details: {
          'targetEmail': email,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending password reset: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, String userId, String userName, Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$userName"?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The user will lose access to all data.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Instead of deleting, we'll mark as deleted
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({
                  'isActive': false,
                  'deletedAt': FieldValue.serverTimestamp(),
                  'deletedBy': FirebaseAuth.instance.currentUser?.uid,
                });

                // Create audit log
                await AuthService.createManagementAuditLog(
                  organizationCode: widget.organizationId,
                  action: 'user_deleted',
                  details: {
                    'deletedUserId': userId,
                    'deletedUserName': userData['fullName'],
                    'deletedUserEmail': userData['email'],
                    'deletedUserRole': userData['role'],
                  },
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}