import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async'; // Add Timer import
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../community/bloc.dart';
import '../community/feed_screen.dart';
import '../community/models.dart';
import '../profile_page.dart';
import 'student_course.dart';
import 'calendar.dart'; // Import the calendar page
import '../Stu_goal.dart'; // Import the goal page
import '../goal_progress_service.dart'; // Import the goal service
import '../chat_integrated.dart';
import '../stu_report.dart';
import '../notification.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({Key? key}) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final GoalProgressService _goalService = GoalProgressService();
  final NotificationService _notificationService = NotificationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _enrolledCourses = [];
  int _pendingAssignments = 0;
  int _missedAssignments = 0;
  int _waterBuckets = 0; // Add water bucket count
  bool _isStudent = false; // Track if user is a student
  bool _isLoading = true;
  String? _errorMessage;

  // Navigation
  int _currentIndex = 0;

  // Animation and timer variables
  Timer? _autoSyncTimer;
  StreamSubscription? _goalProgressSubscription;

  // FIXED: Enhanced notification initialization with better error handling and debugging
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeAnimations();

    // Load data first, then initialize notifications with proper delay
    _loadData().then((_) {
      if (mounted && _userData != null) {
        // Add delay to ensure user data is fully loaded
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted) {
            print('🔄 Initializing notification service in student_home.dart...');
            print('📍 User: ${_userData?['fullName']}');
            print('📍 Role: ${_userData?['role']}');
            print('📍 Org: ${_userData?['organizationCode']}');

            _notificationService.initialize().then((_) {
              print('✅ Notification service initialized successfully');
              // Clean up test notifications once
              _notificationService.cleanupTestNotifications();
            }).catchError((error) {
              print('❌ Error initializing notification service: $error');
            });
          }
        });

        _startListeningForSubmissions();
        _startRealtimeGoalProgressListener();
        _startAutoSyncTimer();
        _checkForMissedRewards();
      }
    });
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel timers and subscriptions
    _autoSyncTimer?.cancel();
    _goalProgressSubscription?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - refresh data
      _loadData();
      _checkForNewSubmissions();
    }
  }

  // Initialize animations
  void _initializeAnimations() {
    // Add any animation initialization code here if needed
  }

  // Load goal progress
  Future<void> _loadGoalProgress() async {
    try {
      await _loadWaterBuckets();
    } catch (e) {
      debugPrint('Error loading goal progress: $e');
    }
  }

  // Start realtime goal progress listener
  void _startRealtimeGoalProgressListener() {
    final user = _authService.currentUser;
    if (user == null) return;

    _goalProgressSubscription = FirebaseFirestore.instance
        .collection('goalProgress')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          final newBuckets = data['waterBuckets'] ?? 0;
          if (newBuckets != _waterBuckets) {
            if (mounted) {
              setState(() {
                _waterBuckets = newBuckets;
              });
            }
          }
        }
      }
    });
  }

  // Start auto sync timer
  void _startListeningForSubmissions() {
    // Check for new submissions when app starts
    _checkForNewSubmissions();

    // Set up periodic checks (every 10 seconds for faster detection)
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkForNewSubmissions();
      } else {
        timer.cancel();
      }
    });
  }

  // Check for missed rewards
  Future<void> _checkForMissedRewards() async {
    try {
      // Implementation for checking missed rewards
      // This would depend on your specific reward logic
    } catch (e) {
      debugPrint('Error checking for missed rewards: $e');
    }
  }

  // Start listening for new submissions automatically
  // Start auto sync timer
  void _startAutoSyncTimer() {
    _autoSyncTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (mounted) {
        _checkForNewSubmissions();
      }
    });
  }

  // Check for new submissions and update water buckets
  Future<void> _checkForNewSubmissions() async {
    try {
      await _goalService.checkAndProcessNewSubmissions();

      // Reload water bucket count to update FAB
      final previousBuckets = _waterBuckets;
      await _loadWaterBuckets();

      // Show notification if buckets increased
      if (_waterBuckets > previousBuckets) {
        final bucketsAdded = _waterBuckets - previousBuckets;
        _showBucketRewardNotification(bucketsAdded);
      }
    } catch (e) {
      print('Error checking for new submissions: $e');
    }
  }

  // Show notification when water buckets are earned
  void _showBucketRewardNotification(int bucketsAdded) {
    String submissionType = '';
    if (bucketsAdded == 1) {
      submissionType = 'tutorial';
    } else if (bucketsAdded == 4) {
      submissionType = 'assignment';
    } else {
      submissionType = 'submission';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('🎉 You earned $bucketsAdded water bucket${bucketsAdded == 1 ? '' : 's'} for completing a $submissionType!'),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_drink, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '+$bucketsAdded',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

      if (mounted) {
        setState(() {
          _userData = userData;
          _isStudent = userData['role'] == 'student'; // Check if user is a student
        });
      }

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
        if (mounted) {
          setState(() {
            _organizationData = orgDoc.data();
          });
        }
      }

      // Load enrolled courses and assignments
      await _loadEnrolledCourses(orgCode, user.uid);
      await _loadAssignmentStats(orgCode, user.uid);
      await _loadWaterBuckets(); // Load water bucket count
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ FIXED: Use getGoalProgress() instead of getWaterBucketCount()
  Future<void> _loadWaterBuckets() async {
    try {
      // Only load water buckets if user is a student
      final isStudent = await _goalService.isCurrentUserStudent();
      if (isStudent) {
        final progress = await _goalService.getGoalProgress();
        final bucketCount = progress?['waterBuckets'] ?? 0;
        if (mounted) {
          setState(() {
            _waterBuckets = bucketCount;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _waterBuckets = 0; // Non-students have no buckets
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading water buckets: $e');
      if (mounted) {
        setState(() {
          _waterBuckets = 0;
        });
      }
    }
  }

  Future<void> _loadEnrolledCourses(String orgCode, String studentId) async {
    try {
      // Get all enrollments for this student
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('enrollments')
          .where('studentId', isEqualTo: studentId)
          .get();

      List<Map<String, dynamic>> coursesList = [];

      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        // Get the course reference from the enrollment
        final courseRef = enrollmentDoc.reference.parent.parent;
        if (courseRef != null) {
          final courseDoc = await courseRef.get();
          if (courseDoc.exists) {
            final courseData = courseDoc.data() as Map<String, dynamic>;
            // Only include active courses
            if (courseData['isActive'] != false) {
              coursesList.add({
                'id': courseDoc.id,
                ...courseData,
                'enrolledAt': enrollmentDoc.data()['enrolledAt'],
              });
            }
          }
        }
      }

      // Sort by enrolled date (most recent first)
      coursesList.sort((a, b) {
        final aTime = a['enrolledAt'] as Timestamp?;
        final bTime = b['enrolledAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _enrolledCourses = coursesList;
        });
      }
    } catch (e) {
      debugPrint('Error loading enrolled courses: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
        });
      }
    }
  }

  Future<void> _loadAssignmentStats(String orgCode, String studentId) async {
    try {
      int pending = 0;
      int missed = 0;

      // For each enrolled course, check assignments
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
          final dueDate = assignmentData['dueDate'] as Timestamp?;

          if (dueDate != null) {
            // Check if student has submitted
            final submissionSnapshot = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(orgCode)
                .collection('courses')
                .doc(course['id'])
                .collection('assignments')
                .doc(assignmentDoc.id)
                .collection('submissions')
                .where('studentId', isEqualTo: studentId)
                .get();

            final hasSubmitted = submissionSnapshot.docs.isNotEmpty;
            final now = DateTime.now();
            final dueDatetime = dueDate.toDate();

            if (!hasSubmitted) {
              if (dueDatetime.isAfter(now)) {
                pending++;
              } else {
                missed++;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingAssignments = pending;
          _missedAssignments = missed;
        });
      }
    } catch (e) {
      debugPrint('Error loading assignment stats: $e');
    }
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> arguments) {
    if (arguments['assignmentId'] != null) {
      // Navigate to assignment details page
      Navigator.pushNamed(
        context,
        '/assignment-details',
        arguments: {
          'assignmentId': arguments['assignmentId'],
          'courseId': arguments['courseId'],
        },
      );
    } else if (arguments['materialId'] != null) {
      // Navigate to tutorial details page
      Navigator.pushNamed(
        context,
        '/material-details',
        arguments: {
          'materialId': arguments['materialId'],
          'courseId': arguments['courseId'],
        },
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarPage(),
      ),
    );
  }

  void _navigateToReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentReportPage(),
      ),
    );
  }

  void _navigateToGoalSystem() async {
    // Check if user is a student before allowing access
    final isStudent = await _goalService.isCurrentUserStudent();
    if (!isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌱 Goal system is only available for students'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StuGoal(),
      ),
    ).then((_) {
      // Reload water buckets when returning from goal system
      _loadWaterBuckets();
    });
  }

  // Create CommunityUser from userData (adapted for students)
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
      role: _userData!['role'] ?? 'student',
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
        if (mounted) {
          setState(() {
            _currentIndex = 0;
          });
        }
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
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  }
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
      // No floating action button
    );
  }

  // FIXED: Update the _buildAppBar method in student_home.dart
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
          const SizedBox(width: 12),
          const Text(
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
        icon: const Icon(Icons.menu, color: Colors.black87),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      // FIXED: Enhanced notification bell with proper initialization and error handling
      actions: [
        // ✅ ENHANCED: Real-time notification bell with better error handling
        StreamBuilder<int>(
          stream: _notificationService.notificationCountStream,
          initialData: 0,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;

            // Debug notification count
            if (count > 0) {
              print('📬 Student Home: $count unread notifications');
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: Colors.black87),
                  onPressed: () async {
                    print('🔔 Notification bell tapped');

                    // Ensure service is initialized before showing dialog
                    if (!_notificationService.isInitialized) {
                      print('🔄 Notification service not initialized, initializing...');

                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      try {
                        await _notificationService.initialize();
                        Navigator.pop(context); // Close loading

                        // Now show notifications
                        showDialog(
                          context: context,
                          builder: (context) => NotificationDialog(),
                        ).then((_) {
                          // Refresh data when returning from notifications
                          _loadData();
                        });
                      } catch (e) {
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error loading notifications: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      // Service is ready, show notifications directly
                      showDialog(
                        context: context,
                        builder: (context) => NotificationDialog(),
                      ).then((_) {
                        // Refresh data when returning from notifications
                        _loadData();
                      });
                    }
                  },
                ),
                if (count > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
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
                  const SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'Student',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userData?['email'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // In the _buildDrawer() method, replace the existing ListTile widgets with this updated version:

            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCalendar(); // Navigate to calendar page
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('My Report'),
              onTap: () {
                Navigator.pop(context);
                _navigateToReport(); // Navigate to report page
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to settings page
              },
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Organization'),
              subtitle: Text(_organizationData?['name'] ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Organization Code'),
              subtitle: Text(_organizationData?['code'] ?? ''),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${_userData?['fullName']?.split(' ').first ?? 'Student'}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have ${_enrolledCourses.length} enrolled course${_enrolledCourses.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Goal System Quick Access Card - ONLY FOR STUDENTS
          if (_isStudent && (_waterBuckets > 0 || _pendingAssignments > 0))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _navigateToGoalSystem,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Icon(Icons.local_florist, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Tree Garden',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _waterBuckets > 0
                                ? 'You have $_waterBuckets water bucket${_waterBuckets == 1 ? '' : 's'} ready!'
                                : 'Complete assignments to earn water buckets!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_waterBuckets > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[600],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_drink, size: 18, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '$_waterBuckets',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Courses Section
          const Text(
            'Your Courses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Courses List
          if (_enrolledCourses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
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
                  const SizedBox(height: 16),
                  Text(
                    'No courses enrolled yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
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

          // Extra space at bottom
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
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
          ).then((_) {
            // Reload data when returning from course page
            _loadData();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.all(8),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? 'Untitled Course',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            course['lecturerName'] ?? 'Unknown Lecturer',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.school_outlined, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
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
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
        }

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
          // Navigate to chat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatContactPage(),
              ),
            );
            break;
          case 3:
          // Navigate to Goal System (only for students)
            if (_isStudent) {
              _navigateToGoalSystem();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🌱 Goal system is only available for students'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            break;
          case 4:
          // Navigate to profile
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
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
          icon: Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(Icons.local_florist),
              if (_isStudent && _waterBuckets > 0)
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_waterBuckets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          label: 'Goals',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }
}