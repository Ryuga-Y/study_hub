import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';

class FeedbackHistoryPage extends StatefulWidget {
  final String courseId;
  final String organizationCode;
  final String? studentId; // Optional: filter by student
  final bool isStudent; // Whether current user is a student

  const FeedbackHistoryPage({
    Key? key,
    required this.courseId,
    required this.organizationCode,
    this.studentId,
    required this.isStudent,
  }) : super(key: key);

  @override
  _FeedbackHistoryPageState createState() => _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState extends State<FeedbackHistoryPage> {
  final AuthService _authService = AuthService();
  bool isLoading = true;
  List<Map<String, dynamic>> feedbackHistory = [];
  String? selectedAssignmentId;

  @override
  void initState() {
    super.initState();
    _loadFeedbackHistory();
  }

  Future<void> _loadFeedbackHistory() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Determine which student to load feedback for
      final targetStudentId = widget.isStudent ? user.uid : widget.studentId;

      if (targetStudentId == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get all assignments for the course
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> allFeedback = [];

      // For each assignment, get evaluations for the student
      for (var assignmentDoc in assignmentsSnapshot.docs) {
        final assignmentData = assignmentDoc.data();
        assignmentData['id'] = assignmentDoc.id;

        // Get submissions for this assignment by the student
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentDoc.id)
            .collection('submissions')
            .where('studentId', isEqualTo: targetStudentId)
            .orderBy('submittedAt', descending: true)
            .get();

        for (var submissionDoc in submissionsSnapshot.docs) {
          final submissionData = submissionDoc.data();

          // Get evaluation for this submission
          final evalDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(assignmentDoc.id)
              .collection('submissions')
              .doc(submissionDoc.id)
              .collection('evaluations')
              .doc('current')
              .get();

          if (evalDoc.exists) {
            final evalData = evalDoc.data()!;

            // Get evaluator name
            String evaluatorName = 'Unknown';
            if (evalData['evaluatorId'] != null) {
              final evaluatorDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(evalData['evaluatorId'])
                  .get();
              if (evaluatorDoc.exists) {
                evaluatorName = evaluatorDoc.data()?['fullName'] ?? 'Unknown';
              }
            }

            allFeedback.add({
              'assignmentId': assignmentDoc.id,
              'assignmentTitle': assignmentData['title'] as String,
              'assignmentPoints': (assignmentData['points'] as num? ?? 100),
              'submissionId': submissionDoc.id,
              'submittedAt': submissionData['submittedAt'],
              'evaluatedAt': evalData['evaluatedAt'],
              'grade': evalData['grade'] as num?,
              'totalScore': evalData['totalScore'] as num?,
              'feedback': evalData['feedback'] as String?,
              'privateNotes': widget.isStudent ? null : evalData['privateNotes'] as String?,
              'allowResubmission': evalData['allowResubmission'] as bool?,
              'rubricUsed': evalData['rubricUsed'] as bool?,
              'criteriaScores': evalData['criteriaScores'] as Map<String, dynamic>?,
              'evaluatorName': evaluatorName,
            });
          }
        }
      }

      setState(() {
        feedbackHistory = allFeedback;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading feedback history: $e');
      setState(() {
        isLoading = false;
      });
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

    // Get unique assignments
    final assignmentSet = feedbackHistory
        .map((f) => {'id': f['assignmentId'] as String, 'title': f['assignmentTitle'] as String})
        .toSet();
    final assignments = assignmentSet.toList();

    // Filter feedback by selected assignment
    final filteredFeedback = selectedAssignmentId == null
        ? feedbackHistory
        : feedbackHistory.where((f) => f['assignmentId'] == selectedAssignmentId).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Feedback History',
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
      ),
      body: Column(
        children: [
          // Filter by Assignment
          if (assignments.isNotEmpty)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedAssignmentId,
                  hint: Text('All Assignments'),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Assignments'),
                    ),
                    ...assignments.map((assignment) {
                      return DropdownMenuItem<String>(
                        value: assignment['id'] as String,
                        child: Text(assignment['title'] as String),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedAssignmentId = value;
                    });
                  },
                ),
              ),
            ),

          // Feedback List
          Expanded(
            child: filteredFeedback.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredFeedback.length,
              itemBuilder: (context, index) {
                return _buildFeedbackCard(filteredFeedback[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No feedback yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.isStudent
                ? 'Your graded assignments will appear here'
                : 'Student feedback will appear here',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final grade = (feedback['grade'] as num? ?? 0).toDouble();
    final maxPoints = (feedback['assignmentPoints'] as num? ?? 100).toDouble();
    final percentage = (grade / maxPoints * 100).toStringAsFixed(1);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(20),
        childrenPadding: EdgeInsets.all(20),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feedback['assignmentTitle'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Evaluated: ${_formatDate(feedback['evaluatedAt'])}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getGradeColor(percentage).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getGradeColor(percentage)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${grade.toInt()}/${maxPoints.toInt()}',
                style: TextStyle(
                  color: _getGradeColor(percentage),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: _getGradeColor(percentage),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        children: [
          // Rubric Scores
          if (feedback['rubricUsed'] == true && feedback['criteriaScores'] != null)
            _buildRubricScores(feedback['criteriaScores']),

          // Feedback
          if (feedback['feedback'] != null && feedback['feedback'].toString().isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.comment, color: Colors.blue[700], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Instructor Feedback',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    feedback['feedback'],
                    style: TextStyle(
                      color: Colors.blue[900],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Private Notes (for instructors only)
          if (!widget.isStudent &&
              feedback['privateNotes'] != null &&
              feedback['privateNotes'].toString().isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange[700], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Private Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    feedback['privateNotes'],
                    style: TextStyle(
                      color: Colors.orange[900],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Additional Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evaluated by: ${feedback['evaluatorName']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (feedback['allowResubmission'] == true)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Resubmission Allowed',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRubricScores(Map<String, dynamic> criteriaScores) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
            children: [
              Icon(Icons.rule, color: Colors.purple[700], size: 20),
              SizedBox(width: 8),
              Text(
                'Rubric Evaluation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...criteriaScores.entries.map((entry) {
            final score = entry.value as Map<String, dynamic>;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    score['levelId'] ?? 'Criterion',
                    style: TextStyle(color: Colors.purple[900]),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(score['points'] as num).toInt()} pts',
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
    );
  }

  Color _getGradeColor(String percentage) {
    final percent = double.tryParse(percentage) ?? 0.0;
    if (percent >= 90) return Colors.green[600]!;
    if (percent >= 80) return Colors.blue[600]!;
    if (percent >= 70) return Colors.orange[600]!;
    if (percent >= 60) return Colors.deepOrange[600]!;
    return Colors.red[600]!;
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

    return '${date.day}/${date.month}/${date.year}';
  }
}