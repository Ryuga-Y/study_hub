import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<Map<String, dynamic>> submissions = [];
  bool isLoading = true;
  String? organizationCode;
  bool hasRubric = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isLecturer ? 2 : 1, vsync: this);
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

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      organizationCode = userData['organizationCode'];

      // Check if rubric exists
      await _checkRubric();

      if (widget.isLecturer) {
        await _loadSubmissions();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
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
          .doc(widget.assignment['id'])
          .collection('rubric')
          .doc('main')
          .get();

      setState(() {
        hasRubric = rubricDoc.exists;
      });
    } catch (e) {
      print('Error checking rubric: $e');
    }
  }

  Future<void> _loadSubmissions() async {
    if (organizationCode == null) return;

    try {
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignment['id'])
          .collection('submissions')
          .orderBy('submittedAt', descending: true)
          .get();

      List<Map<String, dynamic>> loadedSubmissions = [];

      for (var doc in submissionsSnapshot.docs) {
        final submissionData = doc.data();

        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(submissionData['studentId'])
            .get();

        if (studentDoc.exists) {
          // Check if evaluation exists
          final evalDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(widget.assignment['id'])
              .collection('submissions')
              .doc(doc.id)
              .collection('evaluations')
              .doc('current')
              .get();

          loadedSubmissions.add({
            'id': doc.id,
            ...submissionData,
            'studentName': studentDoc.data()?['fullName'] ?? 'Unknown Student',
            'studentEmail': studentDoc.data()?['email'] ?? '',
            'studentId': studentDoc.data()?['studentId'] ?? '',
            'hasEvaluation': evalDoc.exists,
            'evaluationData': evalDoc.exists ? evalDoc.data() : null,
          });
        }
      }

      setState(() {
        submissions = loadedSubmissions;
      });
    } catch (e) {
      print('Error loading submissions: $e');
    }
  }

  void _navigateToRubric() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationRubricPage(
          courseId: widget.courseId,
          assignmentId: widget.assignment['id'],
          assignmentData: widget.assignment,
          organizationCode: organizationCode!,
        ),
      ),
    ).then((_) => _checkRubric());
  }

  void _navigateToEvaluation(Map<String, dynamic> submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmissionEvaluationPage(
          courseId: widget.courseId,
          assignmentId: widget.assignment['id'],
          submissionId: submission['id'],
          submissionData: submission,
          assignmentData: widget.assignment,
          organizationCode: organizationCode!,
        ),
      ),
    ).then((result) {
      if (result == true) {
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
            .doc(widget.assignment['id'])
            .delete();

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment deleted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file')),
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

    final dueDate = widget.assignment['dueDate'] as Timestamp?;
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
              icon: Icon(Icons.analytics_outlined),
              color: Colors.purple[600],
              onPressed: _navigateToAnalytics,
              tooltip: 'Analytics',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
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
      body: Column(
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
                  widget.assignment['title'] ?? 'Assignment',
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
                    Expanded(  // Add this wrapper
                      child: Text(
                        '${widget.courseData['code'] ?? ''} - ${widget.courseData['title'] ?? widget.courseData['name'] ?? ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,  // Optional: add this to truncate with "..."
                        maxLines: 1,  // Optional: ensure it stays on one line
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
    );
  }

  Widget _buildDetailsTab() {
    final dueDate = widget.assignment['dueDate'] as Timestamp?;
    final attachments = widget.assignment['attachments'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
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
                        value: '${widget.assignment['points'] ?? 0}',
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
                  widget.assignment['description'] ?? 'No description provided.',
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
                    widget.assignment['instructions'] ?? 'No specific instructions provided.',
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
                        'Reference Materials',
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
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    decoration: TextDecoration.underline,
                                  ),
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

          // Statistics (for lecturer)
          if (widget.isLecturer) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Submitted',
                    submissions.length.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Graded',
                    submissions.where((s) => s['grade'] != null).length.toString(),
                    Icons.grade,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'With Rubric',
                    submissions.where((s) => s['hasEvaluation'] == true &&
                        s['evaluationData']?['rubricUsed'] == true).length.toString(),
                    Icons.rule,
                    Colors.purple,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Score',
                    _calculateAverageScore(),
                    Icons.analytics,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final submission = submissions[index];
        return _buildSubmissionCard(submission);
      },
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final submittedAt = submission['submittedAt'] as Timestamp?;
    final isGraded = submission['grade'] != null;
    final hasDetailedEvaluation = submission['hasEvaluation'] == true;

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
                      submission['studentName'].substring(0, 1).toUpperCase(),
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
                          submission['studentName'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'ID: ${submission['studentId']}',
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
                  if (isGraded)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Text(
                        '${submission['grade']}/${widget.assignment['points'] ?? 100}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
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
                ],
              ),
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
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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

  String _calculateAverageScore() {
    if (submissions.isEmpty) return 'N/A';

    final gradedSubmissions = submissions.where((s) => s['grade'] != null).toList();
    if (gradedSubmissions.isEmpty) return 'N/A';

    double totalScore = 0;
    for (var submission in gradedSubmissions) {
      totalScore += submission['grade'];
    }

    final avgScore = totalScore / gradedSubmissions.length;
    final maxPoints = widget.assignment['points'] ?? 100;
    final percentage = (avgScore / maxPoints * 100).toStringAsFixed(1);

    return '$percentage%';
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