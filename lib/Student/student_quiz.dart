import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../Authentication/auth_services.dart';
import '../goal_progress_service.dart';

class StudentQuizSubmissionPage extends StatefulWidget {
  final String courseId;
  final String quizId;
  final Map<String, dynamic> quizData;
  final String organizationCode;

  const StudentQuizSubmissionPage({
    Key? key,
    required this.courseId,
    required this.quizId,
    required this.quizData,
    required this.organizationCode,
  }) : super(key: key);

  @override
  _StudentQuizSubmissionPageState createState() => _StudentQuizSubmissionPageState();
}

class _StudentQuizSubmissionPageState extends State<StudentQuizSubmissionPage> {
  final AuthService _authService = AuthService();
  final GoalProgressService _goalService = GoalProgressService();

  List<Map<String, dynamic>> questions = [];
  List<int?> selectedAnswers = [];
  Timer? _timer;
  int remainingSeconds = 0;
  bool isQuizStarted = false;
  bool isSubmitting = false;
  bool hasSubmitted = false;
  Map<String, dynamic>? existingSubmission;
  int currentAttempt = 1;
  bool canTakeQuiz = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    try {
      // Load quiz questions
      final quizQuestions = widget.quizData['questions'] as List<dynamic>? ?? [];

      // Shuffle questions if enabled
      if (widget.quizData['shuffleQuestions'] == true) {
        quizQuestions.shuffle();
      }

      setState(() {
        questions = quizQuestions.cast<Map<String, dynamic>>();
        selectedAnswers = List.filled(questions.length, null);
        remainingSeconds = (widget.quizData['timeLimit'] ?? 30) * 60; // Convert to seconds
      });

      // Check if student has already submitted
      await _checkExistingSubmission();

      // Check if quiz is past due date and late submission is not allowed
      await _checkQuizAvailability();

    } catch (e) {
      print('Error initializing quiz: $e');
      setState(() {
        errorMessage = 'Error loading quiz: $e';
      });
    }
  }

  Future<void> _checkExistingSubmission() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(widget.quizId)
          .collection('submissions')
          .where('studentId', isEqualTo: user.uid)
          .orderBy('submittedAt', descending: true)
          .get();

      if (submissionsSnapshot.docs.isNotEmpty) {
        final submissions = submissionsSnapshot.docs;
        final maxAttempts = widget.quizData['maxAttempts'] ?? 1;

        setState(() {
          currentAttempt = submissions.length + 1;
          existingSubmission = {
            'id': submissions.first.id,
            ...submissions.first.data(),
          };

          // Check if student can take another attempt
          if (maxAttempts > 0 && submissions.length >= maxAttempts) {
            canTakeQuiz = false;
            hasSubmitted = true;
          }
        });
      }
    } catch (e) {
      print('Error checking existing submission: $e');
    }
  }

  Future<void> _checkQuizAvailability() async {
    final dueDate = widget.quizData['dueDate'] as Timestamp?;
    final allowLateSubmission = widget.quizData['allowLateSubmission'] ?? false;

    if (dueDate != null && DateTime.now().isAfter(dueDate.toDate())) {
      if (!allowLateSubmission) {
        setState(() {
          canTakeQuiz = false;
          errorMessage = 'This quiz is no longer available. The due date has passed and late submissions are not allowed.';
        });
      }
    }
  }

  void _startQuiz() {
    setState(() {
      isQuizStarted = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          _submitQuiz(autoSubmit: true);
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int questionIndex, int answerIndex) {
    setState(() {
      selectedAnswers[questionIndex] = answerIndex;
    });
  }

  Future<void> _submitQuiz({bool autoSubmit = false}) async {
    if (isSubmitting) return;

    // Show confirmation dialog unless it's auto-submit
    if (!autoSubmit) {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Submit Quiz?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to submit your quiz?'),
              SizedBox(height: 8),
              Text(
                'Answered: ${selectedAnswers.where((answer) => answer != null).length}/${questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selectedAnswers.contains(null) ? Colors.orange : Colors.green,
                ),
              ),
              if (selectedAnswers.contains(null))
                Text(
                  'You have unanswered questions.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Continue Quiz'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600]),
              child: Text('Submit Quiz', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldSubmit != true) return;
    }

    setState(() {
      isSubmitting = true;
    });

    _timer?.cancel();

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate score
      int totalScore = 0;
      List<Map<String, dynamic>> answers = [];

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final selectedAnswer = selectedAnswers[i];
        final correctAnswer = question['correctAnswerIndex'];
        final points = question['points'] ?? 1;

        final isCorrect = selectedAnswer == correctAnswer;
        if (isCorrect) {
          totalScore += points as int;
        }

        answers.add({
          'questionIndex': i,
          'selectedAnswer': selectedAnswer,
          'correctAnswer': correctAnswer,
          'isCorrect': isCorrect,
          'points': isCorrect ? points : 0,
        });
      }

      // Get student data
      final userData = await _authService.getUserData(user.uid);
      final studentName = userData?['fullName'] ?? 'Unknown Student';

      // Prepare submission data
      final submissionData = {
        'studentId': user.uid,
        'studentName': studentName,
        'studentEmail': userData?['email'] ?? '',
        'quizId': widget.quizId,
        'courseId': widget.courseId,
        'organizationCode': widget.organizationCode,
        'answers': answers,
        'score': totalScore,
        'totalPoints': widget.quizData['totalPoints'] ?? 0,
        'timeSpent': ((widget.quizData['timeLimit'] ?? 30) * 60) - remainingSeconds,
        'submittedAt': FieldValue.serverTimestamp(),
        'attemptNumber': currentAttempt,
        'isAutoSubmitted': autoSubmit,
        'status': 'submitted',
      };

      // Submit to Firestore
      final submissionRef = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .doc(widget.quizId)
          .collection('submissions')
          .add(submissionData);

      print('✅ Quiz submitted successfully: ${submissionRef.id}');

      // Award water buckets for quiz completion (2 buckets for quiz)
      try {
        await _goalService.awardQuizSubmission(
            submissionRef.id,
            widget.quizId,
            quizName: widget.quizData['title'] ?? 'Quiz'
        );
        print('✅ Awarded 2 water buckets for quiz: ${widget.quizData['title']}');
      } catch (e) {
        print('❌ Error awarding water buckets: $e');
        // Don't fail the submission if reward fails
      }

      setState(() {
        hasSubmitted = true;
        existingSubmission = {
          'id': submissionRef.id,
          ...submissionData,
          'submittedAt': Timestamp.now(),
        };
      });

      // Show results if enabled
      if (widget.quizData['showResultsImmediately'] == true) {
        _showQuizResults(totalScore, answers);
      } else {
        _showSubmissionConfirmation(autoSubmit);
      }

    } catch (e) {
      print('❌ Error submitting quiz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _showQuizResults(int score, List<Map<String, dynamic>> answers) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              score >= (widget.quizData['totalPoints'] * 0.8) ? Icons.celebration : Icons.check_circle,
              color: score >= (widget.quizData['totalPoints'] * 0.8) ? Colors.green : Colors.blue,
              size: 48,
            ),
            SizedBox(height: 8),
            Text('Quiz Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Score',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '$score/${widget.quizData['totalPoints']}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[600],
                    ),
                  ),
                  Text(
                    '${((score / (widget.quizData['totalPoints'] ?? 1)) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Correct',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                      Text(
                        '${answers.where((a) => a['isCorrect']).length}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Incorrect',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      Text(
                        '${answers.where((a) => !a['isCorrect']).length}',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                  Icon(Icons.local_drink, color: Colors.orange[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You earned 2 water buckets for completing this quiz! 💧💧',
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
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to course page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSubmissionConfirmation(bool autoSubmit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(autoSubmit ? 'Time\'s Up!' : 'Quiz Submitted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              autoSubmit
                  ? 'Your quiz has been automatically submitted as time ran out.'
                  : 'Your quiz has been successfully submitted.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Your results will be available once the instructor reviews all submissions.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
                  Icon(Icons.local_drink, color: Colors.orange[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You earned 2 water buckets for completing this quiz! 💧💧',
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
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to course page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Quiz'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Quiz Unavailable',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!canTakeQuiz || hasSubmitted) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Quiz Results'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildSubmissionSummary(),
      );
    }

    if (!isQuizStarted) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Quiz Instructions'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _buildQuizInstructions(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('${widget.quizData['title'] ?? 'Quiz'}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => _showExitConfirmation(),
        ),
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: remainingSeconds <= 300 ? Colors.red[100] : Colors.purple[100], // Red when ≤5 minutes
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: remainingSeconds <= 300 ? Colors.red : Colors.purple[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: remainingSeconds <= 300 ? Colors.red[700] : Colors.purple[600],
                ),
                SizedBox(width: 4),
                Text(
                  _formatTime(remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remainingSeconds <= 300 ? Colors.red[700] : Colors.purple[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildQuizContent(),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'Progress: ${selectedAnswers.where((answer) => answer != null).length}/${questions.length}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: isSubmitting ? null : () => _submitQuiz(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSubmitting
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                'Submit Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizInstructions() {
    final dueDate = widget.quizData['dueDate'] as Timestamp?;
    final timeLimit = widget.quizData['timeLimit'] ?? 30;
    final maxAttempts = widget.quizData['maxAttempts'] ?? 1;
    final allowLateSubmission = widget.quizData['allowLateSubmission'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quiz Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Quiz Instructions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  widget.quizData['title'] ?? 'Quiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.quizData['description'] ?? 'Complete this quiz to test your knowledge.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Quiz Details
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
                  'Quiz Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Questions', '${questions.length}'),
                _buildDetailRow('Total Points', '${widget.quizData['totalPoints'] ?? 0}'),
                _buildDetailRow('Time Limit', '$timeLimit minutes'),
                _buildDetailRow('Attempts Allowed', maxAttempts == 0 ? 'Unlimited' : '$maxAttempts'),
                if (currentAttempt > 1)
                  _buildDetailRow('Current Attempt', '$currentAttempt'),
                if (dueDate != null)
                  _buildDetailRow('Due Date', _formatDate(dueDate)),
                _buildDetailRow('Late Submission', allowLateSubmission ? 'Allowed' : 'Not Allowed'),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Instructions
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
                  'Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[600],
                  ),
                ),
                SizedBox(height: 16),
                _buildInstructionItem('📝', 'Read each question carefully before selecting your answer.'),
                _buildInstructionItem('⏰', 'You have $timeLimit minutes to complete the quiz.'),
                _buildInstructionItem('🔒', 'Once you start, the timer will begin and cannot be paused.'),
                _buildInstructionItem('💾', 'Your answers are saved automatically as you go.'),
                _buildInstructionItem('🚫', 'You cannot go back to change answers once submitted.'),
                if (widget.quizData['showResultsImmediately'] == true)
                  _buildInstructionItem('📊', 'You will see your results immediately after submission.'),
                _buildInstructionItem('💧', 'Complete the quiz to earn 2 water buckets for your tree!'),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Start Quiz Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            width: 120,
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

  Widget _buildInstructionItem(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    return PageView.builder(
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        final options = question['options'] as List<dynamic>;

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header
              Container(
                width: double.infinity,
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
                            'Question ${index + 1} of ${questions.length}',
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Answer Options
              ...options.asMap().entries.map((entry) {
                final optionIndex = entry.key;
                final option = entry.value;
                final isSelected = selectedAnswers[index] == optionIndex;

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _selectAnswer(index, optionIndex),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple[50] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.purple[300]! : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
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
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.purple[600] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.purple[600]! : Colors.grey[400]!,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + optionIndex),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                color: isSelected ? Colors.purple[700] : Colors.grey[800],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Colors.purple[600],
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
        );
      },
    );
  }

  Widget _buildSubmissionSummary() {
    if (existingSubmission == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No submission found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final score = existingSubmission!['score'] ?? 0;
    final totalPoints = existingSubmission!['totalPoints'] ?? 1;
    final percentage = ((score / totalPoints) * 100).round();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Results Card
          Container(
            width: double.infinity,
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
                Icon(
                  Icons.quiz,
                  size: 48,
                  color: Colors.purple[600],
                ),
                SizedBox(height: 16),
                Text(
                  'Quiz Completed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.quizData['title'] ?? 'Quiz',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),

                // Score Display
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Score',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '$score/$totalPoints',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[600],
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Submission Details
                _buildDetailRow('Submitted', _formatDateTime(existingSubmission!['submittedAt'] as Timestamp?)),
                _buildDetailRow('Attempt', '${existingSubmission!['attemptNumber'] ?? 1}'),
                if (existingSubmission!['timeSpent'] != null)
                  _buildDetailRow('Time Spent', '${(existingSubmission!['timeSpent'] / 60).round()} minutes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit Quiz?'),
        content: Text('Are you sure you want to exit? Your progress will be lost and the quiz will be automatically submitted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Quiz'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _submitQuiz(autoSubmit: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Exit & Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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