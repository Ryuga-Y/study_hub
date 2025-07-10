import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _allowResubmission = false;

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
        _allowResubmission = existingEvaluation!['allowResubmission'] ?? false;

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

  Future<void> _saveEvaluation() async {
    setState(() {
      isLoading = true;
    });

    try {
      final totalScore = _calculateTotalScore();
      final totalPoints = widget.assignmentData['points'] ?? 100;
      final grade = (totalScore * totalPoints / 100).round();

      final evaluationData = {
        'submissionId': widget.submissionId,
        'studentId': widget.submissionData['studentId'],
        'assignmentId': widget.assignmentId,
        'courseId': widget.courseId,
        'evaluatorId': FirebaseAuth.instance.currentUser?.uid,
        'evaluatedAt': FieldValue.serverTimestamp(),
        'grade': grade,
        'totalScore': totalScore,
        'maxPoints': totalPoints,
        'criteriaScores': criteriaScores,
        'feedback': _feedbackController.text.trim(),
        'privateNotes': _privateNotesController.text.trim(),
        'allowResubmission': _allowResubmission,
        'rubricUsed': rubric != null,
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

      // Update submission with grade and feedback
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
        'grade': grade,
        'feedback': _feedbackController.text.trim(),
        'gradedAt': FieldValue.serverTimestamp(),
        'gradedBy': FirebaseAuth.instance.currentUser?.uid,
        'status': 'graded',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
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

  // Add ability to clear/reset evaluation
  Future<void> _clearEvaluation() async {
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

        // Update submission status
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
          TextButton.icon(
            onPressed: _saveEvaluation,
            icon: Icon(Icons.save),
            label: Text('Save Evaluation'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.purple[600],
            ),
          ),
          // Show clear button only if evaluation exists
          if (existingEvaluation != null)
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
          // Student Info Header
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Row(
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

  Widget _buildRubricTab() {
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
        children: criteria.map((criterion) {
          return _buildCriterionEvaluation(criterion);
        }).toList(),
      ),
    );
  }

  Widget _buildCriterionEvaluation(Map<String, dynamic> criterion) {
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
                  onTap: () {
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
                      color: isSelected ? Colors.purple[50] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.purple[400]! : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: level['name'],
                          groupValue: selectedLevel?['levelId'],
                          onChanged: (value) {
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
                                      color: isSelected ? Colors.purple[700] : null,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.purple[400] : Colors.grey[400],
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  ],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _feedbackController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Provide constructive feedback for the student...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                    ),
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
                        'Instructor Only',
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
                  decoration: InputDecoration(
                    hintText: 'Notes only visible to instructors...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Options
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
                Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                CheckboxListTile(
                  title: Text('Allow Resubmission'),
                  subtitle: Text('Student can submit an updated version'),
                  value: _allowResubmission,
                  onChanged: (value) {
                    setState(() {
                      _allowResubmission = value ?? false;
                    });
                  },
                  activeColor: Colors.purple[400],
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
                  'Version ${submissionHistory.indexOf(submissionHistory.firstWhere((s) => s['id'] == widget.submissionId, orElse: () => {'id': ''})) + 1} of ${submissionHistory.length}',
                  Icons.history,
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
                      'Submission History',
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
                              '${submissionHistory.indexOf(submission) + 1}',
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
}