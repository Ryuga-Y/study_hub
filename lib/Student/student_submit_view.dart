import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Authentication/auth_services.dart';
import '../Lecturer/feedback.dart';

class StudentSubmissionView extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final Map<String, dynamic> assignmentData;
  final String organizationCode;

  const StudentSubmissionView({
    Key? key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _StudentSubmissionViewState createState() => _StudentSubmissionViewState();
}

class _StudentSubmissionViewState extends State<StudentSubmissionView> {
  final AuthService _authService = AuthService();
  bool isLoading = true;

  Map<String, dynamic>? latestSubmission;
  Map<String, dynamic>? evaluation;
  Map<String, dynamic>? rubric;
  List<Map<String, dynamic>> submissionHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Letter grade color function (same as evaluation page)
  Color _getGradeColor(String? letterGrade) {
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

  // Convert percentage to letter grade for backwards compatibility
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

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = _authService.currentUser;
      if (user == null) {
        print('No authenticated user found');
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('Loading data for user: ${user.uid}');

      // Load submission history without orderBy
      final submissionsQuery = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .where('studentId', isEqualTo: user.uid);

      print('Query path: organizations/${widget.organizationCode}/courses/${widget.courseId}/assignments/${widget.assignmentId}/submissions');

      final submissionsSnapshot = await submissionsQuery.get();

      print('Found ${submissionsSnapshot.docs.length} submissions');

      if (submissionsSnapshot.docs.isNotEmpty) {
        // Sort by submittedAt manually
        final sortedDocs = submissionsSnapshot.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['submittedAt'] as Timestamp?;
            final bTime = b.data()['submittedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // Descending order
          });

        // Get latest submission
        final latestDoc = sortedDocs.first;
        latestSubmission = {
          'id': latestDoc.id,
          ...latestDoc.data(),
        };

        print('Latest submission ID: ${latestSubmission!['id']}');

        // Get all submissions for history
        submissionHistory = sortedDocs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();

        // Load evaluation for latest submission
        try {
          final evalDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(widget.assignmentId)
              .collection('submissions')
              .doc(latestDoc.id)
              .collection('evaluations')
              .doc('current')
              .get();

          if (evalDoc.exists) {
            final evalData = evalDoc.data()!;

            // Only show evaluation if it's released
            if (evalData['isReleased'] == true) {
              evaluation = evalData;
              print('Found released evaluation for submission');

              // Load rubric if evaluation used one
              if (evaluation!['rubricUsed'] == true) {
                final rubricDoc = await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationCode)
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('assignments')
                    .doc(widget.assignmentId)
                    .collection('rubric')
                    .doc('main')
                    .get();

                if (rubricDoc.exists) {
                  rubric = rubricDoc.data();
                  print('Loaded rubric data');
                }
              }
            } else {
              print('Evaluation exists but is not released (draft)');
              // Don't set evaluation if it's a draft
              evaluation = null;
            }
          }
        } catch (evalError) {
          print('Error loading evaluation: $evalError');
          // Continue without evaluation data
        }

        // Also check if grade exists in submission document (for released evaluations)
        if (latestSubmission!['grade'] != null &&
            latestSubmission!['isReleased'] == true &&
            evaluation == null) {
          // Create a synthetic evaluation object from submission data
          evaluation = {
            'grade': latestSubmission!['grade'],
            'letterGrade': latestSubmission!['letterGrade'],
            'feedback': latestSubmission!['feedback'],
            'evaluatedAt': latestSubmission!['gradedAt'] ?? latestSubmission!['submittedAt'],
            'isReleased': true,
          };
        }
      } else {
        print('No submissions found for user: ${user.uid}');
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file')),
      );
    }
  }

  Future<void> _navigateToResubmit() async {
    // Navigate back to assignment details for resubmission
    Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Submissions',
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
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.purple[600]),
            onPressed: _refreshData,
          ),
          if (submissionHistory.length > 1)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FeedbackHistoryPage(
                      courseId: widget.courseId,
                      organizationCode: widget.organizationCode,
                      studentId: _authService.currentUser?.uid,
                      isStudent: true,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.history),
              label: Text('All Feedback'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purple[600],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.purple[400],
        child: latestSubmission == null
            ? _buildNoSubmissionState()
            : _buildSubmissionContent(),
      ),
    );
  }

  Widget _buildNoSubmissionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No submission yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You haven\'t submitted this assignment',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.white),
            label: Text(
              'Go Back to Submit',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionContent() {
    final isGraded = evaluation != null || (latestSubmission!['grade'] != null && latestSubmission!['isReleased'] == true);
    final isDraftEvaluation = latestSubmission!['evaluationIsDraft'] == true;
    final hasEvaluation = latestSubmission!['hasEvaluation'] == true;
    final grade = latestSubmission!['grade'] ?? evaluation?['grade'];
    final letterGrade = latestSubmission!['letterGrade'] ?? evaluation?['letterGrade'];
    final maxPoints = widget.assignmentData['points'] ?? 100;

    // Calculate letter grade if not provided (for backwards compatibility)
    String displayLetterGrade = letterGrade ?? '';
    if (displayLetterGrade.isEmpty && grade != null) {
      final percentage = (grade / maxPoints) * 100;
      displayLetterGrade = _calculateLetterGrade(percentage);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Assignment Header
          Container(
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
                Text(
                  widget.assignmentData['title'] ?? 'Assignment',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.grade, color: Colors.white.withValues(alpha: 0.9), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Total Points: $maxPoints',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${submissionHistory.length} submission${submissionHistory.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Evaluation Status
          if (hasEvaluation && isDraftEvaluation) ...[
            // Draft evaluation - show pending status
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.blue[600], size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluation In Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your lecturer has evaluated your submission but hasn\'t released the grade yet.',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 14,
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

          // Resubmit Option - Only if not graded or not evaluated
          if (!hasEvaluation && latestSubmission?['grade'] == null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.blue[600], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit New Version',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You can submit an updated version until graded',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _navigateToResubmit,
                    child: Text(
                      'Resubmit',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ) else if (isGraded)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.green[600], size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignment Completed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This assignment has been graded. No further submissions allowed.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Final',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16),

          // Grade Card (if graded and released)
          if (isGraded && grade != null)
            Container(
              padding: EdgeInsets.all(24),
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
                children: [
                  Text(
                    'Final Grade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Letter Grade
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getGradeColor(displayLetterGrade).withValues(alpha: 0.1),
                          border: Border.all(
                            color: _getGradeColor(displayLetterGrade),
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            displayLetterGrade,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _getGradeColor(displayLetterGrade),
                            ),
                          ),
                        ),
                      ),
                      // Points
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getGradeColor(displayLetterGrade).withValues(alpha: 0.1),
                          border: Border.all(
                            color: _getGradeColor(displayLetterGrade),
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$grade',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _getGradeColor(displayLetterGrade),
                                ),
                              ),
                              Text(
                                'out of $maxPoints',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '${(grade / maxPoints * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getGradeColor(displayLetterGrade),
                    ),
                  ),
                ],
              ),
            ),

          if (!isGraded && !isDraftEvaluation)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.pending, color: Colors.orange[600], size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Evaluation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your submission is being reviewed',
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
            ),
          SizedBox(height: 16),

          // Rubric Evaluation (if available)
          if (evaluation != null && evaluation!['rubricUsed'] == true && rubric != null)
            _buildRubricEvaluation(),

          // Feedback Card
          if ((evaluation != null && evaluation!['feedback'] != null) ||
              (latestSubmission!['feedback'] != null))
            Container(
              margin: EdgeInsets.only(bottom: 16),
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
                      Icon(Icons.comment, color: Colors.blue[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Lecturer Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      evaluation?['feedback'] ?? latestSubmission!['feedback'] ?? '',
                      style: TextStyle(
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Submission Details
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
                    Icon(Icons.info_outline, color: Colors.purple[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Latest Submission Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildDetailRow(
                  'Status',
                  isGraded ? 'Completed' : 'Submitted',
                  isGraded ? Icons.check_circle : Icons.pending,
                  isGraded ? Colors.green : Colors.orange,
                ),
                _buildDetailRow(
                  'Version',
                  'Version ${latestSubmission!['submissionVersion'] ?? 1} of ${submissionHistory.length}',
                  Icons.layers,
                  Colors.blue,
                ),
                _buildDetailRow(
                  'Submitted',
                  _formatDateTime(latestSubmission!['submittedAt']),
                  Icons.access_time,
                  Colors.blue,
                ),
                if (isGraded && (evaluation?['evaluatedAt'] != null || latestSubmission!['gradedAt'] != null))
                  _buildDetailRow(
                    'Completed',
                    _formatDateTime(evaluation?['evaluatedAt'] ?? latestSubmission!['gradedAt']),
                    Icons.grade,
                    Colors.purple,
                  ),
                if (latestSubmission!['isLate'] == true)
                  _buildDetailRow(
                    'Submission',
                    'Late Submission',
                    Icons.warning,
                    Colors.red,
                  ),
                if (latestSubmission!['fileName'] != null)
                  InkWell(
                    onTap: () => _launchUrl(latestSubmission!['fileUrl']),
                    child: Container(
                      margin: EdgeInsets.only(top: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(latestSubmission!['fileName']),
                            color: Colors.purple[600],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              latestSubmission!['fileName'],
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.download,
                            color: Colors.purple[600],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Enhanced Submission Versions - Shows version history of the same submission
          if (latestSubmission!['submissionVersion'] != null && latestSubmission!['submissionVersion'] > 1)
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
                      Icon(Icons.history, color: Colors.grey[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Submission Versions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Version: ${latestSubmission!['submissionVersion']}',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You have updated your submission ${latestSubmission!['submissionVersion'] - 1} time${(latestSubmission!['submissionVersion'] - 1) > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: 14,
                                ),
                              ),
                              if (latestSubmission!['resubmittedAt'] != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  'Last updated: ${_formatDateTime(latestSubmission!['resubmittedAt'])}',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Version Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  // Initial submission
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              'V1',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Initial Submission',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatDateTime(latestSubmission!['submittedAt']),
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
                  // Current version (if resubmitted)
                  if (latestSubmission!['resubmittedAt'] != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'V${latestSubmission!['submissionVersion']}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Version',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  _formatDateTime(latestSubmission!['resubmittedAt']),
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Latest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Submission History - Enhanced with letter grades (only if multiple separate submissions)
          if (submissionHistory.length > 1)
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
                      Icon(Icons.history, color: Colors.grey[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Submission History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'You have submitted ${submissionHistory.length} times',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
                  ...submissionHistory.asMap().entries.map((entry) {
                    final index = entry.key;
                    final submission = entry.value;
                    final isCurrent = index == 0;
                    final submissionGrade = submission['grade'];
                    final submissionLetterGrade = submission['letterGrade'];
                    final maxPoints = widget.assignmentData['points'] ?? 100;

                    // Calculate letter grade if not provided (backwards compatibility)
                    String displayLetter = submissionLetterGrade ?? '';
                    if (displayLetter.isEmpty && submissionGrade != null) {
                      final percentage = (submissionGrade / maxPoints) * 100;
                      displayLetter = _calculateLetterGrade(percentage);
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrent ? Colors.blue[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? Colors.blue[300]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Version number circle
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.blue[400] : Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${submission['submissionVersion'] ?? (submissionHistory.length - index)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDateTime(submission['submittedAt']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (submissionGrade != null)
                                  Row(
                                    children: [
                                      Text(
                                        'Grade: $submissionGrade/$maxPoints',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (displayLetter.isNotEmpty) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getGradeColor(displayLetter),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            displayLetter,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                if (submission['isLate'] == true)
                                  Text(
                                    'Late submission',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[400],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Latest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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

  Widget _buildRubricEvaluation() {
    final criteria = rubric!['criteria'] as List;
    final criteriaScores = evaluation!['criteriaScores'] as Map<String, dynamic>;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
              Icon(Icons.rule, color: Colors.purple[600], size: 24),
              SizedBox(width: 12),
              Text(
                'Rubric Evaluation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...criteria.map((criterion) {
            final criterionId = criterion['id'];
            final score = criteriaScores[criterionId];
            if (score == null) return SizedBox.shrink();

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
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
                          criterion['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${score['points']} pts',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Level: ${score['levelId']}',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (criterion['description'] != null &&
                      criterion['description'].toString().isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      criterion['description'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
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

  String _formatDateTime(dynamic timestamp) {
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
}