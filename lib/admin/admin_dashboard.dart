import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/admin/user_management.dart';
// Import the management pages
import '../Authentication/sign_in.dart';
import 'community_management.dart';
import 'course_management.dart';
import 'faculty_management.dart';
import 'program_management.dart';


class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Current page tracking
  String _currentPage = 'Dashboard';
  List<String> _breadcrumb = ['Dashboard'];

  // User and organization data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;

  // Statistics
  int _totalStudents = 0;
  int _totalLecturers = 0;
  int _totalFaculties = 0;
  int _totalPrograms = 0;
  int _activeChats = 0;

  // Sidebar state for responsive design
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load user data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userData = userDoc.data();
      });

      // Load organization data
      final orgId = _userData!['organizationId'];
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();

      if (orgDoc.exists) {
        setState(() {
          _organizationData = orgDoc.data();
        });

        // Load statistics
        await _loadStatistics(orgId);
      }
    }
  }

  Future<void> _loadStatistics(String orgId) async {
    // Count students
    final studentsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .where('role', isEqualTo: 'student')
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    // Count lecturers
    final lecturersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .where('role', isEqualTo: 'lecturer')
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    // Count faculties
    final facultiesQuery = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('faculties')
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    // Count programs (this is an approximation, you might need a different approach)
    int programCount = 0;
    final faculties = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('faculties')
        .where('isActive', isEqualTo: true)
        .get();

    for (var faculty in faculties.docs) {
      final programs = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('faculties')
          .doc(faculty.id)
          .collection('programs')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      programCount += programs.count ?? 0;
    }

    setState(() {
      _totalStudents = studentsQuery.count ?? 0;
      _totalLecturers = lecturersQuery.count ?? 0;
      _totalFaculties = facultiesQuery.count ?? 0;
      _totalPrograms = programCount;
    });
  }

  void _navigateTo(String page) {
    setState(() {
      _currentPage = page;
      if (page == 'Dashboard') {
        _breadcrumb = ['Dashboard'];
      } else {
        _breadcrumb = ['Dashboard', page];
      }
    });

    // Close drawer on mobile
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    final isTablet = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(),
      drawer: !isDesktop ? _buildDrawer() : null,
      body: Row(
        children: [
          // Sidebar for desktop
          if (isDesktop) _buildSidebar(),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Breadcrumb
                _buildBreadcrumb(),

                // Content area
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
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
          if (MediaQuery.of(context).size.width >= 1200)
            Icon(Icons.school, color: Colors.redAccent, size: 28),
          if (MediaQuery.of(context).size.width >= 1200)
            SizedBox(width: 12),
          Text(
            _organizationData?['name'] ?? 'Study Hub Admin',
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
        // Notifications
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_outlined, color: Colors.black87),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {
            // Handle notifications
          },
        ),

        // Profile menu
        PopupMenuButton(
          offset: Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: CircleAvatar(
            backgroundColor: Colors.redAccent,
            child: Text(
              _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
              style: TextStyle(color: Colors.white),
            ),
          ),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
              value: 'profile',
            ),
            PopupMenuItem<String>(
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
              value: 'settings',
            ),
            PopupMenuDivider(),
            PopupMenuItem<String>(
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
              value: 'logout',
            ),
          ],
          onSelected: (value) {
            if (value == 'profile') {
              _navigateTo('Profile');
            } else if (value == 'logout') {
              _showLogoutDialog();
            }
          },
        ),
        SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSidebar() {
    final isCollapsed = _isSidebarCollapsed;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: isCollapsed ? 70 : 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toggle button
          Container(
            padding: EdgeInsets.all(8),
            child: Align(
              alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  isCollapsed ? Icons.menu : Icons.menu_open,
                  color: Colors.grey[700],
                ),
                onPressed: () {
                  setState(() {
                    _isSidebarCollapsed = !_isSidebarCollapsed;
                  });
                },
              ),
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: _currentPage == 'Dashboard',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Dashboard'),
                ),
                _buildMenuItem(
                  icon: Icons.people,
                  title: 'Users',
                  isSelected: _currentPage == 'Users',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Users'),
                ),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  title: 'Community',
                  isSelected: _currentPage == 'Community',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Community'),
                ),
                _buildMenuItem(
                  icon: Icons.chat_bubble,
                  title: 'Chat',
                  isSelected: _currentPage == 'Chat',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Chat'),
                  badge: _activeChats > 0 ? _activeChats.toString() : null,
                ),
                _buildMenuItem(
                  icon: Icons.school,
                  title: 'Faculties',
                  isSelected: _currentPage == 'Faculties',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Faculties'),
                ),
                _buildMenuItem(
                  icon: Icons.book,
                  title: 'Programs',
                  isSelected: _currentPage == 'Programs',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Programs'),
                ),
                _buildMenuItem(
                  icon: Icons.library_books,
                  title: 'Courses',
                  isSelected: _currentPage == 'Courses',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Courses'),
                ),
                Divider(height: 32),
                _buildMenuItem(
                  icon: Icons.person,
                  title: 'Profile',
                  isSelected: _currentPage == 'Profile',
                  isCollapsed: isCollapsed,
                  onTap: () => _navigateTo('Profile'),
                ),
              ],
            ),
          ),

          // Organization code at bottom
          if (!isCollapsed)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _organizationData?['code'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.copy, size: 18),
                        onPressed: () {
                          // Copy to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Organization code copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer header
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.redAccent,
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

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
                    icon: Icons.people_outline,
                    title: 'Community',
                    isSelected: _currentPage == 'Community',
                    onTap: () => _navigateTo('Community'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.chat_bubble,
                    title: 'Chat',
                    isSelected: _currentPage == 'Chat',
                    onTap: () => _navigateTo('Chat'),
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
                  Divider(),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    isSelected: _currentPage == 'Profile',
                    onTap: () => _navigateTo('Profile'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    isSelected: false,
                    onTap: _showLogoutDialog,
                    textColor: Colors.red,
                  ),
                ],
              ),
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
    required bool isCollapsed,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Tooltip(
      message: isCollapsed ? title : '',
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 16 : 20,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.redAccent : Colors.grey[700],
                  size: 24,
                ),
                if (!isCollapsed) ...[
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.redAccent : Colors.grey[800],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
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

  Widget _buildBreadcrumb() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _breadcrumb.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ),
            Text(
              _breadcrumb[i],
              style: TextStyle(
                color: i == _breadcrumb.length - 1 ? Colors.black87 : Colors.grey,
                fontWeight: i == _breadcrumb.length - 1 ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentPage) {
      case 'Dashboard':
        return _buildDashboardContent();
      case 'Users':
        return UserManagementPage(organizationId: _userData?['organizationId'] ?? '');
      case 'Community':
        return CommunityManagementPage(organizationId: _userData?['organizationId'] ?? '');
      case 'Chat':
        return _buildChatContent();
      case 'Faculties':
        return FacultyManagementPage(organizationId: _userData?['organizationId'] ?? '');
      case 'Programs':
        return ProgramManagementPage(organizationId: _userData?['organizationId'] ?? '');
      case 'Courses':
        return CourseManagementPage(organizationId: _userData?['organizationId'] ?? '');
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
          // Welcome message
          Text(
            'Welcome back, ${_userData?['fullName']?.split(' ').first ?? 'Admin'}!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening in your organization today.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),

          // Statistics cards in 2x2 grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: MediaQuery.of(context).size.width > 768 ? 2.5 : 1.5,
            children: [
              _buildStatCard(
                title: 'Total Students',
                value: _totalStudents.toString(),
                icon: Icons.school,
                color: Colors.blue,
                trend: '+12%',
              ),
              _buildStatCard(
                title: 'Total Lecturers',
                value: _totalLecturers.toString(),
                icon: Icons.person,
                color: Colors.green,
                trend: '+5%',
              ),
              _buildStatCard(
                title: 'Faculties',
                value: _totalFaculties.toString(),
                icon: Icons.business,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Programs',
                value: _totalPrograms.toString(),
                icon: Icons.book,
                color: Colors.purple,
              ),
            ],
          ),
          SizedBox(height: 32),

          // Quick actions
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
                label: 'Add User',
                onTap: () {
                  _navigateTo('Users');
                },
              ),
              _buildQuickAction(
                icon: Icons.school,
                label: 'Add Faculty',
                onTap: () {
                  _navigateTo('Faculties');
                },
              ),
              _buildQuickAction(
                icon: Icons.book,
                label: 'Add Program',
                onTap: () {
                  _navigateTo('Programs');
                },
              ),
              _buildQuickAction(
                icon: Icons.library_books,
                label: 'Add Course',
                onTap: () {
                  _navigateTo('Courses');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start, // or .center
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              if (trend != null)
                Text(
                  trend,
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8), // Reduced height
          Text(
            value,
            style: TextStyle(
              fontSize: 28, // Reduced font size
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder for other content pages
  Widget _buildChatContent() {
    return Center(
      child: Text('Chat Management - To be implemented'),
    );
  }

  Widget _buildProfileContent() {
    return Center(
      child: Text('Profile Settings - To be implemented'),
    );
  }

  // Updated logout dialog method with proper navigation handling
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Close the dialog first
                Navigator.pop(context);

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Sign out from Firebase
                await FirebaseAuth.instance.signOut();

                // Close loading dialog
                Navigator.pop(context);

                // Use direct navigation instead of named route
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignInPage(), // Import your SignInPage widget
                  ),
                      (route) => false,
                );

              } catch (e) {
                // Close loading dialog if it's open
                Navigator.pop(context);

                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logout failed: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}