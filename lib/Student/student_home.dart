import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Student/student_course.dart';
import '../../Authentication/auth_services.dart';
import '../../Authentication/custom_widgets.dart';


class StudentHomePage extends StatefulWidget {
  @override
  _StudentHomePageState createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _pendingAssignments = [];
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

      // Load enrolled courses and pending assignments
      await Future.wait([
        _loadEnrolledCourses(orgCode, user.uid),
        _loadPendingAssignments(orgCode, user.uid),
      ]);
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

  Future<void> _loadEnrolledCourses(String orgCode, String studentId) async {
    try {
      // Get all enrollments for this student
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .get();

      List<Map<String, dynamic>> coursesList = [];

      for (var courseDoc in enrollmentsSnapshot.docs) {
        // Check if student is enrolled in this course
        final enrollmentQuery = await courseDoc.reference
            .collection('enrollments')
            .where('studentId', isEqualTo: studentId)
            .get();

        if (enrollmentQuery.docs.isNotEmpty) {
          final courseData = courseDoc.data();
          coursesList.add({
            'id': courseDoc.id,
            ...courseData,
            'enrolledAt': enrollmentQuery.docs.first.data()['enrolledAt'],
          });
        }
      }

      // Filter active courses and sort by enrollment date
      coursesList = coursesList.where((course) {
        final isActive = course['isActive'];
        return isActive == null || isActive == true;
      }).toList();

      coursesList.sort((a, b) {
        final aTime = a['enrolledAt'] as Timestamp?;
        final bTime = b['enrolledAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _enrolledCourses = coursesList;
      });
    } catch (e) {
      print('Error loading enrolled courses: $e');
    }
  }

  Future<void> _loadPendingAssignments(String orgCode, String studentId) async {
    try {
      List<Map<String, dynamic>> allAssignments = [];

      // For each enrolled course, get assignments
      for (var course in _enrolledCourses) {
        final assignmentsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('courses')
            .doc(course['id'])
            .collection('assignments')
            .get();

        for (var assignmentDoc in assignmentsSnapshot.docs) {
          final assignmentData = assignmentDoc.data();

          // Check if student has submitted this assignment
          final submissionQuery = await assignmentDoc.reference
              .collection('submissions')
              .where('studentId', isEqualTo: studentId)
              .get();

          // If no submission found and due date hasn't passed, add to pending
          if (submissionQuery.docs.isEmpty) {
            final dueDate = assignmentData['dueDate'] as Timestamp?;
            if (dueDate != null && dueDate.toDate().isAfter(DateTime.now())) {
              allAssignments.add({
                'id': assignmentDoc.id,
                'courseId': course['id'],
                'courseName': course['title'] ?? course['name'],
                'courseCode': course['code'],
                ...assignmentData,
              });
            }
          }
        }
      }

      // Sort by due date (earliest first)
      allAssignments.sort((a, b) {
        final aTime = a['dueDate'] as Timestamp?;
        final bTime = b['dueDate'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

      setState(() {
        _pendingAssignments = allAssignments;
      });
    } catch (e) {
      print('Error loading pending assignments: $e');
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

  String _getTimeRemaining(Timestamp? dueDate) {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final due = dueDate.toDate();
    final difference = due.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays > 7) {
      return 'Due in ${difference.inDays} days';
    } else if (difference.inDays > 1) {
      return 'Due in ${difference.inDays} days';
    } else if (difference.inDays == 1) {
      return 'Due tomorrow';
    } else if (difference.inHours > 1) {
      return 'Due in ${difference.inHours} hours';
    } else if (difference.inMinutes > 1) {
      return 'Due in ${difference.inMinutes} minutes';
    } else {
      return 'Due soon';
    }
  }

  Color _getDueDateColor(Timestamp? dueDate) {
    if (dueDate == null) return Colors.grey;

    final now = DateTime.now();
    final due = dueDate.toDate();
    final difference = due.difference(now);

    if (difference.isNegative) {
      return Colors.red;
    } else if (difference.inDays <= 1) {
      return Colors.orange;
    } else if (difference.inDays <= 3) {
      return Colors.amber;
    } else {
      return Colors.green;
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
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 32,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.school,
              color: Colors.purple[400],
              size: 32,
            ),
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
                      _userData?['fullName']?.substring(0, 1).toUpperCase() ?? 'S',
                      style: TextStyle(
                        color: Colors.purple[600],
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'Student',
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
              title: Text('Student ID'),
              subtitle: Text(_userData?['studentId'] ?? 'N/A'),
            ),
            ListTile(
              leading: Icon(Icons.school),
              title: Text('Faculty'),
              subtitle: Text(_userData?['facultyName'] ?? 'N/A'),
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
                  'Welcome back, ${_userData?['fullName']?.split(' ').first ?? 'Student'}!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You have ${_enrolledCourses.length} enrolled course${_enrolledCourses.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // To Do Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'To do:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to assignment history
                      },
                      child: Text(
                        'View History',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              _pendingAssignments.length.toString(),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[600],
                              ),
                            ),
                            Text(
                              'Work',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 60,
                      child: VerticalDivider(
                        color: Colors.grey[400],
                        thickness: 1,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Text(
                              '0', // TODO: Calculate missed assignments
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[600],
                              ),
                            ),
                            Text(
                              'Missed',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Pending Assignments Section
          if (_pendingAssignments.isNotEmpty) ...[
            Text(
              'Upcoming Assignments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(
              _pendingAssignments.take(3).length,
                  (index) => _buildAssignmentCard(_pendingAssignments[index]),
            ),
            if (_pendingAssignments.length > 3)
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to all assignments
                  },
                  child: Text(
                    'View all ${_pendingAssignments.length} assignments',
                    style: TextStyle(color: Colors.purple[400]),
                  ),
                ),
              ),
            SizedBox(height: 24),
          ],

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
          if (_enrolledCourses.isEmpty)
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
                    'No courses enrolled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact your lecturer to get enrolled in courses',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              _enrolledCourses.length,
                  (index) => _buildCourseCard(_enrolledCourses[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final dueDate = assignment['dueDate'] as Timestamp?;
    final timeRemaining = _getTimeRemaining(dueDate);
    final dueDateColor = _getDueDateColor(dueDate);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
          // Navigate to course page with assignment focus
          final courseId = assignment['courseId'];
          final course = _enrolledCourses.firstWhere(
                (c) => c['id'] == courseId,
            orElse: () => {},
          );

          if (course.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentCoursePage(
                  courseId: courseId,
                  courseData: course,
                  focusAssignmentId: assignment['id'],
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.assignment, color: Colors.orange, size: 28),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['title'] ?? 'Assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${assignment['courseCode'] ?? ''} - ${assignment['courseName'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: dueDateColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          timeRemaining,
                          style: TextStyle(
                            color: dueDateColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
              builder: (context) => StudentCoursePage(
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
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          course['lecturerName'] ?? 'Unknown Lecturer',
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
          // Already on home page
            break;
          case 1:
          // TODO: Navigate to community
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
          icon: Icon(Icons.home),
          label: 'Home',
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