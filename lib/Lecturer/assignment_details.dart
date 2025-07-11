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
      print('Loading submissions from path: organizations/$organizationCode/courses/${widget.courseId}/assignments/${assignmentData['id']}/submissions');

      // First try without orderBy to avoid index issues
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
        // If orderBy fails, get all documents and sort manually
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

      print('Found ${submissionsSnapshot.docs.length} submissions');

      List<Map<String, dynamic>> loadedSubmissions = [];

      for (var doc in submissionsSnapshot.docs) {
        final submissionData = doc.data() as Map<String, dynamic>;
        print('Processing submission: ${doc.id} from student: ${submissionData['studentId']}');

        // Get student details
        String studentName = 'Unknown Student';
        String studentEmail = '';
        String studentIdNumber = '';

        try {
          final studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(submissionData['studentId'])
              .get();

          if (studentDoc.exists) {
            final studentData = studentDoc.data()!;
            studentName = studentData['fullName'] ?? 'Unknown Student';
            studentEmail = studentData['email'] ?? '';
            studentIdNumber = studentData['studentId'] ?? '';
          }
        } catch (e) {
          print('Error fetching student data: $e');
        }

        // Check if evaluation exists
        Map<String, dynamic>? evaluationData;
        bool hasEvaluation = false;

        try {
          final evalDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(assignmentData['id'])
              .collection('submissions')
              .doc(doc.id)
              .collection('evaluations')
              .doc('current')
              .get();

          hasEvaluation = evalDoc.exists;
          if (evalDoc.exists) {
            evaluationData = evalDoc.data();
          }
        } catch (e) {
          print('Error checking evaluation: $e');
        }

        loadedSubmissions.add({
          'id': doc.id,
          ...submissionData,
          'studentName': studentName,
          'studentEmail': studentEmail,
          'studentId': studentIdNumber,
          'hasEvaluation': hasEvaluation,
          'evaluationData': evaluationData,
        });
      }

      // Sort manually if we couldn't use orderBy
      loadedSubmissions.sort((a, b) {
        final aTime = a['submittedAt'] as Timestamp?;
        final bTime = b['submittedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          submissions = loadedSubmissions;
        });
      }
    } catch (e) {
      print('Error loading submissions: $e');
      print('Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading submissions: ${e.toString()}'),
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
                  Row(
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
                      if (isOverdue) ...[
                        SizedBox(width: 8),
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
                      ],
                      if (hasRubric) ...[
                        SizedBox(width: 8),
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
                SizedBox(height: 20),

                // Instructions
                Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    assignmentData['instructions'] ?? 'No specific instructions provided.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
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

  Widget _buildSubmissionsTab() {
    if (submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No submissions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Students haven\'t submitted their work',
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
      child: ListView.builder(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        itemCount: submissions.length,
        itemBuilder: (context, index) {
          final submission = submissions[index];
          return _buildSubmissionCard(submission);
        },
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final submittedAt = submission['submittedAt'] as Timestamp?;
    final isGraded = submission['grade'] != null;
    final hasDetailedEvaluation = submission['hasEvaluation'] == true;
    final letterGrade = submission['letterGrade'];
    final percentage = submission['percentage'];

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
        onTap: () => _navigateToEvaluation(submission),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple[100],
                    child: Text(
                      (submission['studentName'] ?? 'S').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Colors.purple[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission['studentName'] ?? 'Unknown Student',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          submission['studentEmail'] ?? 'No email',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasDetailedEvaluation)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.rule,
                        size: 20,
                        color: Colors.purple[600],
                      ),
                    ),
                  if (isGraded) ...[
                    // Show letter grade if available
                    if (letterGrade != null)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getLetterGradeColor(letterGrade),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          letterGrade,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    // Show points and percentage
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${submission['grade']}/${assignmentData['points'] ?? 100}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (percentage != null)
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: () => _navigateToEvaluation(submission),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Evaluate', style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Submitted: ${_formatDateTime(submittedAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (submission['status'] == 'completed') ...[
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // File attachment display
              if (submission['fileName'] != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attachment, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        submission['fileName'],
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // Detailed evaluation feedback
              if (hasDetailedEvaluation && submission['evaluationData'] != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.feedback, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        'Evaluated with rubric',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (submission['evaluationData']['allowResubmission'] == true) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Resubmission allowed',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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