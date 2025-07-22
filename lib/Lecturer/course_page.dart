import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import 'create_assignment.dart';
import 'assignment_details.dart';
import 'create_material.dart';
import 'material_details.dart';

class CoursePage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const CoursePage({
    Key? key,
    required this.courseId,
    required this.courseData,
  }) : super(key: key);

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Data
  String? _organizationCode;
  String? _lecturerFacultyId;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> enrolledStudents = [];
  List<Map<String, dynamic>> facultyStudents = [];

  bool isLoading = true;
  String? errorMessage;
  bool showCreateOptions = false;
  bool isLecturer = false;
  int _currentIndex = 2; // Lecturer tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update FAB visibility
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => errorMessage = 'User not authenticated');
        return;
      }

      // Load user data
      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        setState(() => errorMessage = 'User data not found');
        return;
      }

      if (mounted) {
        setState(() {
          _organizationCode = userData['organizationCode'];
          _lecturerFacultyId = userData['facultyId'];
          isLecturer = userData['role'] == 'lecturer' && widget.courseData['lecturerId'] == user.uid;
        });
      }

      // Load course content
      await Future.wait([
        _fetchAssignments(),
        _fetchMaterials(),
        _fetchEnrolledStudents(),
        if (isLecturer) _fetchFacultyStudents(),
      ]);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading data: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAssignments() async {
    if (_organizationCode == null) return;

    try {
      var assignmentQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          assignments = assignmentQuery.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching assignments: $e');
    }
  }

  Future<void> _fetchMaterials() async {
    if (_organizationCode == null) return;

    try {
      var materialQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          materials = materialQuery.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching materials: $e');
    }
  }

  Future<void> _fetchEnrolledStudents() async {
    if (_organizationCode == null) return;

    try {
      var enrollmentQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in enrollmentQuery.docs) {
        String studentId = doc.data()['studentId'];
        var studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          students.add({
            'id': studentId,
            'fullName': studentDoc.data()?['fullName'] ?? 'Unknown Student',
            'email': studentDoc.data()?['email'] ?? 'No email',
            'facultyName': studentDoc.data()?['facultyName'] ?? studentDoc.data()?['faculty'] ?? '',
            'enrolledAt': doc.data()['enrolledAt'],
          });
        }
      }

      if (mounted) {
        setState(() {
          enrolledStudents = students;
        });
      }
    } catch (e) {
      print('Error fetching enrolled students: $e');
    }
  }

  Future<void> _fetchFacultyStudents() async {
    if (_organizationCode == null || _lecturerFacultyId == null) return;

    try {
      var studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('organizationCode', isEqualTo: _organizationCode)
          .where('role', isEqualTo: 'student')
          .where('facultyId', isEqualTo: _lecturerFacultyId)
          .where('isActive', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          facultyStudents = studentsQuery.docs.map((doc) {
            return {
              'id': doc.id,
              'fullName': doc.data()['fullName'] ?? 'Unknown Student',
              'email': doc.data()['email'] ?? 'No email',
              'studentId': doc.data()['studentId'] ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching faculty students: $e');
    }
  }

  void _showCreateDialog() {
    setState(() {
      showCreateOptions = !showCreateOptions;
    });
  }

  // ✅ UPDATED: Added notification creation for assignments
  void _navigateToCreateAssignment() async {
    setState(() {
      showCreateOptions = false;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAssignmentPage(
          courseId: widget.courseId,
          courseData: {
            ...widget.courseData,
            'organizationCode': _organizationCode,
          },
        ),
      ),
    );

    if (result == true && mounted) {
      _fetchAssignments();

      // ✅ NEW: Create notifications for students when new assignment is added
      _scheduleNotificationCreation('assignment');
    }
  }

  // ✅ UPDATED: Added notification creation for materials
  void _navigateToCreateMaterial() async {
    setState(() {
      showCreateOptions = false;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaterialPage(
          courseId: widget.courseId,
          courseData: {
            ...widget.courseData,
            'organizationCode': _organizationCode,
          },
        ),
      ),
    );

    if (result == true && mounted) {
      _fetchMaterials();

      // ✅ NEW: Create notifications for students when new material is added
      _scheduleNotificationCreation('material');
    }
  }

  // ✅ NEW: Schedule notification creation after content is added
  void _scheduleNotificationCreation(String contentType) {
    // Wait a bit for the new content to be saved, then check for new items
    Future.delayed(Duration(seconds: 2), () {
      _checkForNewContentAndNotify(contentType);
    });
  }

  // ✅ NEW: Check for newly added content and create notifications
  Future<void> _checkForNewContentAndNotify(String contentType) async {
    try {
      if (_organizationCode == null) return;

      print('🔍 Checking for new $contentType to send notifications...');

      if (contentType == 'assignment') {
        // Get the most recent assignment
        final recentAssignments = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (recentAssignments.docs.isNotEmpty) {
          final assignment = recentAssignments.docs.first;
          final assignmentData = assignment.data();

          // Check if this assignment was created in the last 30 seconds (likely just created)
          final createdAt = assignmentData['createdAt'] as Timestamp?;
          if (createdAt != null &&
              DateTime.now().difference(createdAt.toDate()).inSeconds < 30) {

            await _createStudentNotifications(
              itemType: 'assignment',
              itemTitle: assignmentData['title'] ?? 'Assignment',
              sourceId: assignment.id,
              courseId: widget.courseId,
              dueDate: assignmentData['dueDate'] as Timestamp?,
            );
          }
        }
      } else if (contentType == 'material') {
        // Get the most recent material
        final recentMaterials = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (recentMaterials.docs.isNotEmpty) {
          final material = recentMaterials.docs.first;
          final materialData = material.data();

          // Check if this material was created in the last 30 seconds (likely just created)
          final createdAt = materialData['createdAt'] as Timestamp?;
          if (createdAt != null &&
              DateTime.now().difference(createdAt.toDate()).inSeconds < 30) {

            await _createStudentNotifications(
              itemType: 'material',
              itemTitle: materialData['title'] ?? 'Material',
              sourceId: material.id,
              courseId: widget.courseId,
              dueDate: null,
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error checking for new content: $e');
    }
  }

  // ✅ NEW: Create notifications for all enrolled students
  Future<void> _createStudentNotifications({
    required String itemType,
    required String itemTitle,
    required String sourceId,
    required String courseId,
    Timestamp? dueDate,
  }) async {
    try {
      print('📢 Creating notifications for $itemType: $itemTitle');

      // Get current lecturer name
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final lecturerData = await _authService.getUserData(currentUser.uid);
      final lecturerName = lecturerData?['fullName'] ?? 'Your lecturer';
      final courseName = widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course';

      int notificationsCreated = 0;

      // Create notifications for each enrolled student
      for (final student in enrolledStudents) {
        try {
          String title = itemType == 'assignment' ?
          '📝 New Assignment: $itemTitle' :
          '📚 New Material: $itemTitle';

          String body = itemType == 'assignment' ?
          '$lecturerName has posted a new assignment in $courseName' :
          '$lecturerName has shared new material in $courseName';

          if (dueDate != null && itemType == 'assignment') {
            final dueDateStr = _formatDate(dueDate);
            body += ' (Due: $dueDateStr)';
          }

          await FirebaseFirestore.instance
              .collection('organizations')
              .doc(_organizationCode)
              .collection('students')
              .doc(student['id'])
              .collection('notifications')
              .add({
            'title': title,
            'body': body,
            'type': itemType,
            'sourceType': 'course',
            'sourceId': sourceId,
            'courseId': courseId,
            'courseName': courseName,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'createdBy': currentUser.uid,
            'lecturerName': lecturerName,
            if (dueDate != null) 'dueDate': dueDate,
          });

          notificationsCreated++;
        } catch (e) {
          print('❌ Error creating notification for student ${student['id']}: $e');
        }
      }

      print('✅ Successfully created $notificationsCreated notifications for $itemType');

      if (mounted && notificationsCreated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📢 Notifications sent to $notificationsCreated students'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating student notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error sending notifications: ${e.toString()}'),
            backgroundColor: Colors.orange[600],
          ),
        );
      }
    }
  }

  void _navigateToAssignmentDetail(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(
          assignment: assignment,
          courseId: widget.courseId,
          courseData: widget.courseData,
          isLecturer: isLecturer,
        ),
      ),
    );
  }

  void _navigateToMaterialDetail(Map<String, dynamic> material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialDetailPage(
          material: material,
          courseId: widget.courseId,
          courseData: widget.courseData,
          isLecturer: isLecturer,
        ),
      ),
    );
  }

  void _showEnrollStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 600,
          height: 600,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enroll Students',
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

              // Tab selector
              DefaultTabController(
                length: 2,
                child: Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: Colors.purple[400],
                        labelColor: Colors.purple[600],
                        unselectedLabelColor: Colors.grey[600],
                        tabs: [
                          Tab(text: 'Faculty Students'),
                          Tab(text: 'Manual Entry'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Faculty Students Tab
                            _buildFacultyStudentsTab(),
                            // Manual Entry Tab
                            _buildManualEntryTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Reload enrolled students after dialog closes
      if (mounted) {
        _fetchEnrolledStudents();
      }
    });
  }

  Widget _buildFacultyStudentsTab() {
    // Filter out already enrolled students
    final enrolledStudentIds = enrolledStudents.map((s) => s['id']).toSet();
    final availableStudents = facultyStudents.where((student) =>
    !enrolledStudentIds.contains(student['id'])
    ).toList();

    if (availableStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No available students from your faculty',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              'All students might already be enrolled',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Select students from your faculty to enroll',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: availableStudents.length,
            itemBuilder: (context, index) {
              final student = availableStudents[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Text(
                      (student['fullName'] ?? 'S').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.purple[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(student['fullName'] ?? 'Unknown Student'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['email'] ?? 'No email'),
                      if (student['studentId'].toString().isNotEmpty)
                        Text(
                          'ID: ${student['studentId']}',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _enrollStudent(student['id'], student['fullName']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Enroll', style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryTab() {
    final emailController = TextEditingController();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Enter student email address to enroll',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: 'Student Email',
              hintText: 'student@example.com',
              prefixIcon: Icon(Icons.email, color: Colors.purple[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                String email = emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter student email')),
                  );
                  return;
                }

                try {
                  // Find student by email
                  var studentQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .where('role', isEqualTo: 'student')
                      .where('organizationCode', isEqualTo: _organizationCode)
                      .get();

                  if (studentQuery.docs.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Student not found in your organization')),
                      );
                    }
                    return;
                  }

                  String studentId = studentQuery.docs.first.id;
                  String studentName = studentQuery.docs.first.data()['fullName'] ?? 'Unknown';

                  await _enrollStudent(studentId, studentName);
                  emailController.clear();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[400],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Enroll Student', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enrollStudent(String studentId, String studentName) async {
    try {
      // Check if already enrolled
      var existingEnrollment = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (existingEnrollment.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$studentName is already enrolled in this course')),
          );
        }
        return;
      }

      // Enroll student
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .add({
        'studentId': studentId,
        'enrolledAt': FieldValue.serverTimestamp(),
        'enrolledBy': _authService.currentUser!.uid,
      });

      // Update enrolled count
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .update({
        'enrolledCount': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$studentName enrolled successfully'),
            backgroundColor: Colors.green[600],
          ),
        );
      }

      // Refresh enrolled students
      _fetchEnrolledStudents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enrolling student: ${e.toString()}')),
        );
      }
    }
  }

  void _removeStudent(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Remove Student'),
        content: Text('Are you sure you want to remove $studentName from this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Remove from course enrollments
                var enrollmentQuery = await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(_organizationCode)
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('enrollments')
                    .where('studentId', isEqualTo: studentId)
                    .get();

                for (var doc in enrollmentQuery.docs) {
                  await doc.reference.delete();
                }

                // Update enrolled count
                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(_organizationCode)
                    .collection('courses')
                    .doc(widget.courseId)
                    .update({
                  'enrolledCount': FieldValue.increment(-1),
                });

                if (mounted) {
                  Navigator.pop(context);
                  _fetchEnrolledStudents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Student removed successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error removing student: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
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
                errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
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
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Course Header
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
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
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.courseData['code'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (widget.courseData['courseTemplateId'] != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Lecturer Template',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  widget.courseData['title'] ?? widget.courseData['name'] ?? 'Lecturer Title',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.courseData['description'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Text(
                      widget.courseData['lecturerName'] ?? 'Unknown Lecturer',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(width: 24),
                    Icon(Icons.people, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '${enrolledStudents.length} students',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
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
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.purple[400],
              indicatorWeight: 3,
              labelColor: Colors.purple[600],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Content'),
                Tab(text: 'Students'),
                Tab(text: 'Overview'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(),
                _buildStudentsTab(),
                _buildOverviewTab(),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button with Speed Dial
      floatingActionButton: isLecturer && _tabController.index == 0
          ? _buildFloatingActionButton()
          : null,
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
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
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

  // New FAB widgets with speed dial
  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial options
        if (showCreateOptions) ...[
          // Material FAB
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Material',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: "material",
                  onPressed: () {
                    setState(() {
                      showCreateOptions = false;
                    });
                    _navigateToCreateMaterial();
                  },
                  backgroundColor: Colors.green,
                  elevation: 4,
                  child: Icon(Icons.description, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          // Assignment FAB
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Assignment',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: "assignment",
                  onPressed: () {
                    setState(() {
                      showCreateOptions = false;
                    });
                    _navigateToCreateAssignment();
                  },
                  backgroundColor: Colors.orange,
                  elevation: 4,
                  child: Icon(Icons.assignment, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
        // Main FAB
        FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          backgroundColor: Colors.purple[400],
          elevation: 6,
          icon: AnimatedRotation(
            turns: showCreateOptions ? 0.125 : 0,
            duration: Duration(milliseconds: 200),
            child: Icon(
              showCreateOptions ? Icons.close : Icons.add,
              color: Colors.white,
            ),
          ),
          label: Text(
            'Create',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildContentTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchAssignments(),
          _fetchMaterials(),
        ]);
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Assignments Section
            if (assignments.isNotEmpty) ...[
              _buildSectionHeader('Assignments', Icons.assignment),
              ...assignments.map((assignment) => _buildContentCard(
                title: assignment['title'] ?? 'Assignment',
                subtitle: assignment['description'] ?? 'No description',
                date: _formatDate(assignment['createdAt']),
                icon: Icons.assignment,
                color: Colors.orange,
                onTap: () => _navigateToAssignmentDetail(assignment),
                onDelete: isLecturer ? () => _deleteAssignment(assignment) : null,
              )),
              SizedBox(height: 24),
            ],

            // Materials Section
            if (materials.isNotEmpty) ...[
              _buildSectionHeader('Materials', Icons.description),
              ...materials.map((material) => _buildContentCard(
                title: material['title'] ?? 'Material',
                subtitle: material['description'] ?? 'No description',
                date: _formatDate(material['createdAt']),
                icon: Icons.description,
                color: Colors.green,
                onTap: () => _navigateToMaterialDetail(material),
                onDelete: isLecturer ? () => _deleteMaterial(material) : null,
              )),
            ],

            // Empty state
            if (assignments.isEmpty && materials.isEmpty)
              Container(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      isLecturer
                          ? 'No content yet.\nTap the Create button to add assignments or materials.'
                          : 'No content available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 100), // Space for floating button
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple[400], size: 24),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required String subtitle,
    required String date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 28),
                ),
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
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLecturer && onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        if (isLecturer)
          Padding(
            padding: EdgeInsets.all(16),
            child: CustomButton(
              text: 'Enroll Students',
              onPressed: _showEnrollStudentDialog,
            ),
          ),
        Expanded(
          child: enrolledStudents.isEmpty
              ? Center(
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
                  isLecturer
                      ? 'No students enrolled yet.\nTap "Enroll Students" to add students.'
                      : 'No students enrolled in this course yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _fetchEnrolledStudents,
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: enrolledStudents.length,
              itemBuilder: (context, index) {
                return _buildStudentCard(enrolledStudents[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.purple[100],
          child: Text(
            (student['fullName'] ?? 'S').substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Colors.purple[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student['fullName'] ?? 'Unknown Student',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student['email'] ?? 'No email',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (student['facultyName'] != null && student['facultyName'].toString().isNotEmpty)
              Text(
                'Faculty: ${student['facultyName']}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            SizedBox(height: 4),
            Text(
              'Enrolled: ${_formatDate(student['enrolledAt'])}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isLecturer
            ? IconButton(
          icon: Icon(Icons.remove_circle_outline, color: Colors.red[400]),
          onPressed: () => _removeStudent(
            student['id'],
            student['fullName'] ?? 'Unknown Student',
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Students',
                  enrolledStudents.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Assignments',
                  assignments.length.toString(),
                  Icons.assignment,
                  Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Materials',
                  materials.length.toString(),
                  Icons.description,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Content',
                  (assignments.length + materials.length).toString(),
                  Icons.library_books,
                  Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Course Details
          Container(
            padding: EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lecturer Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Code', widget.courseData['code'] ?? 'N/A'),
                if (widget.courseData['courseTemplateId'] != null)
                  _buildDetailRow('Lecturer Template', widget.courseData['courseTemplateName'] ?? 'N/A'),
                if (widget.courseData['baseCourseId'] != null)
                  _buildDetailRow('Base Lecturer', widget.courseData['baseCourseName'] ?? 'N/A'),
                _buildDetailRow('Faculty', widget.courseData['facultyName'] ?? 'N/A'),
                _buildDetailRow('Lecturer', widget.courseData['lecturerName'] ?? 'N/A'),
                _buildDetailRow('Created', _formatDate(widget.courseData['createdAt'])),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          ...(_getRecentActivity().map((item) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  item['type'] == 'assignment' ? Icons.assignment : Icons.description,
                  color: Colors.purple[400],
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(item['createdAt']),
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
          ))),

          if (assignments.isEmpty && materials.isEmpty)
            Container(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No activity yet. Start by creating assignments or materials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
          // TODO: Navigate to courses
            Navigator.pop(context);
            break;
          case 1:
          // TODO: Navigate to community
            break;
          case 2:
          // Already on course page
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

  List<Map<String, dynamic>> _getRecentActivity() {
    List<Map<String, dynamic>> recentItems = [];

    // Add assignments
    for (var assignment in assignments) {
      recentItems.add({
        'title': assignment['title'] ?? 'Assignment',
        'type': 'assignment',
        'createdAt': assignment['createdAt'],
      });
    }

    // Add materials
    for (var material in materials) {
      recentItems.add({
        'title': material['title'] ?? 'Material',
        'type': 'material',
        'createdAt': material['createdAt'],
      });
    }

    // Sort by creation date (most recent first)
    recentItems.sort((a, b) {
      if (a['createdAt'] == null && b['createdAt'] == null) return 0;
      if (a['createdAt'] == null) return 1;
      if (b['createdAt'] == null) return -1;

      DateTime dateA = a['createdAt'] is Timestamp
          ? (a['createdAt'] as Timestamp).toDate()
          : a['createdAt'] as DateTime;
      DateTime dateB = b['createdAt'] is Timestamp
          ? (b['createdAt'] as Timestamp).toDate()
          : b['createdAt'] as DateTime;

      return dateB.compareTo(dateA);
    });

    // Return only the most recent 5 items
    return recentItems.take(5).toList();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'N/A';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _deleteAssignment(Map<String, dynamic> assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Assignment'),
        content: Text('Are you sure you want to delete this assignment?'),
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
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .delete();

        _fetchAssignments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assignment deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting assignment: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Material'),
        content: Text('Are you sure you want to delete this material?'),
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
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(material['id'])
            .delete();

        _fetchMaterials();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting material: $e')),
          );
        }
      }
    }
  }
}