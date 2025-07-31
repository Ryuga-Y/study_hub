import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_hub/Student/student_quiz.dart';
import 'package:study_hub/Student/student_tutorial.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../community/bloc.dart';
import '../community/feed_screen.dart';
import '../community/models.dart';
import '../profile_page.dart';
import 'student_assignment_details.dart';
import '../goal_progress_service.dart';
import '../Stu_goal.dart';
import '../chat_integrated.dart';
import '../notification.dart';

// Add these enums for calendar event types
enum EventType { normal, recurring }
enum RecurrenceType { none, daily, weekly, monthly }
enum CalendarView { month, week, day }

class StudentCoursePage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final String? highlightMaterialId;

  const StudentCoursePage({
    Key? key,
    required this.courseId,
    required this.courseData,
    this.highlightMaterialId,
  }) : super(key: key);

  @override
  _StudentCoursePageState createState() => _StudentCoursePageState();
}

class _StudentCoursePageState extends State<StudentCoursePage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final GoalProgressService _goalService = GoalProgressService();
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;

  // Add these as class variables for real-time listeners
  StreamSubscription<QuerySnapshot>? _assignmentsSubscription;
  StreamSubscription<QuerySnapshot>? _materialsSubscription;

  // Data
  String? _organizationCode;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  Map<String, Map<String, dynamic>> submissions = {};
  Map<String, Map<String, dynamic>> tutorialSubmissions = {};
  List<Map<String, dynamic>> classmates = [];

  bool isLoading = true;
  String? errorMessage;
  int _currentIndex = 0;

  // Calendar view state (if needed)
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  CalendarView _currentView = CalendarView.month;

  // Auto-open tutorial modal for highlighted material
  void _autoOpenTutorialModal() {
    final material = materials.firstWhere(
          (m) => m['id'] == widget.highlightMaterialId,
      orElse: () => <String, dynamic>{},
    );

    if (material.isNotEmpty && material['materialType'] == 'tutorial') {
      // Small delay to ensure the UI is ready
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _viewMaterial(material);
        }
      });
    }
  }

  // FIXED: Update the initState method in student_course.dart
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize notification service immediately
    _notificationService.initialize();

    _loadData().then((_) {
      // Auto-open tutorial modal if highlightMaterialId is provided
      if (widget.highlightMaterialId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoOpenTutorialModal();
        });
      }
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    _assignmentsSubscription?.cancel();
    _materialsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => errorMessage = 'User not authenticated');
        return;
      }

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        setState(() => errorMessage = 'User data not found');
        return;
      }

      setState(() {
        _organizationCode = userData['organizationCode'];
      });

      // Fetch assignments, materials, and submissions
      await Future.wait([
        _fetchAssignments(),
        _fetchMaterials(),
      ]);

      print('✅ Loaded ${assignments.length} assignments and ${materials.length} materials');

      // Fetch submissions (which depend on assignments and materials being loaded)
      await Future.wait([
        _fetchSubmissions(user.uid),
        _fetchTutorialSubmissions(user.uid),
        _fetchClassmates(user.uid),
      ]);

      // Start real-time listeners after initial data load
      _startRealtimeListeners();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  // AFTER: Replace the _startRealtimeListeners method in student_course.dart
  void _startRealtimeListeners() {
    if (_organizationCode == null) return;

    // Listen for new assignments with enhanced notification creation
    _assignmentsSubscription = FirebaseFirestore.instance
        .collection('organizations')
        .doc(_organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      // Check for new assignments
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final assignmentData = change.doc.data() as Map<String, dynamic>;
          final assignmentId = change.doc.id;

          // Check if this is a new assignment (not initial load)
          final isNew = assignments.where((a) => a['id'] == assignmentId).isEmpty;

          if (isNew) {
            // Show notification for new assignment
            _showNewItemNotification('assignment', assignmentData['title'] ?? 'Assignment');

            // ✅ ENHANCED: Create notification with complete navigation data
            await _createEnhancedFirestoreNotification(
              type: 'assignment',
              title: assignmentData['title'] ?? 'Assignment',
              sourceId: assignmentId,
              courseId: widget.courseId,
              courseName: widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course',
              orgCode: _organizationCode!,
              dueDate: assignmentData['dueDate'] as Timestamp?,
            );

            // Create calendar event for the new assignment
            if (assignmentData['dueDate'] != null) {
              await _createCalendarEvent(
                title: assignmentData['title'] ?? 'Assignment',
                dueDate: (assignmentData['dueDate'] as Timestamp).toDate(),
                type: 'assignment',
                sourceId: assignmentId,
                courseId: widget.courseId,
              );
            }
          }
        }
      }

      // Update assignments list
      setState(() {
        assignments = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    });

    // Listen for new tutorials with enhanced notification creation
    _materialsSubscription = FirebaseFirestore.instance
        .collection('organizations')
        .doc(_organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('materials')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      // Check for new tutorials
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final materialData = change.doc.data() as Map<String, dynamic>;
          final materialId = change.doc.id;

          // Check if this is a new tutorial (not initial load)
          final isNew = materials.where((m) => m['id'] == materialId).isEmpty;

          if (isNew && (materialData['materialType'] == 'tutorial' || materialData['materialType'] == 'quiz')) {
            final itemType = materialData['materialType'] == 'quiz' ? 'quiz' : 'tutorial';
            final itemTitle = materialData['title'] ?? (materialData['materialType'] == 'quiz' ? 'Quiz' : 'Tutorial');

            // Show notification for new tutorial/quiz
            _showNewItemNotification(itemType, itemTitle);

            // ✅ ENHANCED: Create notification with complete navigation data
            await _createEnhancedFirestoreNotification(
              type: itemType,
              title: itemTitle,
              sourceId: materialId,
              courseId: widget.courseId,
              courseName: widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course',
              orgCode: _organizationCode!,
              dueDate: materialData['dueDate'] as Timestamp?,
            );

            // Create calendar event for the new tutorial
            if (materialData['dueDate'] != null) {
              await _createCalendarEvent(
                title: materialData['title'] ?? 'Tutorial',
                dueDate: (materialData['dueDate'] as Timestamp).toDate(),
                type: 'tutorial',
                sourceId: materialId,
                courseId: widget.courseId,
              );
            }
          }
        }
      }

      // Update materials list
      setState(() {
        materials = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    });
  }

