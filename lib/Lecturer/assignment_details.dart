import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Lecturer/create_assignment.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Authentication/auth_services.dart';
import 'evaluation_rubric.dart';
import 'feedback.dart';
import 'submission_evaluation.dart';
import 'evaluation_analytics.dart';

class AssignmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool isLecturer;

  const AssignmentDetailPage({
    Key? key,
    required this.assignment,
    required this.courseId,
    required this.courseData,
    required this.isLecturer,
  }) : super(key: key);

  @override
  _AssignmentDetailPageState createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Make assignmentData mutable to allow updates
  late Map<String, dynamic> assignmentData;

  List<Map<String, dynamic>> submissions = [];
  bool isLoading = true;
  String? organizationCode;
  bool hasRubric = false;
  Map<String, dynamic>? rubricData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isLecturer ? 2 : 1, vsync: this);

    // Create a mutable copy of assignment data
    assignmentData = Map<String, dynamic>.from(widget.assignment);

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
      if (user == null) return;

      // Get organization code from courseData first, fallback to user data
      organizationCode = widget.courseData['organizationCode'];

      if (organizationCode == null || organizationCode!.isEmpty) {
        final userData = await _authService.getUserData(user.uid);
        if (userData == null) return;
        organizationCode = userData['organizationCode'];
      }

      print('Loading data with organizationCode: $organizationCode');
      print('Assignment ID: ${assignmentData['id']}');
      print('Course ID: ${widget.courseId}');

      // Load latest assignment data from Firestore
      await _reloadAssignmentData();

      // Check if rubric exists
      await _checkRubric();

      if (widget.isLecturer) {
        await _loadSubmissions();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLateSubmissions() async {
    final currentValue = assignmentData['allowLateSubmissions'] ?? true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              currentValue ? Icons.cancel : Icons.check_circle,
              color: currentValue ? Colors.red[600] : Colors.green[600],
              size: 24,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                currentValue ? 'Disable Late Submissions' : 'Enable Late Submissions',
                style: TextStyle(fontWeight: FontWeight.w500), // Optional: add styling
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentValue
                  ? 'Are you sure you want to disable late submissions?'
                  : 'Are you sure you want to enable late submissions?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentValue ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentValue ? Colors.red[200]! : Colors.green[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: currentValue ? Colors.red[700] : Colors.green[700],
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentValue
                          ? 'Students will NOT be able to submit after the due date'
                          : 'Students will be able to submit after the due date',
                      style: TextStyle(
                        color: currentValue ? Colors.red[700] : Colors.green[700],
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
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentValue ? Colors.red : Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              currentValue ? 'Disable' : 'Enable',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && organizationCode != null) {
      setState(() {
        isLoading = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentData['id'])
            .update({
          'allowLateSubmissions': !currentValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update local state
        setState(() {
          assignmentData['allowLateSubmissions'] = !currentValue;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !currentValue ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  !currentValue
                      ? 'Late submissions enabled'
                      : 'Late submissions disabled',
                ),
              ],
            ),
            backgroundColor: !currentValue ? Colors.green : Colors.red,
          ),
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating late submission setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkRubric() async {
    if (organizationCode == null) return;

    try {
      final rubricDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(assignmentData['id'])
          .collection('rubric')
          .doc('main')
          .get();

      if (mounted) {
        setState(() {
          hasRubric = rubricDoc.exists;
          if (rubricDoc.exists) {
            rubricData = rubricDoc.data();
          }
        });
      }
    } catch (e) {
      print('Error checking rubric: $e');
    }
  }

  Future<void> _loadSubmissions() async {
    if (organizationCode == null) return;

    try {
      print('Loading all enrolled students and their submission status');
      print('Path: organizations/$organizationCode/courses/${widget.courseId}/enrollments');

      // First, load all enrolled students
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      print('Found ${enrollmentsSnapshot.docs.length} enrolled students');

      List<Map<String, dynamic>> allStudentsWithStatus = [];

      // Load all submissions for this assignment
      QuerySnapshot submissionsSnapshot;
      try {
        submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentData['id'])
            .collection('submissions')
            .orderBy('submittedAt', descending: true)
            .get();
      } catch (e) {
        print('OrderBy failed, trying without ordering: $e');
        submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentData['id'])
            .collection('submissions')
            .get();
      }

      // Create a map of submissions by studentId for quick lookup
      Map<String, Map<String, dynamic>> submissionsByStudent = {};
      for (var doc in submissionsSnapshot.docs) {
        final submissionData = doc.data() as Map<String, dynamic>;
        final studentId = submissionData['studentId'];
        if (studentId != null) {
          submissionsByStudent[studentId] = {
            'id': doc.id,
            ...submissionData,
          };
        }
      }

      // Process each enrolled student
      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
        final studentId = enrollmentData['studentId'];

        if (studentId == null) continue;

        print('Processing student: $studentId');

        // Get student details
        String studentName = 'Unknown Student';
        String studentEmail = '';
        String studentIdNumber = '';

        try {
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data()!;
            studentName = studentData['fullName'] ?? 'Unknown Student';
            studentEmail = studentData['email'] ?? '';
            studentIdNumber = studentData['studentId'] ?? '';
          }
        } catch (e) {
          print('Error fetching student data for $studentId: $e');
        }

        // Check if student has a submission
        final submission = submissionsByStudent[studentId];
        bool hasSubmission = submission != null;
        bool hasEvaluation = false;
        Map<String, dynamic>? evaluationData;

        if (hasSubmission) {
          // Check if evaluation exists for this submission
          try {
            final evalDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(organizationCode)
                .collection('courses')
                .doc(widget.courseId)
                .collection('assignments')
                .doc(assignmentData['id'])
                .collection('submissions')
                .doc(submission['id'])
                .collection('evaluations')
                .doc('current')
                .get();

            hasEvaluation = evalDoc.exists;
            if (evalDoc.exists) {
              evaluationData = evalDoc.data();
            }
          } catch (e) {
            print('Error checking evaluation for ${submission['id']}: $e');
          }
        }

        // Create student record with submission status
        Map<String, dynamic> studentRecord = {
          'studentId': studentId,
          'studentName': studentName,
          'studentEmail': studentEmail,
          'studentIdNumber': studentIdNumber,
          'hasSubmission': hasSubmission,
          'submissionStatus': hasSubmission ? 'submitted' : 'not_submitted',
          'hasEvaluation': hasEvaluation,
          'evaluationData': evaluationData,
        };

        // Add submission data if exists
        if (hasSubmission) {
          studentRecord.addAll(submission);
        } else {
          // Add default values for non-submitted students
          studentRecord.addAll({
            'id': null,
            'submittedAt': null,
            'fileName': null,
            'fileUrl': null,
            'grade': null,
            'letterGrade': null,
            'percentage': null,
            'feedback': null,
            'status': 'not_submitted',
            'isLate': null,
            'evaluationIsDraft': false,
            'isReleased': false,
          });
        }

        allStudentsWithStatus.add(studentRecord);
      }

      // Sort students: submitted first, then by submission time (latest first) for submitted,
      // and alphabetically by name for non-submitted
      allStudentsWithStatus.sort((a, b) {
        // First priority: submission status (submitted first)
        if (a['hasSubmission'] && !b['hasSubmission']) return -1;
        if (!a['hasSubmission'] && b['hasSubmission']) return 1;

        // If both have submitted, sort by submission time (latest first)
        if (a['hasSubmission'] && b['hasSubmission']) {
          final aTime = a['submittedAt'] as Timestamp?;
          final bTime = b['submittedAt'] as Timestamp?;
          if (aTime != null && bTime != null) {
            return bTime.compareTo(aTime);
          }
        }

        // If both haven't submitted, sort alphabetically by name
        if (!a['hasSubmission'] && !b['hasSubmission']) {
          return (a['studentName'] ?? '').compareTo(b['studentName'] ?? '');
        }

        return 0;
      });

      if (mounted) {
        setState(() {
          submissions = allStudentsWithStatus;
        });
      }

      print('Processed ${allStudentsWithStatus.length} students total');
      print('Submitted: ${allStudentsWithStatus.where((s) => s['hasSubmission']).length}');
      print('Not submitted: ${allStudentsWithStatus.where((s) => !s['hasSubmission']).length}');

    } catch (e) {
      print('Error loading submissions and student status: $e');
      print('Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading student submissions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAssignmentPage(
          courseId: widget.courseId,
          courseData: {
            ...widget.courseData,
            'organizationCode': organizationCode,
          },
          editMode: true,
          assignmentId: assignmentData['id'],
          assignmentData: assignmentData,
        ),
      ),
    );

    if (result == true && mounted) {
      // Reload all data
      await _loadData();
    }
  }

  // Updated method to properly reload assignment data
  Future<void> _reloadAssignmentData() async {
    if (organizationCode == null) return;

    try {
      // Fetch updated assignment data
      final assignmentDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(assignmentData['id'])
          .get();

      if (assignmentDoc.exists && mounted) {
        setState(() {
          // Update the assignment data
          assignmentData = {
            'id': assignmentDoc.id,
            ...assignmentDoc.data()!,
          };
        });
      }
    } catch (e) {
      print('Error reloading assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reloading assignment data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToRubric() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationRubricPage(
          courseId: widget.courseId,
          assignmentId: assignmentData['id'],
          assignmentData: assignmentData,
          organizationCode: organizationCode!,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _checkRubric();
      }
    });
  }

  void _navigateToEvaluation(Map<String, dynamic> submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmissionEvaluationPage(
          courseId: widget.courseId,
          assignmentId: assignmentData['id'],
          submissionId: submission['id'],
          submissionData: submission,
          assignmentData: assignmentData,
          organizationCode: organizationCode!,
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _loadSubmissions();
      }
    });
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationAnalyticsPage(
          courseId: widget.courseId,
          organizationCode: organizationCode!,
          courseData: widget.courseData,
        ),
      ),
    );
  }

  void _navigateToFeedbackHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackHistoryPage(
          courseId: widget.courseId,
          organizationCode: organizationCode!,
          isStudent: !widget.isLecturer,
        ),
      ),
    );
  }

  Future<void> _deleteAssignment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Assignment'),
        content: Text('Are you sure you want to delete this assignment? This action cannot be undone.'),
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

    if (confirm == true && organizationCode != null) {
      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentData['id'])
            .delete();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Assignment deleted successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting assignment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  // Add refresh functionality
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    await _loadData();
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

    final dueDate = assignmentData['dueDate'] as Timestamp?;
    final isOverdue = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Assignment Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isLecturer) ...[
            IconButton(
              icon: Icon(Icons.refresh),
              color: Colors.purple[600],
              onPressed: _refreshData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: Icon(Icons.analytics_outlined),
              color: Colors.purple[600],
              onPressed: _navigateToAnalytics,
              tooltip: 'Analytics',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _navigateToEditAssignment();
                    break;
                  case 'rubric':
                    _navigateToRubric();
                    break;
                  case 'late_submissions': // ADD THIS CASE
                    _toggleLateSubmissions();
                    break;
                  case 'feedback_history':
                    _navigateToFeedbackHistory();
                    break;
                  case 'delete':
                    _deleteAssignment();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Assignment'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rubric',
                  child: Row(
                    children: [
                      Icon(Icons.rule, size: 20),
                      SizedBox(width: 8),
                      Text(hasRubric ? 'Edit Rubric' : 'Create Rubric'),
                    ],
                  ),
                ),
                // ADD THIS MENU ITEM
                PopupMenuItem(
                  value: 'late_submissions',
                  child: Row(
                    children: [
                      Icon(
                        assignmentData['allowLateSubmissions'] ?? true
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 20,
                        color: assignmentData['allowLateSubmissions'] ?? true
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        assignmentData['allowLateSubmissions'] ?? true
                            ? 'Disable Late Submissions'
                            : 'Enable Late Submissions',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'feedback_history',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(width: 8),
                      Text('Feedback History'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Assignment'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              icon: Icon(Icons.feedback_outlined),
              color: Colors.purple[600],
              onPressed: _navigateToFeedbackHistory,
              tooltip: 'My Feedback',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.purple[400],
        child: Column(
          children: [
            // Assignment Header
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[600]!, Colors.orange[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Assignment',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOverdue)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Overdue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (hasRubric)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rule, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Rubric',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    assignmentData['title'] ?? 'Assignment',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.library_books, color: Colors.white.withValues(alpha: 0.9), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.courseData['code'] ?? ''} - ${widget.courseData['title'] ?? widget.courseData['name'] ?? ''}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
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

            // Tab Bar
            if (widget.isLecturer)
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
                  indicatorColor: Colors.orange[400],
                  indicatorWeight: 3,
                  labelColor: Colors.orange[600],
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Submissions (${submissions.length})'),
                  ],
                ),
              ),

            // Tab Content
            Expanded(
              child: widget.isLecturer
                  ? TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildSubmissionsTab(),
                ],
              )
                  : _buildDetailsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final dueDate = assignmentData['dueDate'] as Timestamp?;
    final attachments = assignmentData['attachments'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Late Submission Status Card
          Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (assignmentData['allowLateSubmissions'] ?? true)
                  ? Colors.green[50]
                  : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (assignmentData['allowLateSubmissions'] ?? true)
                    ? Colors.green[300]!
                    : Colors.red[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  (assignmentData['allowLateSubmissions'] ?? true)
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: (assignmentData['allowLateSubmissions'] ?? true)
                      ? Colors.green[700]
                      : Colors.red[700],
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Late Submission Policy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        (assignmentData['allowLateSubmissions'] ?? true)
                            ? 'Students can submit after the due date'
                            : 'No submissions accepted after due date',
                        style: TextStyle(
                          color: (assignmentData['allowLateSubmissions'] ?? true)
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isLecturer)
                  TextButton(
                    onPressed: _toggleLateSubmissions,
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Assignment Info Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
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
                    Icon(Icons.info_outline, color: Colors.orange[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Assignment Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Due Date and Points
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.calendar_today,
                        label: 'Due Date',
                        value: _formatDateTime(dueDate),
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.grade,
                        label: 'Points',
                        value: '${assignmentData['points'] ?? 0}',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Description
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  assignmentData['description'] ?? 'No description provided.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Rubric Card
          if (hasRubric && rubricData != null) ...[
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rule, color: Colors.purple[600], size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Evaluation Rubric',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      if (widget.isLecturer)
                        TextButton.icon(
                          onPressed: _navigateToRubric,
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple[600],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Rubric criteria
                  if (rubricData!['criteria'] != null) ...[
                    ...(rubricData!['criteria'] as List).map((criterion) {
                      final weight = criterion['weight'] ?? 0;
                      final levels = criterion['levels'] as List? ?? [];

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    criterion['name'] ?? 'Criterion',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.purple[800],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[600],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$weight%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (criterion['description'] != null && criterion['description'].toString().isNotEmpty) ...[
                              SizedBox(height: 4),
                              Text(
                                criterion['description'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            SizedBox(height: 8),

                            // Performance levels
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: levels.map<Widget>((level) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.purple[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        level['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.purple[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${level['points'] ?? 0}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  // Total points info
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 8),
                        Text(
                          'Total Assignment Points: ${rubricData!['totalPoints'] ?? assignmentData['points'] ?? 100}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Attachments Card
          if (attachments.isNotEmpty)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
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
                      Icon(Icons.attach_file, color: Colors.purple[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Reference Materials (${attachments.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ...attachments.map((attachment) {
                    final name = attachment['name'] ?? 'File';
                    final url = attachment['url'] ?? '';
                    final size = attachment['size'];

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _launchUrl(url),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(name),
                                color: Colors.purple[400],
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (size != null) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        _formatFileSize(size is int ? size : int.tryParse(size.toString()) ?? 0),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.download,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Update _buildSubmissionsTab to add batch return button
  Widget _buildSubmissionsTab() {
    // Count different statuses
    final submittedCount = submissions.where((s) => s['hasSubmission'] == true).length;
    final notSubmittedCount = submissions.where((s) => s['hasSubmission'] == false).length;
    final draftCount = submissions.where((s) =>
    s['evaluationIsDraft'] == true && s['hasEvaluation'] == true
    ).length;

    if (submissions.isEmpty) {
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
              'No students enrolled',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No students are enrolled in this course',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text('Refresh', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.purple[400],
      child: Column(
        children: [
          // Compact Statistics Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
            child: Column(
              children: [
                // Compact Statistics Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatCard(
                        'Submitted',
                        submittedCount.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatCard(
                        'Pending',
                        notSubmittedCount.toString(),
                        Colors.orange,
                        Icons.pending,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatCard(
                        'Total',
                        submissions.length.toString(),
                        Colors.blue,
                        Icons.people,
                      ),
                    ),
                  ],
                ),

                // Compact Progress Bar
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14, // Smaller font
                            ),
                          ),
                          Text(
                            '${submittedCount}/${submissions.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: submissions.isNotEmpty ? submittedCount / submissions.length : 0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green[500]!),
                        minHeight: 6, // Thinner progress bar
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${(submissions.isNotEmpty ? (submittedCount / submissions.length * 100) : 0).toStringAsFixed(1)}% complete',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Compact batch return button if there are drafts
          if (draftCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              margin: EdgeInsets.only(bottom: 8),
              child: Container(
                padding: EdgeInsets.all(12), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.drafts, color: Colors.orange[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$draftCount draft${draftCount > 1 ? 's' : ''} pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Return to students',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _returnAllDrafts,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Return All',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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

          // Optimized Students List
          Expanded(
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
              itemCount: submissions.length,
              itemExtent: null, // Let Flutter calculate optimal height
              itemBuilder: (context, index) {
                final student = submissions[index];
                return _buildStudentSubmissionCard(student);
              },
            ),
          ),
        ],
      ),
    );
  }

// Compact statistics card
  Widget _buildCompactStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(10), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20), // Smaller icon
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18, // Smaller font
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10, // Smaller font
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildStudentSubmissionCard(Map<String, dynamic> student) {
    final hasSubmission = student['hasSubmission'] == true;
    final submittedAt = student['submittedAt'] as Timestamp?;
    final isGraded = student['grade'] != null;
    final hasDetailedEvaluation = student['hasEvaluation'] == true;
    final letterGrade = student['letterGrade'];
    final percentage = student['percentage'];
    final isDraft = student['evaluationIsDraft'] == true;
    final isReleased = student['isReleased'] == true;
    final studentName = student['studentName'] ?? 'Unknown Student';
    final studentEmail = student['studentEmail'] ?? 'No email';

    // Determine card colors based on submission status
    Color borderColor;
    Color backgroundColor;
    if (!hasSubmission) {
      borderColor = Colors.orange[300]!;
      backgroundColor = Colors.orange[50]!;
    } else if (isGraded && isReleased) {
      borderColor = Colors.green[300]!;
      backgroundColor = Colors.green[50]!;
    } else {
      borderColor = Colors.grey[300]!;
      backgroundColor = Colors.white;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8), // Reduced margin
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10), // Slightly smaller radius
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: hasSubmission ? () => _navigateToEvaluation(student) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(12), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main row with student info and status
              Row(
                children: [
                  // Smaller avatar
                  CircleAvatar(
                    radius: 18, // Smaller avatar
                    backgroundColor: hasSubmission ? Colors.purple[100] : Colors.orange[100],
                    child: Text(
                      studentName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: hasSubmission ? Colors.purple[600] : Colors.orange[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),

                  // Student info - more compact
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // Smaller font
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          studentEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11, // Smaller font
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8),

                  // Status and actions - more compact
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!hasSubmission) ...[
                          // Not submitted status
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[300]!),
                            ),
                            child: Text(
                              'Not Submitted',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ] else if (hasDetailedEvaluation && isDraft) ...[
                          // Draft evaluation
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Draft',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _returnSingleEvaluation(student),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.send, size: 10, color: Colors.white),
                                      SizedBox(width: 2),
                                      Text(
                                        'Return',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isGraded && isReleased) ...[
                          // Graded and released
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (letterGrade != null)
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _getLetterGradeColor(letterGrade),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    letterGrade,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green[300]!),
                                ),
                                child: Text(
                                  '${student['grade']}/${assignmentData['points'] ?? 100}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (hasSubmission) ...[
                          // Submitted but not evaluated
                          GestureDetector(
                            onTap: () => _navigateToEvaluation(student),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[600],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Evaluate',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Submission time or due date
                        SizedBox(height: 4),
                        Text(
                          hasSubmission
                              ? _formatCompactDateTime(submittedAt)
                              : 'Due: ${_formatCompactDateTime(assignmentData['dueDate'])}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Additional info row (compact)
              if (hasSubmission) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    // Status indicators
                    if (student['status'] == 'completed')
                      _buildCompactBadge('Completed', Colors.green[600]!, Icons.check_circle),
                    if (student['status'] == 'evaluated_draft')
                      _buildCompactBadge('Draft', Colors.orange[600]!, Icons.drafts),
                    if (student['isLate'] == true)
                      _buildCompactBadge('Late', Colors.red[600]!, Icons.warning),
                    if (hasDetailedEvaluation)
                      _buildCompactBadge('Rubric', Colors.purple[600]!, Icons.rule),

                    Spacer(),

                    // File indicator
                    if (student['fileName'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment, size: 12, color: Colors.blue[600]),
                          SizedBox(width: 2),
                          Text(
                            'File',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ] else if (!hasSubmission) ...[
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.orange[600]),
                    SizedBox(width: 4),
                    Text(
                      'Awaiting submission',
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactBadge(String text, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(right: 6),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

// Helper method for compact date formatting
  String _formatCompactDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'N/A';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  // Add batch return functionality:
  Future<void> _returnAllDrafts() async {
    // Get all draft evaluations
    final draftSubmissions = submissions.where((s) =>
    s['evaluationIsDraft'] == true && s['hasEvaluation'] == true
    ).toList();

    if (draftSubmissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No draft evaluations to return'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.send, color: Colors.green[600], size: 24),
            SizedBox(width: 8),
            Text('Return All Evaluations'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to return all ${draftSubmissions.length} draft evaluations to students?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Students to receive evaluations:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  ...draftSubmissions.take(5).map((s) =>
                      Text('• ${s['studentName']}',
                          style: TextStyle(fontSize: 13, color: Colors.blue[700]))
                  ),
                  if (draftSubmissions.length > 5)
                    Text('... and ${draftSubmissions.length - 5} more',
                        style: TextStyle(fontSize: 13, color: Colors.blue[700], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text('Return All', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      int successCount = 0;

      for (final submission in draftSubmissions) {
        try {
          await _releaseSubmissionEvaluation(submission['id']);
          successCount++;
        } catch (e) {
          print('Error releasing evaluation for ${submission['studentName']}: $e');
        }
      }

      await _loadSubmissions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully returned $successCount evaluations to students'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error returning evaluations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

// Add helper method to release individual submission
  Future<void> _releaseSubmissionEvaluation(String submissionId) async {
    // Get evaluation data
    final evalDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .doc(assignmentData['id'])
        .collection('submissions')
        .doc(submissionId)
        .collection('evaluations')
        .doc('current')
        .get();

    if (!evalDoc.exists) {
      throw Exception('Evaluation not found');
    }

    final evalData = evalDoc.data()!;

    // Update evaluation to released
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .doc(assignmentData['id'])
        .collection('submissions')
        .doc(submissionId)
        .collection('evaluations')
        .doc('current')
        .update({
      'isDraft': false,
      'isReleased': true,
      'releasedAt': FieldValue.serverTimestamp(),
    });

    // Update submission with grade data
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationCode)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .doc(assignmentData['id'])
        .collection('submissions')
        .doc(submissionId)
        .update({
      'grade': evalData['grade'],
      'letterGrade': evalData['letterGrade'],
      'percentage': evalData['percentage'],
      'feedback': evalData['feedback'],
      'status': 'completed',
      'isReleased': true,
      'evaluationIsDraft': false,
      'releasedAt': FieldValue.serverTimestamp(),
    });
  }

// Add method to return single evaluation
  Future<void> _returnSingleEvaluation(Map<String, dynamic> submission) async {
    setState(() {
      isLoading = true;
    });

    try {
      await _releaseSubmissionEvaluation(submission['id']);
      await _loadSubmissions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Evaluation returned to ${submission['studentName']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error returning evaluation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
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
      default:
        return Icons.insert_drive_file;
    }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    String dateStr = '${date.day}/${date.month}/${date.year}';
    String timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }
}