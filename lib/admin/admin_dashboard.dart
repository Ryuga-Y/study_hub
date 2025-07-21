import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import 'user_management.dart';
import 'community_management.dart';
import 'course_management.dart';
import 'faculty_management.dart';
import 'program_management.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Navigation
  String _currentPage = 'Dashboard';

  // Data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;
  bool _isLoading = true;

  // Statistics
  Map<String, int> _stats = {
    'students': 0,
    'lecturers': 0,
    'faculties': 0,
    'programs': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Load user data
      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      setState(() {
        _userData = userData;
      });

      // Load organization data
      final orgCode = userData['organizationCode'];
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .get();

      if (orgDoc.exists) {
        setState(() {
          _organizationData = orgDoc.data();
        });

        // Load statistics
        await _loadStatistics(orgCode);
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics(String orgCode) async {
    try {
      // Get counts using aggregation queries
      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('organizationCode', isEqualTo: orgCode)
            .where('role', isEqualTo: 'student')
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('organizationCode', isEqualTo: orgCode)
            .where('role', isEqualTo: 'lecturer')
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('faculties')
            .where('isActive', isEqualTo: true)
            .count()
            .get(),

      ]);

      // Count programs
      int programCount = 0;
      final faculties = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('faculties')
          .where('isActive', isEqualTo: true)
          .get();

      for (var faculty in faculties.docs) {
        final programs = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('faculties')
            .doc(faculty.id)
            .collection('programs')
            .where('isActive', isEqualTo: true)
            .count()
            .get();
        programCount += programs.count ?? 0;
      }

      setState(() {
        _stats = {
          'students': futures[0].count ?? 0,
          'lecturers': futures[1].count ?? 0,
          'faculties': futures[2].count ?? 0,
          'programs': programCount,
        };
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _navigateTo(String page) {
    setState(() {
      _currentPage = page;
    });

    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1200;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: !isDesktop ? _buildMobileDrawer() : null,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.redAccent, size: 28),
          SizedBox(width: 12),
          Text(
            _organizationData?['name'] ?? 'Admin Dashboard',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      leading: MediaQuery.of(context).size.width < 1200
          ? IconButton(
        icon: Icon(Icons.menu, color: Colors.black87),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      )
          : null,
      automaticallyImplyLeading: false,
      actions: [
        // Organization Code
        Container(
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.business, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                _organizationData?['code'] ?? '',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Profile Menu
        PopupMenuButton<String>(
          offset: Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Text(
                _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            } else if (value == 'profile') {
              _navigateTo('Profile');
            }
          },
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: _currentPage == 'Dashboard',
                  onTap: () => _navigateTo('Dashboard'),
                ),
                _buildMenuItem(
                  icon: Icons.people,
                  title: 'Users',
                  isSelected: _currentPage == 'Users',
                  onTap: () => _navigateTo('Users'),
                ),
                _buildMenuItem(
                  icon: Icons.school,
                  title: 'Faculties',
                  isSelected: _currentPage == 'Faculties',
                  onTap: () => _navigateTo('Faculties'),
                ),
                _buildMenuItem(
                  icon: Icons.book,
                  title: 'Programs',
                  isSelected: _currentPage == 'Programs',
                  onTap: () => _navigateTo('Programs'),
                ),
                _buildMenuItem(
                  icon: Icons.library_books,
                  title: 'Courses',
                  isSelected: _currentPage == 'Courses',
                  onTap: () => _navigateTo('Courses'),
                ),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  title: 'Community',
                  isSelected: _currentPage == 'Community',
                  onTap: () => _navigateTo('Community'),
                ),
                Divider(height: 32),
                _buildMenuItem(
                  icon: Icons.person,
                  title: 'Profile',
                  isSelected: _currentPage == 'Profile',
                  onTap: () => _navigateTo('Profile'),
                ),
              ],
            ),
          ),

          // User info at bottom
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent,
                  child: Text(
                    _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userData?['fullName'] ?? 'Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Administrator',
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
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[700]!, Colors.redAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userData?['email'] ?? '',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              title: 'Dashboard',
              isSelected: _currentPage == 'Dashboard',
              onTap: () => _navigateTo('Dashboard'),
            ),
            _buildDrawerItem(
              icon: Icons.people,
              title: 'Users',
              isSelected: _currentPage == 'Users',
              onTap: () => _navigateTo('Users'),
            ),
            _buildDrawerItem(
              icon: Icons.school,
              title: 'Faculties',
              isSelected: _currentPage == 'Faculties',
              onTap: () => _navigateTo('Faculties'),
            ),
            _buildDrawerItem(
              icon: Icons.book,
              title: 'Programs',
              isSelected: _currentPage == 'Programs',
              onTap: () => _navigateTo('Programs'),
            ),
            _buildDrawerItem(
              icon: Icons.library_books,
              title: 'Courses',
              isSelected: _currentPage == 'Courses',
              onTap: () => _navigateTo('Courses'),
            ),
            _buildDrawerItem(
              icon: Icons.people_outline,
              title: 'Community',
              isSelected: _currentPage == 'Community',
              onTap: () => _navigateTo('Community'),
            ),
            Divider(),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              isSelected: false,
              onTap: _handleLogout,
              textColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.redAccent.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.redAccent : Colors.grey[700],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.redAccent : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? (isSelected ? Colors.redAccent : Colors.grey[700]),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isSelected ? Colors.redAccent : Colors.grey[800]),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.redAccent.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }

  Widget _buildContent() {
    switch (_currentPage) {
      case 'Dashboard':
        return _buildDashboardContent();
      case 'Users':
        return UserManagementPage(organizationId: _organizationData?['code'] ?? '');
      case 'Faculties':
        return FacultyManagementPage(organizationId: _organizationData?['code'] ?? '');
      case 'Programs':
        return ProgramManagementPage(organizationId: _organizationData?['code'] ?? '');
      case 'Courses':
        return CourseManagementPage(organizationId: _organizationData?['code'] ?? '');
      case 'Community':
        return CommunityManagementPage(organizationId: _organizationData?['code'] ?? '');
      case 'Profile':
        return _buildProfileContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[700]!, Colors.redAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${_userData?['fullName']?.split(' ').first ?? 'Admin'}!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Here\'s what\'s happening in your organization today',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.dashboard,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Statistics Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 600 ? 1 :
              constraints.maxWidth < 900 ? 2 : 4;

              return GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth < 600 ? 2 : 1.5,
                children: [
                  _buildStatCard(
                    title: 'Total Students',
                    value: _stats['students'].toString(),
                    icon: Icons.school,
                    color: Colors.blue,
                  ),
                  _buildStatCard(
                    title: 'Total Lecturers',
                    value: _stats['lecturers'].toString(),
                    icon: Icons.person,
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    title: 'Faculties',
                    value: _stats['faculties'].toString(),
                    icon: Icons.business,
                    color: Colors.orange,
                  ),
                  _buildStatCard(
                    title: 'Programs',
                    value: _stats['programs'].toString(),
                    icon: Icons.book,
                    color: Colors.purple,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 32),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction(
                icon: Icons.person_add,
                label: MediaQuery.of(context).size.width > 400 ? 'Add User' : 'User',
                onTap: () => _navigateTo('Users'),
              ),
              _buildQuickAction(
                icon: Icons.school,
                label: MediaQuery.of(context).size.width > 400 ? 'Add Faculty' : 'Faculty',
                onTap: () => _navigateTo('Faculties'),
              ),
              _buildQuickAction(
                icon: Icons.book,
                label: MediaQuery.of(context).size.width > 400 ? 'Add Program' : 'Program',
                onTap: () => _navigateTo('Programs'),
              ),
              _buildQuickAction(
                icon: Icons.library_books,
                label: MediaQuery.of(context).size.width > 400 ? 'Add Course' : 'Course',
                onTap: () => _navigateTo('Courses'),
              ),
            ],
          ),

          SizedBox(height: 32),

          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_organizationData == null) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAllActivitiesDialog(),
              icon: Icon(Icons.history, size: 16),
              label: Text('View All'),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 5,
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('organizations')
                .doc(_organizationData!['code'])
                .collection('audit_logs')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No recent activity',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildActivityItem(data);
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final action = activity['action'] ?? '';
    final timestamp = activity['timestamp'] as Timestamp?;
    final details = activity['details'] as Map<String, dynamic>? ?? {};
    final performedBy = activity['performedBy'] ?? '';

    // Get activity info
    final activityInfo = _getActivityInfo(action, details);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Activity Icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activityInfo['color'].withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activityInfo['icon'],
              color: activityInfo['color'],
              size: 20,
            ),
          ),
          SizedBox(width: 12),

          // Activity Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityInfo['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (activityInfo['subtitle'] != null) ...[
                  SizedBox(height: 2),
                  Text(
                    activityInfo['subtitle'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Timestamp
          if (timestamp != null)
            Text(
              _formatRelativeTime(timestamp.toDate()),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getActivityInfo(String action, Map<String, dynamic> details) {
    switch (action) {
      case 'student_account_created':
        return {
          'icon': Icons.school,
          'color': Colors.blue,
          'title': 'New student registered',
          'subtitle': details['userName'] != null ? '${details['userName']} joined the organization' : null,
        };
      case 'lecturer_account_created':
        return {
          'icon': Icons.person,
          'color': Colors.green,
          'title': 'New lecturer registered',
          'subtitle': details['userName'] != null ? '${details['userName']} joined the organization' : null,
        };
      case 'admin_account_created':
        return {
          'icon': Icons.admin_panel_settings,
          'color': Colors.red,
          'title': 'New admin registered',
          'subtitle': details['userName'] != null ? '${details['userName']} joined as admin' : null,
        };
      case 'admin_joined_pending_activation':
        return {
          'icon': Icons.hourglass_empty,
          'color': Colors.orange,
          'title': 'Admin pending activation',
          'subtitle': details['adminName'] != null ? '${details['adminName']} awaiting activation' : null,
        };
      case 'admin_activated':
        return {
          'icon': Icons.check_circle,
          'color': Colors.green,
          'title': 'Admin account activated',
          'subtitle': 'Admin user was activated',
        };
      case 'admin_deactivated':
        return {
          'icon': Icons.block,
          'color': Colors.orange,
          'title': 'Admin account deactivated',
          'subtitle': 'Admin user was deactivated',
        };
      case 'faculty_created':
        return {
          'icon': Icons.school,
          'color': Colors.blue,
          'title': 'New faculty created',
          'subtitle': details['facultyName'] != null ? 'Faculty: ${details['facultyName']}' : null,
        };
      case 'program_created':
        return {
          'icon': Icons.book,
          'color': Colors.purple,
          'title': 'New program created',
          'subtitle': details['programName'] != null ? 'Program: ${details['programName']}' : null,
        };
      case 'course_created':
        return {
          'icon': Icons.library_books,
          'color': Colors.indigo,
          'title': 'New course created',
          'subtitle': details['courseName'] != null ? 'Course: ${details['courseName']}' : null,
        };
      default:
        return {
          'icon': Icons.info,
          'color': Colors.grey,
          'title': action.replaceAll('_', ' ').split(' ').map((word) =>
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1)).join(' '),
          'subtitle': null,
        };
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showAllActivitiesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 600,
          height: 700,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Recent Activities',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(_organizationData!['code'])
                      .collection('audit_logs')
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text('No activities found', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildActivityItem(data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: Colors.redAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),

          // Profile Card
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.redAccent,
                  child: Text(
                    _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                    style: TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _userData?['fullName'] ?? 'Admin User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _userData?['email'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                Divider(),
                SizedBox(height: 24),
                _buildInfoRow('Role', 'Administrator'),
                SizedBox(height: 16),
                _buildInfoRow('Organization', _organizationData?['name'] ?? ''),
                SizedBox(height: 16),
                _buildInfoRow('Organization Code', _organizationData?['code'] ?? ''),
                SizedBox(height: 16),
                _buildInfoRow('Member Since', _formatDate(_userData?['createdAt'])),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Action Buttons
          CustomButton(
            text: 'Change Password',
            onPressed: () {
              // Implement password change
            },
            backgroundColor: Colors.blue,
            icon: Icons.lock,
          ),

          SizedBox(height: 16),

          CustomButton(
            text: 'Logout',
            onPressed: _handleLogout,
            backgroundColor: Colors.red,
            icon: Icons.logout,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}