// ✅ ENHANCED: Complete notification creation method (FIXED - Only one version)
  Future<void> _createEnhancedFirestoreNotification({
    required String type,
    required String title,
    required String sourceId,
    required String courseId,
    required String courseName,
    required String orgCode,
    Timestamp? dueDate,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Get all enrolled students for this course
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgCode)
          .collection('courses')
          .doc(courseId)
          .collection('enrollments')
          .get();

      print('✅ Creating notifications for ${enrollmentsSnapshot.docs.length} students');

      // Create notification for each enrolled student
      for (var enrollment in enrollmentsSnapshot.docs) {
        final studentId = enrollment.data()['studentId'];

        // Skip if it's the lecturer who created the content
        if (studentId == user.uid) continue;

        // Create comprehensive notification data
        final notificationData = {
          'title': type == 'assignment' ? '📝 New Assignment: $title' :
          type == 'tutorial' ? '📚 New Tutorial: $title' :
          type == 'quiz' ? '🧠 New Quiz: $title' : '📖 New Material: $title',
          'body': '$title has been posted in $courseName',
          'type': 'NotificationType.$type',
          'sourceId': sourceId,
          'sourceType': type,
          'courseId': courseId,                  // ✅ CRITICAL for navigation
          'courseName': courseName,
          'organizationCode': orgCode,           // ✅ CRITICAL for navigation
          'itemTitle': title,                    // ✅ ENHANCED for display
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          // ✅ ENHANCED: Complete navigation helpers
          'navigationData': {
            'sourceId': sourceId,
            'courseId': courseId,
            'orgCode': orgCode,
            'type': type,
            'title': title,
            'courseName': courseName,
          },
        };

        // Add due date if available
        if (dueDate != null) {
          notificationData['dueDate'] = dueDate;
        }

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgCode)
            .collection('students')
            .doc(studentId)
            .collection('notifications')
            .add(notificationData);

        print('✅ Created notification for student: $studentId');
      }
    } catch (e) {
      print('❌ Error creating enhanced notification: $e');
    }
  }

  // Calendar event creation function
  Future<void> _createCalendarEvent({
    required String title,
    required DateTime dueDate,
    required String type,
    required String sourceId,
    required String courseId,
  }) async {
    try {
      if (_organizationCode == null) return;

      // For items due at 11:59 PM, create a 1-minute duration event
      final startTime = dueDate;
      final endTime = startTime.add(Duration(minutes: 1));

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('students')
          .doc(_authService.currentUser!.uid)
          .collection('calendar_events')
          .add({
        'title': type == 'assignment' ? '📝 Assignment: $title' : '📖 Tutorial: $title',
        'description': '$type deadline',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'color': type == 'assignment' ? Colors.red.toARGB32() : Colors.red.toARGB32(),
        'calendar': type == 'assignment' ? 'assignments' : 'tutorials',
        'eventType': 0, // EventType.normal
        'recurrenceType': 0, // RecurrenceType.none
        'reminderMinutes': 60,
        'location': '',
        'isRecurring': false,
        'originalEventId': '',
        'sourceId': sourceId,
        'sourceType': type,
        'courseId': courseId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created calendar event for $type: $title');
    } catch (e) {
      print('Error creating calendar event: $e');
    }
  }

  // Show notification for new items
  void _showNewItemNotification(String type, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              type == 'assignment' ? Icons.assignment : Icons.quiz,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'New $type added: $title',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: type == 'assignment' ? Colors.orange : Colors.blue,
        duration: Duration(seconds: 4),
      ),
    );
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

      setState(() {
        assignments = assignmentQuery.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
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

      setState(() {
        materials = materialQuery.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching materials: $e');
    }
  }

  Future<void> _fetchSubmissions(String studentId) async {
    if (_organizationCode == null) return;

    try {
      Map<String, Map<String, dynamic>> submissionMap = {};

      for (var assignment in assignments) {
        var submissionQuery = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();

        if (submissionQuery.docs.isNotEmpty) {
          submissionMap[assignment['id']] = {
            'id': submissionQuery.docs.first.id,
            ...submissionQuery.docs.first.data(),
          };
        }
      }

      setState(() {
        submissions = submissionMap;
      });
    } catch (e) {
      print('Error fetching submissions: $e');
    }
  }

  Future<void> _fetchTutorialSubmissions(String studentId) async {
    if (_organizationCode == null) return;

    try {
      Map<String, Map<String, dynamic>> tutorialMap = {};

      // Debug: Log the number of materials
      print('📚 Total materials: ${materials.length}');

      for (var material in materials) {
        if (material['materialType'] == 'tutorial') {
          // Debug: Log tutorial material info
          print('🔍 Checking tutorial: ${material['title']} (ID: ${material['id']})');

          var submissionQuery = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(_organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('materials')
              .doc(material['id'])
              .collection('submissions')
              .where('studentId', isEqualTo: studentId)
              .orderBy('submittedAt', descending: true)
              .limit(1)
              .get();

          if (submissionQuery.docs.isNotEmpty) {
            // Debug: Log found submission
            print('✅ Found submission for tutorial: ${material['title']}');

            tutorialMap[material['id']] = {
              'id': submissionQuery.docs.first.id,
              ...submissionQuery.docs.first.data(),
            };
          } else {
            // Debug: Log no submission found
            print('❌ No submission found for tutorial: ${material['title']}');
          }
        }
      }

      // Debug: Log final tutorial submissions
      print('📊 Total tutorial submissions found: ${tutorialMap.length}');

      setState(() {
        tutorialSubmissions = tutorialMap;
      });
    } catch (e) {
      print('Error fetching tutorial submissions: $e');
    }
  }

  Future<void> _fetchClassmates(String currentStudentId) async {
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
        if (studentId != currentStudentId) {
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
            });
          }
        }
      }

      setState(() {
        classmates = students;
      });
    } catch (e) {
      print('Error fetching classmates: $e');
    }
  }

  // 🎯 ENHANCED ASSIGNMENT SUBMISSION with existing submission check
  Future<void> _submitAssignment(Map<String, dynamic> assignment) async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Check if already submitted
    final existingSubmission = submissions[assignment['id']];
    if (existingSubmission != null) {
      // Check if it's been graded
      if (existingSubmission['grade'] != null) {
        // Show "already graded" message (existing code)
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('Submission Not Allowed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This assignment has already been graded.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.grade, color: Colors.green[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grade: ${existingSubmission['grade']}/${assignment['points'] ?? 100}',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (existingSubmission['letterGrade'] != null)
                              Text(
                                'Letter Grade: ${existingSubmission['letterGrade']}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'No further submissions are allowed once an assignment has been graded.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      // Show dialog asking if they want to update their submission
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update Submission?'),
          content: Text('You have already submitted this assignment. Do you want to update your submission?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Update'),
            ),
          ],
        ),
      );

      if (shouldUpdate != true) return;

      // Navigate to assignment details page for resubmission
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentAssignmentDetailsPage(
            assignment: assignment,
            courseId: widget.courseId,
            courseData: widget.courseData,
            organizationCode: _organizationCode!,
          ),
        ),
      ).then((_) => _loadData());
      return;
    }

    // Check due date
    final dueDate = assignment['dueDate'] as Timestamp?;
    if (dueDate != null && dueDate.toDate().isBefore(DateTime.now())) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Past Due Date'),
          content: Text('This assignment is past due. Do you still want to submit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Submit Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        // Check file size
        if (result.files.single.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size exceeds 10MB limit'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Show upload progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                ),
                SizedBox(width: 20),
                Expanded(child: Text('Submitting assignment...')),
              ],
            ),
          ),
        );

        final userData = await _authService.getUserData(user.uid);
        final studentName = userData?['fullName'] ?? 'Unknown Student';

        // Upload file to Firebase Storage
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final storagePath = 'submissions/${widget.courseId}/${assignment['id']}/$fileName';

        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: _getContentType(result.files.single.extension ?? ''),
          customMetadata: {
            'studentId': user.uid,
            'studentName': studentName,
            'assignmentId': assignment['id'],
            'originalName': result.files.single.name,
          },
        );

        final uploadTask = ref.putData(result.files.single.bytes!, metadata);
        final snapshot = await uploadTask;
        final fileUrl = await snapshot.ref.getDownloadURL();

        // Create submission document in Firestore
        final submissionRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .add({
          'studentId': user.uid,
          'studentName': studentName,
          'studentEmail': userData?['email'] ?? '',
          'submittedAt': FieldValue.serverTimestamp(),
          'fileUrl': fileUrl,
          'fileName': result.files.single.name,
          'fileSize': result.files.single.size,
          'storagePath': storagePath,
          'status': 'submitted',
          'grade': null,
          'feedback': null,
          'isLate': dueDate != null && DateTime.now().isAfter(dueDate.toDate()),
        });

        // 🎯 AWARD WATER BUCKETS: 4 buckets for assignment submission (only for NEW submissions)
        try {
          await _goalService.awardAssignmentSubmission(
              submissionRef.id,
              assignment['id'],
              assignmentName: assignment['title'] ?? 'Assignment'
          );
          print('✅ Awarded 4 water buckets for assignment: ${assignment['title']}');
        } catch (e) {
          print('❌ Error awarding water buckets: $e');
          // Don't fail the submission if reward fails
        }

        // Close loading dialog
        Navigator.pop(context);

        // Refresh submissions data
        await _fetchSubmissions(user.uid);

        // Show success message with water bucket reward
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Assignment submitted successfully!')),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_drink, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('+4', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🎯 ENHANCED TUTORIAL SUBMISSION with existing submission check
  Future<void> _submitTutorial(Map<String, dynamic> material) async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Check if already submitted
    final existingSubmission = tutorialSubmissions[material['id']];
    if (existingSubmission != null) {
      // Tutorial already submitted - show update dialog and continue with file picker
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update Tutorial Submission?'),
          content: Text('You have already submitted this tutorial. Do you want to update your submission?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Update'),
            ),
          ],
        ),
      );

      if (shouldUpdate != true) return;

      // Navigate to tutorial submission view for resubmission
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentTutorialSubmissionView(
            courseId: widget.courseId,
            materialId: material['id'],
            materialData: material,
            organizationCode: _organizationCode!,
          ),
        ),
      ).then((_) => _loadData());
      return;
    }

    final dueDate = material['dueDate'] as Timestamp?;
    if (dueDate != null && dueDate.toDate().isBefore(DateTime.now())) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Past Due Date'),
          content: Text('This tutorial is past due. Do you still want to submit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Submit Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Add comment dialog
    final commentController = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Comments (Optional)'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Any comments about your submission...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, commentController.text),
            child: Text('Continue'),
          ),
        ],
      ),
    );

    if (comment == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'zip', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                ),
                SizedBox(width: 20),
                Expanded(child: Text('Submitting tutorial...')),
              ],
            ),
          ),
        );

        final userData = await _authService.getUserData(user.uid);
        final studentName = userData?['fullName'] ?? 'Unknown Student';

        List<Map<String, dynamic>> uploadedFiles = [];

        for (var file in result.files) {
          if (file.bytes != null && file.size <= 10 * 1024 * 1024) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final storagePath = 'materials/${widget.courseId}/${material['id']}/submissions/$fileName';

            final ref = FirebaseStorage.instance.ref().child(storagePath);
            final metadata = SettableMetadata(
              contentType: _getContentType(file.extension ?? ''),
            );

            final uploadTask = ref.putData(file.bytes!, metadata);
            final snapshot = await uploadTask;
            final fileUrl = await snapshot.ref.getDownloadURL();

            uploadedFiles.add({
              'url': fileUrl,
              'name': file.name,
              'size': file.size,
              'uploadedAt': Timestamp.now(),
              'storagePath': storagePath,
            });
          }
        }

        final submissionRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('materials')
            .doc(material['id'])
            .collection('submissions')
            .add({
          'studentId': user.uid,
          'studentName': studentName,
          'studentEmail': userData?['email'] ?? '',
          'submittedAt': FieldValue.serverTimestamp(),
          'files': uploadedFiles,
          'comments': comment,
          'status': 'submitted',
          'isLate': dueDate != null && DateTime.now().isAfter(dueDate.toDate()),
          // ADD THESE THREE LINES:
          'materialId': material['id'],
          'courseId': widget.courseId,
          'organizationCode': _organizationCode,
        });

        // 🎯 AWARD WATER BUCKETS: 1 bucket for tutorial submission (only first submission gets reward)
        try {
          await _goalService.awardTutorialSubmission(
              submissionRef.id,
              material['id'],
              materialName: material['title'] ?? 'Tutorial'
          );
          print('✅ Awarded 1 water bucket for tutorial: ${material['title']}');
        } catch (e) {
          print('❌ Error awarding water buckets: $e');
          // Don't fail the submission if reward fails
        }

        Navigator.pop(context);

        await _fetchTutorialSubmissions(user.uid);

        // Show success message with water bucket reward
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Tutorial submitted successfully!')),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[600],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_drink, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('+1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting tutorial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewMaterial(Map<String, dynamic> material) {
    final files = material['files'] as List<dynamic>? ?? [];
    final materialType = material['materialType'] ?? 'learning';
    final dueDate = material['dueDate'] as Timestamp?;
    final isTutorial = materialType == 'tutorial';
    final isQuiz = materialType == 'quiz';

    // Handle quiz differently - navigate to quiz submission page
    if (isQuiz) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentQuizSubmissionPage(
            courseId: widget.courseId,
            quizId: material['id'],
            quizData: material,
            organizationCode: _organizationCode!,
          ),
        ),
      ).then((_) => _loadData());
      return;
    }

    // Rest of the existing _viewMaterial method for tutorials and learning materials...
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isTutorial ? Colors.blue[50] : Colors.green[50],
                    border: Border(
                      bottom: BorderSide(
                        color: isTutorial ? Colors.blue[200]! : Colors.green[200]!,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTutorial ? Icons.quiz : Icons.menu_book,
                        color: isTutorial ? Colors.blue[700] : Colors.green[700],
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material['title'] ?? 'Material',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isTutorial ? 'Tutorial' : 'Learning Material',
                                  style: TextStyle(
                                    color: isTutorial ? Colors.blue[600] : Colors.green[600],
                                    fontSize: 12,
                                  ),
                                ),
                                if (isTutorial && dueDate != null) ...[
                                  SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: Colors.grey)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Due: ${_formatDateTime(dueDate)}',
                                    style: TextStyle(
                                      color: dueDate.toDate().isBefore(DateTime.now())
                                          ? Colors.red[600]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: dueDate.toDate().isBefore(DateTime.now())
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey[700], size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                material['description'] ?? 'No description provided',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Tutorial reward info
                        if (isTutorial) ...[
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_drink, color: Colors.orange[600], size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Submit this tutorial to earn 1 water bucket for your tree!',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (files.isNotEmpty) ...[
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.attach_file, color: Colors.purple[600], size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Files (${files.length})',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ...files.map((file) {
                            final fileName = file['name'] ?? 'Unknown file';
                            final fileSize = file['size'] ?? 0;
                            final fileUrl = file['url'] ?? '';

                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getFileIcon(fileName),
                                    color: Colors.purple[600],
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _formatFileSize(fileSize),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.download, color: Colors.purple[600]),
                                  onPressed: () => _downloadFile(fileUrl, fileName),
                                ),
                                onTap: () => _downloadFile(fileUrl, fileName),
                              ),
                            );
                          }).toList(),
                        ] else ...[
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.folder_open,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No files attached',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text(
                                'By ${widget.courseData['lecturerName'] ?? 'Lecturer'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                _formatDate(material['createdAt']),
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
                ),

                if (isTutorial)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: FutureBuilder<bool>(
                      future: _checkTutorialSubmission(material['id']),
                      builder: (context, snapshot) {
                        final hasSubmitted = snapshot.data ?? false;
                        final isPastDue = dueDate != null &&
                            dueDate.toDate().isBefore(DateTime.now());

                        if (hasSubmitted) {
                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Tutorial Submitted',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudentTutorialSubmissionView(
                                        courseId: widget.courseId,
                                        materialId: material['id'],
                                        materialData: material,
                                        organizationCode: _organizationCode!,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('View', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _submitTutorial(material);
                            },
                            icon: Icon(Icons.upload_file, color: Colors.white),
                            label: Text(
                              isPastDue ? 'Submit (Late)' : 'Submit Tutorial',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPastDue ? Colors.orange : Colors.blue[600],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
        },
      ),
    );
  }

  Future<bool> _checkTutorialSubmission(String materialId) async {
    final user = _authService.currentUser;
    if (user == null || _organizationCode == null) return false;

    try {
      final submissionSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(materialId)
          .collection('submissions')
          .where('studentId', isEqualTo: user.uid)
          .get();

      return submissionSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking tutorial submission: $e');
      return false;
    }
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final Uri url = Uri.parse(fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
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
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course Title',
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
                    Icon(Icons.school, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.courseData['facultyName'] ?? 'Faculty',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

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
                Tab(text: 'Classmates'),
                Tab(text: 'Overview'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(),
                _buildClassmatesTab(),
                _buildOverviewTab(),
              ],
            ),
          ),
        ],
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
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildMaterialCardWithStream(Map<String, dynamic> material) {
    final materialType = material['materialType'] ?? 'learning';
    final isTutorial = materialType == 'tutorial';
    final isQuiz = materialType == 'quiz';
    final dueDate = material['dueDate'] as Timestamp?;
    final isPastDue = dueDate != null && dueDate.toDate().isBefore(DateTime.now());
    final user = _authService.currentUser;

    // Define colors and icons based on material type
    Color cardColor;
    IconData cardIcon;
    String typeLabel;

    if (isQuiz) {
      cardColor = Colors.purple;
      cardIcon = Icons.psychology;
      typeLabel = 'Quiz';
    } else if (isTutorial) {
      cardColor = Colors.blue;
      cardIcon = Icons.quiz;
      typeLabel = 'Tutorial';
    } else {
      cardColor = Colors.green;
      cardIcon = Icons.menu_book;
      typeLabel = 'Learning Material';
    }

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
        onTap: () => _viewMaterial(material),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    cardIcon,
                    color: cardColor,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            material['title'] ?? 'Material',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: cardColor.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      material['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    // Show submission status for quizzes and tutorials
                    if ((isTutorial || isQuiz) && user != null && _organizationCode != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('organizations')
                            .doc(_organizationCode)
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('materials')
                            .doc(material['id'])
                            .collection('submissions')
                            .where('studentId', isEqualTo: user.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final hasSubmitted = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                          // For quizzes, also show score if available
                          int? score;
                          int? totalPoints;
                          if (hasSubmitted && isQuiz && snapshot.data!.docs.isNotEmpty) {
                            final submissionData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                            score = submissionData['score'];
                            totalPoints = submissionData['totalPoints'] ?? material['totalPoints'];
                          }

                          return Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (dueDate != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: (hasSubmitted && isPastDue) ? Colors.grey[600] : (isPastDue ? Colors.red : Colors.grey[600])
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Due: ${_formatDate(dueDate)}',
                                      style: TextStyle(
                                        color: (hasSubmitted && isPastDue) ? Colors.grey[600] : (isPastDue ? Colors.red : Colors.grey[600]),
                                        fontSize: 11,
                                        fontWeight: (hasSubmitted && isPastDue) ? FontWeight.normal : (isPastDue ? FontWeight.bold : FontWeight.normal),
                                      ),
                                    ),
                                  ],
                                ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSubmitted
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : (isPastDue ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasSubmitted ? 'Completed' : (isPastDue ? 'Missing' : 'Pending'),
                                  style: TextStyle(
                                    color: hasSubmitted
                                        ? Colors.green
                                        : (isPastDue ? Colors.red : Colors.orange),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Show score for completed quizzes
                              if (hasSubmitted && isQuiz && score != null && totalPoints != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$score/$totalPoints',
                                    style: TextStyle(
                                      color: Colors.purple[700],
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // Show water bucket reward for incomplete items
                              if (!hasSubmitted)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_drink, size: 8, color: Colors.orange[700]),
                                      SizedBox(width: 1),
                                      Text(
                                        isQuiz ? '+2' : (isTutorial ? '+1' : ''),
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      )
                    else if (!isTutorial && !isQuiz)
                      Text(
                        _formatDate(material['createdAt']),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                material['files'] != null && (material['files'] as List).isNotEmpty
                    ? Icons.download
                    : (isQuiz ? Icons.play_arrow : Icons.visibility),
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (assignments.isNotEmpty) ...[
            _buildSectionHeader('Assignments', Icons.assignment),
            ...assignments.map((assignment) => _buildAssignmentCardWithStream(assignment)),
            SizedBox(height: 24),
          ],

          if (materials.isNotEmpty) ...[
            _buildSectionHeader('Materials', Icons.description),
            ...materials.map((material) => _buildMaterialCardWithStream(material)),
          ],

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
                    'No content available yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 100),
        ],
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

  Widget _buildAssignmentCardWithStream(Map<String, dynamic> assignment) {
    final dueDate = assignment['dueDate'] as Timestamp?;
    final isDuePassed = dueDate != null && dueDate.toDate().isBefore(DateTime.now());
    final user = _authService.currentUser;

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentAssignmentDetailsPage(
                assignment: assignment,
                courseId: widget.courseId,
                courseData: widget.courseData,
                organizationCode: _organizationCode!,
              ),
            ),
          ).then((_) => _loadData());
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
                  child: Icon(
                    Icons.assignment,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignment['title'] ?? 'Assignment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (user != null && _organizationCode != null)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('organizations')
                                .doc(_organizationCode)
                                .collection('courses')
                                .doc(widget.courseId)
                                .collection('assignments')
                                .doc(assignment['id'])
                                .collection('submissions')
                                .where('studentId', isEqualTo: user.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final hasSubmitted = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                              if (!hasSubmitted) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_drink, size: 12, color: Colors.orange[700]),
                                      SizedBox(width: 2),
                                      Text(
                                        '+4',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      assignment['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    if (user != null && _organizationCode != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('organizations')
                            .doc(_organizationCode)
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('assignments')
                            .doc(assignment['id'])
                            .collection('submissions')
                            .where('studentId', isEqualTo: user.uid)
                            .orderBy('submittedAt', descending: true)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final hasSubmitted = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                          final submission = hasSubmitted ? snapshot.data!.docs.first.data() as Map<String, dynamic> : null;
                          final isGraded = submission?['grade'] != null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status and due date row
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  // Due date info
                                  if (dueDate != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: (hasSubmitted && isDuePassed) ? Colors.grey[600] : (isDuePassed ? Colors.red : Colors.grey[600])
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Due: ${_formatDate(dueDate)}',
                                          style: TextStyle(
                                            color: (hasSubmitted && isDuePassed) ? Colors.grey[600] : (isDuePassed ? Colors.red : Colors.grey[600]),
                                            fontSize: 12,
                                            fontWeight: (hasSubmitted && isDuePassed) ? FontWeight.normal : (isDuePassed ? FontWeight.bold : FontWeight.normal),
                                          ),
                                        ),
                                      ],
                                    ),

                                  // Status badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hasSubmitted
                                          ? (isGraded
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.blue.withValues(alpha: 0.1))
                                          : (isDuePassed
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      hasSubmitted
                                          ? (isGraded ? 'Completed' : 'Submitted')
                                          : (isDuePassed ? 'Missing' : 'Pending'),
                                      style: TextStyle(
                                        color: hasSubmitted
                                            ? (isGraded ? Colors.green : Colors.blue)
                                            : (isDuePassed ? Colors.red : Colors.orange),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Grade display
                              if (hasSubmitted && isGraded) ...[
                                SizedBox(height: 8),
                                _buildGradeDisplay(
                                  grade: submission!['grade'],
                                  letterGrade: submission['letterGrade'],
                                  maxPoints: assignment['points'] ?? 100,
                                ),
                              ],
                            ],
                          );
                        },
                      )
                    else
                    // Fallback for when user is null or organization code is null
                      Row(
                        children: [
                          if (dueDate != null) ...[
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              'Due: ${_formatDate(dueDate)}',
                              style: TextStyle(
                                color: isDuePassed ? Colors.red : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 12),
                          ],
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDuePassed
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDuePassed ? 'Missing' : 'Pending',
                              style: TextStyle(
                                color: isDuePassed ? Colors.red : Colors.orange,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassmatesTab() {
    return classmates.isEmpty
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
            'No classmates found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: classmates.length,
      itemBuilder: (context, index) {
        return _buildClassmateCard(classmates[index]);
      },
    );
  }

  Widget _buildClassmateCard(Map<String, dynamic> student) {
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
            student['fullName'].toString().substring(0, 1).toUpperCase(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final submittedAssignments = assignments.where((a) => submissions.containsKey(a['id'])).length;
    final completedAssignments = submissions.values.where((s) => s['grade'] != null).length;
    final pendingAssignments = assignments.length - submittedAssignments;

    final tutorials = materials.where((m) => m['materialType'] == 'tutorial').toList();
    final completedTutorials = tutorials.where((t) => tutorialSubmissions.containsKey(t['id'])).length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedAssignments.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  pendingAssignments.toString(),
                  Icons.pending,
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
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Classmates',
                  classmates.length.toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

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
                  'Course Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Code', widget.courseData['code'] ?? 'N/A'),
                _buildDetailRow('Faculty', widget.courseData['facultyName'] ?? 'N/A'),
                _buildDetailRow('Lecturer', widget.courseData['lecturerName'] ?? 'N/A'),
                _buildDetailRow('Enrolled', _formatDate(widget.courseData['enrolledAt'])),
              ],
            ),
          ),

          SizedBox(height: 24),

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
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (assignments.isNotEmpty) ...[
                  Text(
                    'Assignments',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: submittedAssignments / assignments.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${(submittedAssignments / assignments.length * 100).toStringAsFixed(0)}% submitted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
                if (tutorials.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Tutorials',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: tutorials.isEmpty ? 0 : completedTutorials / tutorials.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${tutorials.isEmpty ? 0 : (completedTutorials / tutorials.length * 100).toStringAsFixed(0)}% completed',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
                if (assignments.isEmpty && tutorials.isEmpty)
                  Text(
                    'No assignments or tutorials yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDisplay({
    required int? grade,
    required String? letterGrade,
    required int maxPoints,
    double fontSize = 12,
  }) {
    if (grade == null) return SizedBox.shrink();

    // Calculate letter grade if not provided (backwards compatibility)
    String displayLetterGrade = letterGrade ?? '';
    if (displayLetterGrade.isEmpty) {
      final percentage = (grade / maxPoints) * 100;
      displayLetterGrade = _calculateLetterGrade(percentage);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Grade: $grade/$maxPoints',
            style: TextStyle(
              color: Colors.purple,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getLetterGradeColor(displayLetterGrade),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            displayLetterGrade,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods for letter grades
  String _calculateLetterGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 75) return 'A-';
    if (percentage >= 70) return 'B+';
    if (percentage >= 65) return 'B';
    if (percentage >= 60) return 'B-';
    if (percentage >= 55) return 'C+';
    if (percentage >= 50) return 'C';
    return 'F'; // Below 50 is F
  }

  Color _getLetterGradeColor(String? letterGrade) {
    if (letterGrade == null) return Colors.grey[600]!;

    switch (letterGrade) {
      case 'A+':
      case 'A':
      case 'A-':
        return Colors.green[600]!;
      case 'B+':
      case 'B':
      case 'B-':
        return Colors.blue[600]!;
      case 'C+':
      case 'C':
        return Colors.orange[600]!;
      case 'F':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
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
        switch (index) {
          case 0:
          // Navigate back to courses (student home)
            Navigator.pop(context);
            break;
          case 1:
          // Navigate to community
            _navigateToCommunity();
            break;
          case 2:
          // Navigate to chat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatContactPage(),
              ),
            ).then((_) {
              // Reset bottom navigation to Courses tab when returning from chat
              setState(() {
                _currentIndex = 0;
              });
            });
            break;
          case 3:
          // Navigate to Goal System (flower page)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StuGoal(),
              ),
            ).then((_) {
              // Reset bottom navigation to Courses tab when returning from goals
              setState(() {
                _currentIndex = 0;
              });
            });
            break;
          case 4:
          // Navigate to profile
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            ).then((_) {
              // Reset bottom navigation to Courses tab when returning from profile
              setState(() {
                _currentIndex = 0;
              });
            });
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
          icon: Icon(Icons.local_florist),
          label: 'Goals',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }

  Future<void> _navigateToCommunity() async {
    try {
      final organizationCode = _organizationCode ?? '';
      if (organizationCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Organization code not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get current user data
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User data not found'),
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
      final communityUser = CommunityUser(
        uid: user.uid,
        fullName: userData['fullName'] ?? 'Unknown',
        email: userData['email'] ?? '',
        avatarUrl: userData['avatarUrl'],
        bio: userData['bio'],
        organizationCode: userData['organizationCode'] ?? '',
        role: userData['role'] ?? 'student',
        postCount: userData['postCount'] ?? 0,
        friendCount: userData['friendCount'] ?? 0,
        joinDate: userData['createdAt'] != null
            ? (userData['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        isActive: userData['isActive'] ?? true,
      );

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

  // Utility methods
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

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    String dateStr = '${date.day}/${date.month}/${date.year}';
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0 && date.day == now.day) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && date.day != now.day)) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }

  String _formatFileSize(dynamic size) {
    int bytes = 0;
    if (size is int) {
      bytes = size;
    } else if (size is String) {
      bytes = int.tryParse(size) ?? 0;
    }

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}