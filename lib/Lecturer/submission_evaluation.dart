import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../notification.dart';

class SubmissionEvaluationPage extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String submissionId;
  final Map<String, dynamic> submissionData;
  final Map<String, dynamic> assignmentData;
  final String organizationCode;

  const SubmissionEvaluationPage({
    Key? key,
    required this.courseId,
    required this.assignmentId,
    required this.submissionId,
    required this.submissionData,
    required this.assignmentData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _SubmissionEvaluationPageState createState() => _SubmissionEvaluationPageState();
}

class _SubmissionEvaluationPageState extends State<SubmissionEvaluationPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  // Rubric data
  Map<String, dynamic>? rubric;
  Map<String, Map<String, dynamic>> criteriaScores = {};

  // Feedback data
  final _feedbackController = TextEditingController();
  final _privateNotesController = TextEditingController();

  // Submission history
  List<Map<String, dynamic>> submissionHistory = [];

  // Existing evaluation
  Map<String, dynamic>? existingEvaluation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    _privateNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load rubric
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
      }

      // Load existing evaluation
      final evalDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('evaluations')
          .doc('current')
          .get();

      if (evalDoc.exists) {
        existingEvaluation = evalDoc.data();
        _feedbackController.text = existingEvaluation!['feedback'] ?? '';
        _privateNotesController.text = existingEvaluation!['privateNotes'] ?? '';

        // Load existing scores
        if (existingEvaluation!['criteriaScores'] != null) {
          final scores = existingEvaluation!['criteriaScores'] as Map<String, dynamic>;
          scores.forEach((key, value) {
            criteriaScores[key] = Map<String, dynamic>.from(value);
          });
        }
      }

      // Load submission history
      await _loadSubmissionHistory();

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

  Future<void> _loadSubmissionHistory() async {
    try {
      // First try with orderBy
      try {
        final historySnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .where('studentId', isEqualTo: widget.submissionData['studentId'])
            .orderBy('submittedAt', descending: true)
            .get();

        if (mounted) {
          setState(() {
            submissionHistory = historySnapshot.docs.map((doc) {
              return {
                'id': doc.id,
                ...doc.data(),
              };
            }).toList();
          });
        }
      } catch (e) {
        // If orderBy fails, try without it and sort manually
        print('OrderBy failed, trying without ordering: $e');
        final historySnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .where('studentId', isEqualTo: widget.submissionData['studentId'])
            .get();

        final docs = historySnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();

        // Sort manually
        docs.sort((a, b) {
          final aTime = a['submittedAt'] as Timestamp?;
          final bTime = b['submittedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (mounted) {
          setState(() {
            submissionHistory = docs;
          });
        }
      }
    } catch (e) {
      print('Error loading submission history: $e');
    }
  }

  double _calculateTotalScore() {
    if (rubric == null) return 0;

    double totalScore = 0;
    final criteria = rubric!['criteria'] as List;

    for (var criterion in criteria) {
      final criterionId = criterion['id'];
      final weight = (criterion['weight'] ?? 0).toDouble();
      final score = criteriaScores[criterionId]?['points'] ?? 0;
      final maxPoints = (criterion['levels'] as List)
          .map((l) => l['points'] as int)
          .reduce((a, b) => a > b ? a : b);

      totalScore += (score / maxPoints) * weight;
    }

    return totalScore;
  }

  Future<void> _saveEvaluation({bool isDraft = true}) async {
    // Check if evaluation is already released
    if (existingEvaluation != null && existingEvaluation!['isReleased'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: 8),
              Text('This evaluation has been returned and cannot be modified'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      final totalScore = _calculateTotalScore();
      final totalPoints = widget.assignmentData['points'] ?? 100;
      final grade = (totalScore * totalPoints / 100).round();

      // Calculate percentage and letter grade
      final percentage = (grade / totalPoints) * 100;
      final letterGrade = _calculateLetterGrade(percentage);

      // Ensure we have a valid studentId
      String studentId = widget.submissionData['studentId']?.toString() ?? '';
      if (studentId.isEmpty) {
        // Try to fetch from submission document
        final submissionDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .doc(widget.submissionId)
            .get();

        if (!submissionDoc.exists) {
          throw Exception('Submission document not found');
        }

        // Extract studentId from the submission document
        final submissionData = submissionDoc.data();
        studentId = submissionData?['studentId']?.toString() ?? '';

        if (studentId.isEmpty) {
          throw Exception('Student ID not found in submission document');
        }
      }

      final evaluationData = {
        'submissionId': widget.submissionId,
        'studentId': studentId,
        'studentName': widget.submissionData['studentName']?.toString() ?? '',
        'studentEmail': widget.submissionData['studentEmail']?.toString() ?? '',
        'assignmentId': widget.assignmentId,
        'courseId': widget.courseId,
        'evaluatorId': FirebaseAuth.instance.currentUser?.uid,
        'evaluatedAt': FieldValue.serverTimestamp(),
        'grade': grade,
        'letterGrade': letterGrade,
        'percentage': percentage,
        'totalScore': totalScore,
        'maxPoints': totalPoints,
        'criteriaScores': criteriaScores,
        'feedback': _feedbackController.text.trim(),
        'privateNotes': _privateNotesController.text.trim(),
        'rubricUsed': rubric != null,
        'isDraft': isDraft,  // NEW: Track if evaluation is draft
        'isReleased': !isDraft,  // NEW: Track if released to student
        'releasedAt': isDraft ? null : FieldValue.serverTimestamp(),  // NEW: Track release time
      };

      // Save to evaluations subcollection
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('evaluations')
          .doc('current')
          .set(evaluationData);

// Update submission - only update visible fields if not draft
      final updateData = <String, dynamic>{
        'gradedAt': FieldValue.serverTimestamp(),
        'gradedBy': FirebaseAuth.instance.currentUser?.uid,
        'status': isDraft ? 'evaluated_draft' : 'completed',
        'hasEvaluation': true,
        'evaluationIsDraft': isDraft,
      };

// Only add grade data if not draft (released to student)
      if (!isDraft) {
        updateData.addAll({
          'grade': grade,
          'letterGrade': letterGrade,
          'percentage': percentage,
          'feedback': _feedbackController.text.trim(),
          'isReleased': true,
        });
      }

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
          .update(updateData);

      // 🔔 FIXED: Send notification to student when evaluation is returned (not draft)
      if (!isDraft) {
        try {
          // Ensure studentId is valid
          // Use the already validated studentId
          if (studentId.isEmpty) {
            throw Exception('Student ID not found for notification');
          }

          await _createEvaluationNotification(
            studentId: studentId,
            assignmentTitle: widget.assignmentData['title'] ?? 'Assignment',
            grade: grade,
            totalPoints: totalPoints,
            letterGrade: letterGrade,
          );

          print('✅ Evaluation notification sent to student: $studentId');
        } catch (e) {
          print('❌ Error sending evaluation notification: $e');
          // Don't fail the evaluation save if notification fails
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDraft
                ? 'Evaluation saved as draft. Remember to return it to the student!'
                : 'Evaluation saved and returned to student'),
            backgroundColor: isDraft ? Colors.orange : Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving evaluation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving evaluation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _releaseEvaluation() async {
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
            Text('Return to Student'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to return this evaluation to the student?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
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
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Once returned:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• Student will see their grade and feedback',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                  Text('• You can still edit the evaluation later',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                  Text('• Student will receive a notification',
                      style: TextStyle(fontSize: 13, color: Colors.blue[700])),
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
                Text('Return to Student', style: TextStyle(color: Colors.white)),
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
      // Get current evaluation data
      final evalDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
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
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
          .collection('evaluations')
          .doc('current')
          .update({
        'isDraft': false,
        'isReleased': true,
        'releasedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .doc(widget.assignmentId)
          .collection('submissions')
          .doc(widget.submissionId)
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

// 🔔 NEW: Send notification to student when evaluation is returned
      try {
        String studentId = evalData['studentId']?.toString() ?? '';

        // If studentId is not in evalData, get it from submission data
        if (studentId.isEmpty) {
          studentId = widget.submissionData['studentId']?.toString() ?? '';
        }

        // If still empty, fetch from submission document
        if (studentId.isEmpty) {
          final submissionDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(widget.assignmentId)
              .collection('submissions')
              .doc(widget.submissionId)
              .get();

          if (submissionDoc.exists) {
            final submissionData = submissionDoc.data();
            studentId = submissionData?['studentId']?.toString() ?? '';
          }
        }

        print('🔔 DEBUG: Attempting to send notification to student: $studentId');
        print('🔔 DEBUG: Organization code: ${widget.organizationCode}');
        print('🔔 DEBUG: Assignment title: ${widget.assignmentData['title']}');

        if (studentId.isNotEmpty) {
          await _createEvaluationNotification(
            studentId: studentId,
            assignmentTitle: widget.assignmentData['title'] ?? 'Assignment',
            grade: evalData['grade'] ?? 0,
            totalPoints: evalData['maxPoints'] ?? 100,
            letterGrade: evalData['letterGrade'] ?? '',
          );
        } else {
          print('❌ Cannot send notification: Student ID is empty');
        }
      } catch (e) {
        print('Error sending evaluation notification: $e');
        // Don't fail the release if notification fails
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Evaluation returned to student successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error releasing evaluation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

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

  Future<void> _clearEvaluation() async {
    // Check if evaluation is already released
    if (existingEvaluation != null && existingEvaluation!['isReleased'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: 8),
              Text('Cannot clear a returned evaluation'),
            ],
          ),
          backgroundColor: Colors.red,
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
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Clear Evaluation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to clear this evaluation?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text('Remove the grade (${existingEvaluation?['grade'] ?? 0}/${widget.assignmentData['points'] ?? 100})'),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text('Delete all feedback and rubric scores'),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text('Reset submission status to "Submitted"'),
                ),
              ],
            ),
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
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The student will need to wait for re-evaluation.',
                      style: TextStyle(
                        color: Colors.orange[800],
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
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Clear Evaluation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        isLoading = true;
      });

      try {
        // Delete evaluation
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .doc(widget.submissionId)
            .collection('evaluations')
            .doc('current')
            .delete();

        // Update submission status - FIXED: Added letterGrade and percentage
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(widget.assignmentId)
            .collection('submissions')
            .doc(widget.submissionId)
            .update({
          'grade': null,
          'letterGrade': null,           // ADDED: Clear letter grade
          'percentage': null,            // ADDED: Clear percentage
          'feedback': null,
          'gradedAt': null,
          'gradedBy': null,
          'status': 'submitted',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluation cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing evaluation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
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

    // Fixed null safety issue
    final studentName = widget.submissionData['studentName'] ?? 'Unknown Student';
    final studentInitial = studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Evaluate Submission',
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
          // Show different buttons based on evaluation state
          if (existingEvaluation != null && existingEvaluation!['isReleased'] == true) ...[
            // Evaluation is already released - show read-only indicator
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.green[700]),
                    SizedBox(width: 4),
                    Text(
                      'Returned',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (existingEvaluation != null && existingEvaluation!['isDraft'] == true) ...[
            // Draft exists - show Return button
            TextButton.icon(
              onPressed: _releaseEvaluation,
              icon: Icon(Icons.send),
              label: Text('Return to Student'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green[600],
                backgroundColor: Colors.green[50],
                padding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _saveEvaluation(isDraft: true),
              icon: Icon(Icons.save),
              label: Text('Update Draft'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange[600],
              ),
            ),
          ] else ...[
            // No evaluation yet - show Save buttons
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'save_draft') {
                  _saveEvaluation(isDraft: true);
                } else if (value == 'save_return') {
                  _saveEvaluation(isDraft: false);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'save_draft',
                  child: Row(
                    children: [
                      Icon(Icons.save, color: Colors.orange[600], size: 20),
                      SizedBox(width: 8),
                      Text('Save as Draft'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'save_return',
                  child: Row(
                    children: [
                      Icon(Icons.send, color: Colors.green[600], size: 20),
                      SizedBox(width: 8),
                      Text('Save & Return'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.purple[600]),
                    SizedBox(width: 4),
                    Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.purple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.purple[600]),
                  ],
                ),
              ),
            ),
          ],
          // Only show clear option for non-released evaluations
          if (existingEvaluation != null && existingEvaluation!['isReleased'] != true)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _clearEvaluation();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Clear Evaluation'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Show locked banner if evaluation is released
          if (existingEvaluation != null && existingEvaluation!['isReleased'] == true)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.green[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This evaluation has been returned to the student (Read-Only)',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // Student Info Header with Submission Timing Info
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple[400],
                      child: Text(
                        studentInitial,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Email: ${widget.submissionData['studentEmail'] ?? 'No email'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Current Score',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${_calculateTotalScore().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[600],
                          ),
                        ),
                        // Show predicted letter grade
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getGradeColor(_calculateLetterGrade(_calculateTotalScore())),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _calculateLetterGrade(_calculateTotalScore()),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Submission Timing Information
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.purple[600], size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submission Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'Version',
                              '${widget.submissionData['submissionVersion'] ?? _getSubmissionVersionNumber()} of ${submissionHistory.length}',
                              Icons.layers,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              'Status',
                              widget.submissionData['isLate'] == true ? 'Late' : 'On Time',
                              widget.submissionData['isLate'] == true ? Icons.warning : Icons.check_circle,
                              widget.submissionData['isLate'] == true ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoChip(
                              'Submitted',
                              _formatDateTime(widget.submissionData['submittedAt']),
                              Icons.access_time,
                              Colors.orange,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoChip(
                              'Due Date',
                              _formatDateTime(widget.assignmentData['dueDate']),
                              Icons.calendar_today,
                              Colors.grey,
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
                Tab(text: 'Rubric'),
                Tab(text: 'Feedback'),
                Tab(text: 'Submission'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRubricTab(),
                _buildFeedbackTab(),
                _buildSubmissionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  int _getSubmissionVersionNumber() {
    // Find the position of current submission in sorted history
    for (int i = 0; i < submissionHistory.length; i++) {
      if (submissionHistory[i]['id'] == widget.submissionId) {
        return submissionHistory.length - i;
      }
    }
    return 1;
  }

  Widget _buildRubricTab() {
    final isReleased = existingEvaluation != null && existingEvaluation!['isReleased'] == true;

    if (rubric == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No rubric defined for this assignment',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'You can still provide feedback and assign a grade',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final criteria = rubric!['criteria'] as List;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Show lock banner if evaluation is released
          if (isReleased) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.green[600]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluation Locked',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'This evaluation has been returned to the student and cannot be modified.',
                          style: TextStyle(
                            color: Colors.green[600],
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
          // Show rubric criteria
          ...criteria.map((criterion) {
            return _buildCriterionEvaluation(criterion, isReadOnly: isReleased);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCriterionEvaluation(Map<String, dynamic> criterion, {bool isReadOnly = false}) {
    final criterionId = criterion['id'];
    final levels = criterion['levels'] as List;
    final selectedLevel = criteriaScores[criterionId];

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
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterion['name'] ?? 'Criterion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (criterion['description'] != null &&
                          criterion['description'].toString().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            criterion['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${criterion['weight'] ?? 0}%',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...levels.map((level) {
              final isSelected = selectedLevel?['levelId'] == level['name'];
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: isReadOnly ? null : () {
                    setState(() {
                      criteriaScores[criterionId] = {
                        'levelId': level['name'],
                        'points': level['points'],
                      };
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isReadOnly ? Colors.green[50] : Colors.purple[50])
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? (isReadOnly ? Colors.green[400]! : Colors.purple[400]!)
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: level['name'],
                          groupValue: selectedLevel?['levelId'],
                          onChanged: (existingEvaluation != null && existingEvaluation!['isReleased'] == true)
                              ? null  // This disables the radio button
                              : (value) {
                            setState(() {
                              criteriaScores[criterionId] = {
                                'levelId': value,
                                'points': level['points'],
                              };
                            });
                          },
                          activeColor: Colors.purple[400],
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    level['name'] ?? 'Level',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? (isReadOnly ? Colors.green[700] : Colors.purple[700])
                                          : null,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isReadOnly ? Colors.green[400] : Colors.purple[400])
                                          : Colors.grey[400],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${level['points'] ?? 0} pts',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (level['description'] != null &&
                                  level['description'].toString().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    level['description'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
    );
  }

  Widget _buildFeedbackTab() {
    final isReleased = existingEvaluation != null && existingEvaluation!['isReleased'] == true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show lock banner if evaluation is released
          if (isReleased) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, color: Colors.green[600]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback Locked',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'This evaluation has been returned to the student and cannot be modified.',
                          style: TextStyle(
                            color: Colors.green[600],
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
          // Student Feedback
          Container(
            padding: EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.comment, color: Colors.blue[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Feedback for Student',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isReleased) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Visible to Student',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _feedbackController,
                  maxLines: 6,
                  readOnly: isReleased,
                  decoration: InputDecoration(
                    hintText: isReleased
                        ? 'Feedback has been sent to student'
                        : 'Provide constructive feedback for the student...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isReleased ? Colors.green[400]! : Colors.blue[400]!,
                          width: 2
                      ),
                    ),
                    filled: isReleased,
                    fillColor: isReleased ? Colors.grey[100] : null,
                  ),
                  style: TextStyle(
                    color: isReleased ? Colors.grey[700] : null,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Private Notes
          Container(
            padding: EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, color: Colors.orange[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Private Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Lecturer Only',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _privateNotesController,
                  maxLines: 4,
                  readOnly: isReleased,
                  decoration: InputDecoration(
                    hintText: isReleased
                        ? 'Private notes (locked)'
                        : 'Notes only visible to Lecturer...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isReleased ? Colors.green[400]! : Colors.orange[400]!,
                          width: 2
                      ),
                    ),
                    filled: isReleased,
                    fillColor: isReleased ? Colors.grey[100] : null,
                  ),
                  style: TextStyle(
                    color: isReleased ? Colors.grey[700] : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTab() {
    final submittedAt = widget.submissionData['submittedAt'] as Timestamp?;
    final fileName = widget.submissionData['fileName'] ?? 'Submission';
    final fileUrl = widget.submissionData['fileUrl'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Submission Details
          Container(
            padding: EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Submission Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildDetailRow(
                  'Submitted',
                  _formatDateTime(submittedAt),
                  Icons.access_time,
                ),
                _buildDetailRow(
                  'Version',
                  'Version ${widget.submissionData['submissionVersion'] ?? _getSubmissionVersionNumber()} of ${submissionHistory.length}',
                  Icons.history,
                ),
                if (widget.submissionData['isLate'] == true)
                  _buildDetailRow(
                    'Status',
                    'Late Submission',
                    Icons.warning,
                  ),
                if (widget.submissionData['isResubmission'] == true)
                  _buildDetailRow(
                    'Type',
                    'Resubmission',
                    Icons.refresh,
                  ),
                if (fileUrl != null)
                  InkWell(
                    onTap: () => _launchUrl(fileUrl),
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
                            _getFileIcon(fileName),
                            color: Colors.purple[600],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName,
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

          // Submission History
          Container(
            padding: EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue[600], size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Submission History (${submissionHistory.length} total)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...submissionHistory.map((submission) {
                  final isCurrent = submission['id'] == widget.submissionId;
                  final isLate = submission['isLate'] == true;
                  final isResubmission = submission['isResubmission'] == true;

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
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isCurrent ? Colors.blue[400] : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${submission['submissionVersion'] ?? (submissionHistory.length - submissionHistory.indexOf(submission))}',
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
                              Row(
                                children: [
                                  Text(
                                    _formatDateTime(submission['submittedAt']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isLate) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'LATE',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isResubmission) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'RESUBMIT',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (submission['grade'] != null)
                                Text(
                                  'Grade: ${submission['grade']}/${widget.assignmentData['points'] ?? 100}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
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
                              'Current',
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String letterGrade) {
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

    if (difference.inDays == 0) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else {
      return '$dateStr at $timeStr';
    }
  }

  // 🔔 NEW: Create notification for student when evaluation is returned
  Future<void> _createEvaluationNotification({
    required String studentId,
    required String assignmentTitle,
    required int grade,
    required int totalPoints,
    required String letterGrade,
  }) async {
    try {
      print('🔔 Creating evaluation notification for student: $studentId');
      print('📍 Path: organizations/${widget.organizationCode}/students/$studentId/notifications');

      // Verify lecturer permissions first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Lecturer not authenticated');
      }

      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('students')
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': '📝 Assignment Graded',
        'body': 'Your assignment "$assignmentTitle" has been graded: $grade/$totalPoints ($letterGrade)',
        'type': 'NotificationType.assignment',
        'sourceId': widget.assignmentId,
        'sourceType': 'assignment',
        'courseId': widget.courseId, // CRITICAL: Required for Firebase rules
        'courseName': widget.assignmentData['courseName'] ?? 'Course',
        'organizationCode': widget.organizationCode,
        'lecturerId': currentUser.uid, // ADDED: For permission verification
        'assignmentTitle': assignmentTitle, // ADDED: For better context
        'grade': grade,
        'totalPoints': totalPoints,
        'letterGrade': letterGrade,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'notificationCategory': 'evaluation', // ADDED: For filtering
      });

      print('✅ Created evaluation notification for student: $studentId');
      print('📧 Notification details: Assignment "$assignmentTitle" graded $grade/$totalPoints ($letterGrade)');
      print('📍 Notification path: organizations/${widget.organizationCode}/students/$studentId/notifications');
    } catch (e) {
      print('❌ Error creating evaluation notification: $e');
      throw e;
    }
  }
}