import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../community/bloc.dart';
import '../community/feed_screen.dart';
import '../community/models.dart';
import 'course_page.dart';
import 'create_course.dart';

class LecturerHomePage extends StatefulWidget {
  @override
  _LecturerHomePageState createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends State<LecturerHomePage> {
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Navigation
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'User not authenticated');
        return;
      }

      // Load user data
      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        setState(() => _errorMessage = 'User data not found');
        return;
      }

      setState(() {
        _userData = userData;
      });

      // Load organization data
      final orgCode = userData['organizationCode'];
      if (orgCode == null) {
        setState(() => _errorMessage = 'Organization code not found');
        return;
      }

      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .get();

      if (orgDoc.exists) {
        setState(() {
          _organizationData = orgDoc.data();
        });
      }

      // Load courses created by this lecturer
      await _loadCourses(orgCode, user.uid);
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCourses(String orgCode, String lecturerId) async {
    try {
      // Simple query without isActive check and orderBy to avoid index issues
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .where('lecturerId', isEqualTo: lecturerId)
          .get();

      List<Map<String, dynamic>> coursesList = coursesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Filter out inactive courses if the field exists
      coursesList = coursesList.where((course) {
        final isActive = course['isActive'];
        // If isActive doesn't exist or is true, include the course
        return isActive == null || isActive == true;
      }).toList();

      // Manual sorting by createdAt (descending)
      coursesList.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order
      });

      setState(() {
        _courses = coursesList;
      });
    } catch (e) {
      print('Error loading courses: $e');
      setState(() {
        _errorMessage = 'Error loading courses: $e';
      });
    }
  }

  Future<void> _handleLogout() async {
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

  // Create CommunityUser from userData
  CommunityUser _createCommunityUser() {
    final user = _authService.currentUser;
    if (user == null || _userData == null) {
      throw Exception('User data not available');
    }

    return CommunityUser(
      uid: user.uid,
      fullName: _userData!['fullName'] ?? 'Unknown',
      email: _userData!['email'] ?? '',
      avatarUrl: _userData!['avatarUrl'],
      bio: _userData!['bio'],
      organizationCode: _userData!['organizationCode'] ?? '',
      role: _userData!['role'] ?? 'lecturer',
      postCount: _userData!['postCount'] ?? 0,
      friendCount: _userData!['friendCount'] ?? 0,
      joinDate: _userData!['createdAt'] != null
          ? (_userData!['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: _userData!['isActive'] ?? true,
    );
  }

  Future<void> _navigateToCommunity() async {
    try {
      final organizationCode = _userData?['organizationCode'] ?? '';
      if (organizationCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organization code not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Create community user object
      final communityUser = _createCommunityUser();

      // Get or create CommunityBloc
      CommunityBloc communityBloc;
      try {
        // Try to get existing bloc
        communityBloc = BlocProvider.of<CommunityBloc>(context);
      } catch (e) {
        // If no bloc exists, create a new one
        communityBloc = CommunityBloc();
      }

      // Initialize the bloc with user profile
      communityBloc.add(LoadUserProfile(communityUser.uid));

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to community feed
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: communityBloc,
            child: FeedScreen(
              organizationCode: organizationCode,
            ),
          ),
        ),
      ).then((_) {
        // Reset bottom navigation to Courses tab when returning from community
        setState(() {
          _currentIndex = 0;
        });
      });
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing community: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // Reset navigation index on error as well
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateCoursePage(),
            ),
          );

          if (result == true) {
            // Reload courses if a new course was created
            _loadData();
          }
        },
        backgroundColor: Colors.purple[400],
        child: Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Icon(
            Icons.school,
            color: Colors.purple[400],
            size: 32,
          ),
          SizedBox(width: 12),
          Text(
            'Study Hub',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.black87),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: Colors.black87),
          onPressed: () {
            // TODO: Implement notifications
          },
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[600]!, Colors.purple[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Text(
                      _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'L',
                      style: TextStyle(
                        color: Colors.purple[600],
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'Lecturer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userData?['email'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to profile page
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text('Calendar'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to calendar page
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings page
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.business),
              title: Text('Organization'),
              subtitle: Text(_organizationData?['name'] ?? ''),
            ),
            ListTile(
              leading: Icon(Icons.code),
              title: Text('Organization Code'),
              subtitle: Text(_organizationData?['code'] ?? ''),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${_userData?['fullName']?.split(' ').first ?? 'Lecturer'}!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You have ${_courses.length} active course${_courses.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Courses Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to all courses
                },
                child: Text(
                  'View All',
                  style: TextStyle(color: Colors.purple[400]),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Courses List
          if (_courses.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No courses yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first course to get started',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 24),
                  CustomButton(
                    text: 'Create Course',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateCoursePage(),
                        ),
                      );

                      if (result == true) {
                        // Reload courses if a new course was created
                        _loadData();
                      }
                    },
                    icon: Icons.add,
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              _courses.length,
                  (index) => _buildCourseCard(_courses[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoursePage(
                courseId: course['id'],
                courseData: course,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        course['code'] ?? course['title']?.substring(0, 2).toUpperCase() ?? 'CS',
                        style: TextStyle(
                          color: Colors.purple[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? 'Untitled Course',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      course['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '${course['enrolledCount'] ?? 0} students',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.school_outlined, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course['facultyName'] ?? 'Faculty',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });

        // Handle navigation
        switch (index) {
          case 0:
          // Already on courses page
            break;
          case 1:
          // Navigate to community (FeedScreen)
            _navigateToCommunity();
            break;
          case 2:
          // TODO: Navigate to chat
            break;
          case 3:
          // TODO: Navigate to calendar
            break;
          case 4:
          // TODO: Navigate to profile
            break;
        }
      },
      selectedItemColor: Colors.purple[400],
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Community',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}