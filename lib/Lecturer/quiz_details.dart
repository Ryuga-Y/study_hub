import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';
import 'create_material.dart'; // Import the CreateMaterialPage

class QuizDetailPage extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final String courseId;
  final Map<String, dynamic> courseData;
  final bool isLecturer;

  const QuizDetailPage({
    Key? key,
    required this.quiz,
    required this.courseId,
    required this.courseData,
    required this.isLecturer,
  }) : super(key: key);

  @override
  _QuizDetailPageState createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late Map<String, dynamic> quizData;
  late TabController _tabController;
  bool isLoading = true;
  String? organizationCode;
  List<Map<String, dynamic>> submissions = [];
  Map<String, dynamic> quizStatistics = {};

  @override
  void initState() {
    super.initState();
    quizData = Map<String, dynamic>.from(widget.quiz);
    _tabController = TabController(length: widget.isLecturer ? 3 : 1, vsync: this);
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
      if (user != null) {
        print('👤 Loading data for user: ${user.uid}');
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          organizationCode = userData['organizationCode'];
          print('🏢 Organization code loaded: $organizationCode');
          print('📊 Course data keys: ${widget.courseData.keys.toList()}');

          if (widget.isLecturer) {
            // Load submissions first, then calculate statistics
            await _loadSubmissions();
            await _calculateStatistics();
          }
        } else {
          print('❌ User data not found');
        }
      } else {
        print('❌ No authenticated user found');
      }
    } catch (e) {
      print('❌ Error loading data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      print('✅ Data loading completed. Organization code: $organizationCode');
    }
  }

  Future<void> _loadSubmissions() async {
    if (organizationCode == null) {
      print('❌ Organization code is null - cannot load submissions');
      return;
    }

    try {
      print('🔍 Loading submissions for quiz: ${quizData['id']}');
      print('📍 Path: organizations/$organizationCode/courses/${widget.courseId}/materials/${quizData['id']}/submissions');

      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(quizData['id'])
          .collection('submissions')
          .orderBy('submittedAt', descending: true)
          .get();

      print('📊 Found ${submissionsSnapshot.docs.length} submissions');

      List<Map<String, dynamic>> loadedSubmissions = [];

      for (var doc in submissionsSnapshot.docs) {
        final submissionData = doc.data();
        print('📝 Processing submission: ${doc.id} by student: ${submissionData['studentId']}');

        // Get student details
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(submissionData['studentId'])
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data()!;
          loadedSubmissions.add({
            'id': doc.id,
            ...submissionData,
            'studentName': studentData['fullName'] ?? 'Unknown Student',
            'studentEmail': studentData['email'] ?? '',
          });
          print('✅ Added submission for: ${studentData['fullName']}');
        } else {
          print('⚠️ Student document not found for: ${submissionData['studentId']}');
          // Still add the submission but with unknown student info
          loadedSubmissions.add({
            'id': doc.id,
            ...submissionData,
            'studentName': 'Unknown Student',
            'studentEmail': '',
          });
        }
      }

      setState(() {
        submissions = loadedSubmissions;
      });

      print('✅ Successfully loaded ${loadedSubmissions.length} submissions');
    } catch (e) {
      print('❌ Error loading submissions: $e');
      setState(() {
        submissions = [];
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });

    await _loadData();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _calculateStatistics() async {
    print('📊 Calculating statistics for ${submissions.length} submissions...');

    if (submissions.isEmpty) {
      print('📊 No submissions found - setting empty statistics');
      setState(() {
        quizStatistics = {
          'totalSubmissions': 0,
          'averageScore': 0.0,
          'highestScore': 0.0,
          'lowestScore': 0.0,
          'completionRate': 0.0,
          'onTimeSubmissions': 0,
          'lateSubmissions': 0,
          'totalPoints': quizData['totalPoints'] ?? 0,
          'totalEnrolledStudents': 0,
        };
      });
      return;
    }

    try {
      final totalPoints = quizData['totalPoints'] ?? 1;
      final scores = submissions.map((s) => (s['score'] ?? 0).toDouble()).toList();
      final dueDate = quizData['dueDate'] as Timestamp?;

      int onTimeCount = 0;
      int lateCount = 0;

      for (var submission in submissions) {
        final submittedAt = submission['submittedAt'] as Timestamp?;
        if (dueDate != null && submittedAt != null) {
          if (submittedAt.toDate().isBefore(dueDate.toDate()) || submittedAt.toDate().isAtSameMomentAs(dueDate.toDate())) {
            onTimeCount++;
          } else {
            lateCount++;
          }
        } else {
          // If no due date, consider all submissions as on time
          onTimeCount++;
        }
      }

      // Get actual enrollment count
      final totalEnrolledStudents = await _getTotalEnrolledStudents();
      final completionRate = totalEnrolledStudents > 0
          ? (submissions.length / totalEnrolledStudents) * 100
          : 0.0;

      print('📊 Statistics calculated:');
      print('   Total submissions: ${submissions.length}');
      print('   Total enrolled: $totalEnrolledStudents');
      print('   Completion rate: ${completionRate.toStringAsFixed(1)}%');
      print('   Average score: ${scores.isNotEmpty ? (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1) : 0}');

      setState(() {
        quizStatistics = {
          'totalSubmissions': submissions.length,
          'averageScore': scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length,
          'highestScore': scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b),
          'lowestScore': scores.isEmpty ? 0.0 : scores.reduce((a, b) => a < b ? a : b),
          'completionRate': completionRate,
          'onTimeSubmissions': onTimeCount,
          'lateSubmissions': lateCount,
          'totalPoints': totalPoints,
          'totalEnrolledStudents': totalEnrolledStudents,
        };
      });
    } catch (e) {
      print('❌ Error calculating statistics: $e');
      setState(() {
        quizStatistics = {
          'totalSubmissions': submissions.length,
          'averageScore': 0.0,
          'highestScore': 0.0,
          'lowestScore': 0.0,
          'completionRate': 0.0,
          'onTimeSubmissions': 0,
          'lateSubmissions': 0,
          'totalPoints': quizData['totalPoints'] ?? 0,
          'totalEnrolledStudents': 0,
        };
      });
    }
  }

  Future<int> _getTotalEnrolledStudents() async {
    if (organizationCode == null) return 0;

    try {
      final enrollmentSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      print('📊 Total enrolled students: ${enrollmentSnapshot.docs.length}');
      return enrollmentSnapshot.docs.length;
    } catch (e) {
      print('❌ Error getting total enrolled students: $e');
      return 0; // Return 0 if we can't get the count
    }
  }

  // NEW METHOD: Navigate to edit quiz
  Future<void> _editQuiz() async {
    print('✏️ Navigating to edit quiz: ${quizData['title']}');

    if (organizationCode == null) {
      print('❌ Organization code not available for editing');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to edit quiz: Organization data not loaded'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Create enhanced courseData with organizationCode
      final enhancedCourseData = Map<String, dynamic>.from(widget.courseData);
      enhancedCourseData['organizationCode'] = organizationCode;

      print('🔧 Enhanced courseData with organizationCode: $organizationCode');
      print('📝 CourseData keys: ${enhancedCourseData.keys.toList()}');

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateMaterialPage(
            courseId: widget.courseId,
            courseData: enhancedCourseData, // Use enhanced courseData
            editMode: true,
            materialId: quizData['id'],
            materialData: quizData,
          ),
        ),
      );

      // If the quiz was updated, refresh the data
      if (result == true) {
        print('✅ Quiz was updated, refreshing data...');
        await _refreshQuizData();
      }
    } catch (e) {
      print('❌ Error navigating to edit quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening quiz editor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NEW METHOD: Refresh quiz data after edit
  Future<void> _refreshQuizData() async {
    if (organizationCode == null) {
      print('❌ Organization code is null - cannot refresh quiz data');
      return;
    }

    try {
      print('🔄 Refreshing quiz data...');

      final quizDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(quizData['id'])
          .get();

      if (quizDoc.exists) {
        setState(() {
          quizData = {
            'id': quizDoc.id,
            ...quizDoc.data()!,
          };
        });
        print('✅ Quiz data refreshed');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quiz updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('⚠️ Quiz document no longer exists');
      }
    } catch (e) {
      print('❌ Error refreshing quiz data: $e');
    }
  }

  // NEW METHOD: Show edit confirmation if there are submissions
  Future<void> _showEditConfirmation() async {
    // Check if organization code is available
    if (organizationCode == null) {
      print('⚠️ Organization code not loaded - cannot edit quiz');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait for data to load before editing'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (submissions.isEmpty) {
      // No submissions, allow direct edit
      await _editQuiz();
      return;
    }

    // Show warning dialog if there are submissions
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Edit Quiz?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This quiz has ${submissions.length} submission${submissions.length > 1 ? 's' : ''}.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Editing the quiz may affect:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 4),
            Text('• Student scores and rankings', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text('• Quiz statistics and reports', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text('• Existing submissions data', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to continue?',
              style: TextStyle(fontWeight: FontWeight.w500),
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
              foregroundColor: Colors.white,
            ),
            child: Text('Edit Anyway'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _editQuiz();
    }
  }

  Future<void> _showSubmissionDetails(Map<String, dynamic> submission) async {
    final questions = quizData['questions'] as List<dynamic>? ?? [];
    final answers = submission['answers'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.all(24),
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
                          'Quiz Submission Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${submission['studentName']} • Score: ${submission['score']}/${quizData['totalPoints']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
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
              SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    final answer = index < answers.length ? answers[index] : null;
                    final isCorrect = answer != null && answer['selectedAnswer'] == question['correctAnswerIndex'];

                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCorrect ? Colors.green[300]! : Colors.red[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple[600],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Q${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question['question'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCorrect ? '${question['points']} pts' : '0 pts',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          // Options
                          ...(question['options'] as List<dynamic>).asMap().entries.map((optionEntry) {
                            final optionIndex = optionEntry.key;
                            final option = optionEntry.value;
                            final isCorrectOption = optionIndex == question['correctAnswerIndex'];
                            final isSelectedOption = answer != null && answer['selectedAnswer'] == optionIndex;

                            Color optionColor = Colors.grey[100]!;
                            Color textColor = Colors.grey[700]!;
                            Icon? optionIcon;

                            if (isCorrectOption) {
                              optionColor = Colors.green[100]!;
                              textColor = Colors.green[700]!;
                              optionIcon = Icon(Icons.check_circle, color: Colors.green, size: 16);
                            } else if (isSelectedOption && !isCorrectOption) {
                              optionColor = Colors.red[100]!;
                              textColor = Colors.red[700]!;
                              optionIcon = Icon(Icons.cancel, color: Colors.red, size: 16);
                            }

                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: optionColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCorrectOption ? Colors.green[300]! :
                                  (isSelectedOption ? Colors.red[300]! : Colors.grey[300]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[400]!),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + optionIndex),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: isCorrectOption || isSelectedOption ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (optionIcon != null) optionIcon,
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Submitted: ${_formatDateTime(submission['submittedAt'] as Timestamp?)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    final dueDate = quizData['dueDate'] as Timestamp?;
    final questions = quizData['questions'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Quiz Details',
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
        // NEW: Add edit button for lecturers
        actions: (widget.isLecturer && organizationCode != null) ? [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.purple[600]),
            onPressed: _showEditConfirmation,
            tooltip: 'Edit Quiz',
          ),
          SizedBox(width: 8),
        ] : null,
      ),
      body: Column(
        children: [
          // Quiz Header
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade400],
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.psychology, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Quiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dueDate != null) ...[
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
                            Icon(Icons.calendar_today, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Due: ${_formatDate(dueDate)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // NEW: Add edit button in header for better visibility
                    if (widget.isLecturer && organizationCode != null) ...[
                      Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit, color: Colors.white, size: 20),
                          onPressed: _showEditConfirmation,
                          tooltip: 'Edit Quiz',
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  quizData['title'] ?? 'Quiz',
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
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuizStat('Questions', '${questions.length}', Icons.quiz),
                      SizedBox(width: 16),
                      _buildQuizStat('Points', '${quizData['totalPoints'] ?? 0}', Icons.star),
                      SizedBox(width: 16),
                      _buildQuizStat('Time Limit', '${quizData['timeLimit'] ?? 30}m', Icons.timer),
                    ],
                  ),
                )
              ],
            ),
          ),

          // Tab Bar (only for lecturers)
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
                indicatorColor: Colors.purple[400],
                indicatorWeight: 3,
                labelColor: Colors.purple[600],
                unselectedLabelColor: Colors.grey[600],
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Questions'),
                  Tab(text: 'Submissions (${submissions.length})'),
                  Tab(text: 'Statistics'),
                ],
              ),
            ),

          // Tab Content
          Expanded(
            child: widget.isLecturer
                ? TabBarView(
              controller: _tabController,
              children: [
                _buildQuestionsTab(),
                _buildSubmissionsTab(),
                _buildStatisticsTab(),
              ],
            )
                : _buildQuestionsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
        SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsTab() {
    final questions = quizData['questions'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz Settings Card
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
                    Text(
                      'Quiz Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[600],
                      ),
                    ),
                    // NEW: Additional edit button in settings section
                    if (widget.isLecturer && organizationCode != null)
                      TextButton.icon(
                        onPressed: _showEditConfirmation,
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.purple[600],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildSettingItem('Time Limit', '${quizData['timeLimit'] ?? 30} minutes')),
                    Expanded(child: _buildSettingItem('Max Attempts', '${quizData['maxAttempts'] ?? 1}')),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSettingItem('Late Submission', quizData['allowLateSubmission'] == true ? 'Allowed' : 'Not Allowed')),
                    Expanded(child: _buildSettingItem('Show Results', quizData['showResultsImmediately'] == true ? 'Immediately' : 'Manual')),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Questions List
          if (questions.isNotEmpty) ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;

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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Question ${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${question['points']} point${question['points'] > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    question['question'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  ...(question['options'] as List<dynamic>).asMap().entries.map((optionEntry) {
                    final optionIndex = optionEntry.key;
                    final option = optionEntry.value;
                    final isCorrect = optionIndex == question['correctAnswerIndex'];

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrect ? Colors.green[300]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCorrect ? Colors.green[100] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCorrect ? Colors.green : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + optionIndex),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? Colors.green[700] : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                color: isCorrect ? Colors.green[700] : Colors.grey[700],
                              ),
                            ),
                          ),
                          if (isCorrect)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
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
              'Students haven\'t taken the quiz',
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
        final score = submission['score'] ?? 0;
        final totalPoints = quizData['totalPoints'] ?? 1;
        final percentage = (score / totalPoints * 100).round();
        final isLate = _isLateSubmission(submission['submittedAt'] as Timestamp?);

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
            onTap: () => _showSubmissionDetails(submission),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
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
                  SizedBox(width: 16),
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
                        SizedBox(height: 4),
                        Text(
                          'Submitted: ${_formatDateTime(submission['submittedAt'] as Timestamp?)}',
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getScoreColor(percentage).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getScoreColor(percentage)),
                        ),
                        child: Text(
                          '$score/$totalPoints ($percentage%)',
                          style: TextStyle(
                            color: _getScoreColor(percentage),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (isLate) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Late',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Overall Statistics
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
                      Text(
                        'Quiz Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[600],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.purple[600]),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Statistics',
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Submissions',
                          '${quizStatistics['totalSubmissions'] ?? 0}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Average Score',
                          '${(quizStatistics['averageScore'] ?? 0.0).toStringAsFixed(1)}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Completion Rate',
                          '${(quizStatistics['completionRate'] ?? 0.0).toStringAsFixed(1)}%',
                          Icons.analytics,
                          Colors.orange,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'On Time',
                          '${quizStatistics['onTimeSubmissions'] ?? 0}',
                          Icons.schedule,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Additional info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Enrolled Students:', style: TextStyle(color: Colors.grey[700])),
                            Text('${quizStatistics['totalEnrolledStudents'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Highest Score:', style: TextStyle(color: Colors.grey[700])),
                            Text('${(quizStatistics['highestScore'] ?? 0.0).toStringAsFixed(0)}/${quizStatistics['totalPoints'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Lowest Score:', style: TextStyle(color: Colors.grey[700])),
                            Text('${(quizStatistics['lowestScore'] ?? 0.0).toStringAsFixed(0)}/${quizStatistics['totalPoints'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                        if (quizStatistics['lateSubmissions'] != null && quizStatistics['lateSubmissions'] > 0) ...[
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Late Submissions:', style: TextStyle(color: Colors.grey[700])),
                              Text('${quizStatistics['lateSubmissions']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Performance Distribution
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
                  Text(
                    'Performance Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[600],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (submissions.isNotEmpty)
                    _buildPerformanceBreakdown()
                  else
                    Text(
                      'No submissions available for performance analysis',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceBreakdown() {
    if (submissions.isEmpty) return SizedBox.shrink();

    final totalPoints = quizData['totalPoints'] ?? 1;
    int excellentCount = 0; // 90-100%
    int goodCount = 0;      // 70-89%
    int fairCount = 0;      // 50-69%
    int poorCount = 0;      // Below 50%

    for (var submission in submissions) {
      final score = submission['score'] ?? 0;
      final percentage = (score / totalPoints) * 100;

      if (percentage >= 90) excellentCount++;
      else if (percentage >= 70) goodCount++;
      else if (percentage >= 50) fairCount++;
      else poorCount++;
    }

    return Column(
      children: [
        _buildPerformanceBar('Excellent (90-100%)', excellentCount, Colors.green),
        SizedBox(height: 8),
        _buildPerformanceBar('Good (70-89%)', goodCount, Colors.blue),
        SizedBox(height: 8),
        _buildPerformanceBar('Fair (50-69%)', fairCount, Colors.orange),
        SizedBox(height: 8),
        _buildPerformanceBar('Needs Improvement (<50%)', poorCount, Colors.red),
      ],
    );
  }

  Widget _buildPerformanceBar(String label, int count, Color color) {
    final total = submissions.length;
    final percentage = total > 0 ? (count / total) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  bool _isLateSubmission(Timestamp? submittedAt) {
    final dueDate = quizData['dueDate'] as Timestamp?;
    if (dueDate == null || submittedAt == null) return false;
    return submittedAt.toDate().isAfter(dueDate.toDate());
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
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