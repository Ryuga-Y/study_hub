import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';

class StudentReportPage extends StatefulWidget {
  const StudentReportPage({Key? key}) : super(key: key);

  @override
  _StudentReportPageState createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  bool isLoading = true;
  String? organizationCode;

  // Data structures
  List<Map<String, dynamic>> assignmentResults = [];
  List<Map<String, dynamic>> tutorialResults = [];
  Map<String, dynamic> overallStats = {
    'totalAssignments': 0,
    'completedAssignments': 0,
    'totalTutorials': 0,
    'completedTutorials': 0,
    'overallGPA': 0.0,
    'totalCredits': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) return;

      organizationCode = userData['organizationCode'];
      if (organizationCode == null) return;

      // Load all enrolled courses
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collectionGroup('enrollments')
          .where('studentId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> tempAssignments = [];
      List<Map<String, dynamic>> tempTutorials = [];

      for (var enrollment in enrollmentsSnapshot.docs) {
        final courseRef = enrollment.reference.parent.parent;
        if (courseRef == null) continue;

        final courseDoc = await courseRef.get();
        if (!courseDoc.exists) continue;

        final courseData = courseDoc.data() as Map<String, dynamic>;
        final courseId = courseDoc.id;

        // Load assignments for this course
        await _loadAssignmentResults(
            courseId,
            courseData,
            user.uid,
            tempAssignments
        );

        // Load tutorials for this course
        await _loadTutorialResults(
            courseId,
            courseData,
            user.uid,
            tempTutorials
        );
      }

      // Sort by date (most recent first)
      tempAssignments.sort((a, b) {
        final aTime = a['evaluatedAt'] ?? a['submittedAt'];
        final bTime = b['evaluatedAt'] ?? b['submittedAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      tempTutorials.sort((a, b) {
        final aTime = a['submittedAt'];
        final bTime = b['submittedAt'];
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      // Calculate overall statistics
      _calculateOverallStats(tempAssignments, tempTutorials);

      setState(() {
        assignmentResults = tempAssignments;
        tutorialResults = tempTutorials;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAssignmentResults(
      String courseId,
      Map<String, dynamic> courseData,
      String studentId,
      List<Map<String, dynamic>> results,
      ) async {
    try {
      // Get all assignments for this course
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(courseId)
          .collection('assignments')
          .get();

      for (var assignmentDoc in assignmentsSnapshot.docs) {
        final assignmentData = assignmentDoc.data();
        final assignmentId = assignmentDoc.id;

        // Check if student has submission
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();

        if (submissionsSnapshot.docs.isEmpty) continue;

        final submissionDoc = submissionsSnapshot.docs.first;
        final submissionData = submissionDoc.data();

        // Check for evaluation
        final evaluationDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .doc(submissionDoc.id)
            .collection('evaluations')
            .doc('current')
            .get();

        Map<String, dynamic>? evaluationData;
        Map<String, dynamic>? rubricData;

        if (evaluationDoc.exists) {
          evaluationData = evaluationDoc.data();

          // Load rubric if used
          if (evaluationData?['rubricUsed'] == true) {
            final rubricDoc = await FirebaseFirestore.instance
                .collection('organizations')
                .doc(organizationCode)
                .collection('courses')
                .doc(courseId)
                .collection('assignments')
                .doc(assignmentId)
                .collection('rubric')
                .doc('main')
                .get();

            if (rubricDoc.exists) {
              rubricData = rubricDoc.data();
            }
          }
        }

        results.add({
          'type': 'assignment',
          'courseId': courseId,
          'courseName': courseData['title'] ?? courseData['name'] ?? 'Unknown Course',
          'courseCode': courseData['code'] ?? '',
          'itemId': assignmentId,
          'itemName': assignmentData['title'] ?? 'Assignment',
          'dueDate': assignmentData['dueDate'],
          'points': assignmentData['points'] ?? 100,
          'submittedAt': submissionData['submittedAt'],
          'isLate': submissionData['isLate'] ?? false,
          'grade': submissionData['grade'] ?? evaluationData?['grade'],
          'letterGrade': submissionData['letterGrade'] ?? evaluationData?['letterGrade'],
          'percentage': submissionData['percentage'] ?? evaluationData?['percentage'],
          'feedback': submissionData['feedback'] ?? evaluationData?['feedback'],
          'evaluatedAt': submissionData['gradedAt'] ?? evaluationData?['evaluatedAt'],
          'rubric': rubricData,
          'criteriaScores': evaluationData?['criteriaScores'],
        });
      }
    } catch (e) {
      print('Error loading assignment results: $e');
    }
  }

  Future<void> _loadTutorialResults(
      String courseId,
      Map<String, dynamic> courseData,
      String studentId,
      List<Map<String, dynamic>> results,
      ) async {
    try {
      // Get all tutorials (materials with type 'tutorial')
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationCode)
          .collection('courses')
          .doc(courseId)
          .collection('materials')
          .where('materialType', isEqualTo: 'tutorial')
          .get();

      for (var materialDoc in materialsSnapshot.docs) {
        final materialData = materialDoc.data();
        final materialId = materialDoc.id;

        // Check if student has submission
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(materialId)
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();

        if (submissionsSnapshot.docs.isEmpty) continue;

        final submissionDoc = submissionsSnapshot.docs.first;
        final submissionData = submissionDoc.data();

        // Check for feedback
        Map<String, dynamic>? feedbackData;
        final feedbackDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationCode)
            .collection('courses')
            .doc(courseId)
            .collection('materials')
            .doc(materialId)
            .collection('submissions')
            .doc(submissionDoc.id)
            .collection('feedback')
            .doc('main')
            .get();

        if (feedbackDoc.exists) {
          feedbackData = feedbackDoc.data();
        }

        results.add({
          'type': 'tutorial',
          'courseId': courseId,
          'courseName': courseData['title'] ?? courseData['name'] ?? 'Unknown Course',
          'courseCode': courseData['code'] ?? '',
          'itemId': materialId,
          'itemName': materialData['title'] ?? 'Tutorial',
          'dueDate': materialData['dueDate'],
          'submittedAt': submissionData['submittedAt'],
          'isLate': submissionData['isLate'] ?? false,
          'status': submissionData['status'] ?? 'submitted',
          'comments': submissionData['comments'],
          'feedback': feedbackData,
          'files': submissionData['files'] ?? [],
        });
      }
    } catch (e) {
      print('Error loading tutorial results: $e');
    }
  }

  void _calculateOverallStats(
      List<Map<String, dynamic>> assignments,
      List<Map<String, dynamic>> tutorials,
      ) {
    int totalAssignments = assignments.length;
    int completedAssignments = assignments.where((a) => a['grade'] != null).length;
    int totalTutorials = tutorials.length;
    int completedTutorials = tutorials.where((t) => t['feedback'] != null).length;

    // Calculate GPA (using letter grades)
    double totalGradePoints = 0;
    int totalGradedItems = 0;

    for (var assignment in assignments) {
      if (assignment['letterGrade'] != null) {
        totalGradePoints += _getGradePoint(assignment['letterGrade']);
        totalGradedItems++;
      }
    }

    double gpa = totalGradedItems > 0 ? totalGradePoints / totalGradedItems : 0.0;

    setState(() {
      overallStats = {
        'totalAssignments': totalAssignments,
        'completedAssignments': completedAssignments,
        'totalTutorials': totalTutorials,
        'completedTutorials': completedTutorials,
        'overallGPA': gpa,
        'totalCredits': totalGradedItems,
      };
    });
  }

  double _getGradePoint(String letterGrade) {
    switch (letterGrade) {
      case 'A+': return 4.0;
      case 'A': return 4.0;
      case 'A-': return 3.7;
      case 'B+': return 3.3;
      case 'B': return 3.0;
      case 'B-': return 2.7;
      case 'C+': return 2.3;
      case 'C': return 2.0;
      case 'F': return 0.0;
      default: return 0.0;
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Report',
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
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Overall Statistics Card
          Container(
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
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Academic Performance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'GPA',
                      overallStats['overallGPA'].toStringAsFixed(2),
                      Colors.white,
                    ),
                    _buildStatItem(
                      'Assignments',
                      '${overallStats['completedAssignments']}/${overallStats['totalAssignments']}',
                      Colors.white,
                    ),
                    _buildStatItem(
                      'Tutorials',
                      '${overallStats['completedTutorials']}/${overallStats['totalTutorials']}',
                      Colors.white,
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
                  color: Colors.grey.withOpacity(0.1),
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
                Tab(text: 'Assignments'),
                Tab(text: 'Tutorials'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsTab(),
                _buildTutorialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsTab() {
    if (assignmentResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No assignment results yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: assignmentResults.length,
      itemBuilder: (context, index) {
        return _buildAssignmentResultCard(assignmentResults[index]);
      },
    );
  }

  Widget _buildAssignmentResultCard(Map<String, dynamic> result) {
    final hasGrade = result['grade'] != null;
    final grade = result['grade'];
    final letterGrade = result['letterGrade'];
    final maxPoints = result['points'];
    final percentage = result['percentage'] ??
        (hasGrade ? ((grade / maxPoints) * 100) : null);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: hasGrade ? () => _showAssignmentDetails(result) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course and Assignment Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['courseCode'] + ' - ' + result['courseName'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          result['itemName'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGrade) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getGradeColor(letterGrade ?? ''),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            letterGrade ?? _calculateLetterGrade(percentage ?? 0),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$grade/$maxPoints',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12),

              // Submission Info
              // Submission Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(result['dueDate'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.upload_file, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Submitted: ${_formatDate(result['submittedAt'])}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (result['isLate'] == true) ...[
                        SizedBox(height: 2),
                        Container(
                          margin: EdgeInsets.only(left: 18), // Align with submitted text
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
                    ],
                  ),
                ],
              ),

              // Percentage Bar (if graded)
              if (hasGrade && percentage != null) ...[
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getGradeColor(letterGrade ?? ''),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getGradeColor(letterGrade ?? ''),
                      ),
                    ),
                  ],
                ),
              ],

              // View Details (if graded with rubric)
              if (hasGrade && result['rubric'] != null) ...[
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAssignmentDetails(result),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple[600],
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

  Widget _buildTutorialsTab() {
    if (tutorialResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No tutorial submissions yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: tutorialResults.length,
      itemBuilder: (context, index) {
        return _buildTutorialResultCard(tutorialResults[index]);
      },
    );
  }

  Widget _buildTutorialResultCard(Map<String, dynamic> result) {
    final hasFeedback = result['feedback'] != null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
            // Course and Tutorial Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result['courseCode'] + ' - ' + result['courseName'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        result['itemName'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasFeedback ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasFeedback ? 'Reviewed' : 'Submitted',
                    style: TextStyle(
                      color: hasFeedback ? Colors.green[700] : Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Submission Info
            Row(
              children: [
                if (result['dueDate'] != null) ...[
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(result['dueDate'])}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Icon(Icons.upload_file, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDate(result['submittedAt'])}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (result['isLate'] == true) ...[
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
              ],
            ),

            // Files submitted
            if (result['files'] != null && (result['files'] as List).isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attachment, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    '${(result['files'] as List).length} file(s) submitted',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Student Comments
            if (result['comments'] != null && result['comments'].toString().isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Comments:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      result['comments'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Lecturer Feedback
            if (hasFeedback) ...[
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
                        Icon(Icons.comment, size: 14, color: Colors.blue[700]),
                        SizedBox(width: 4),
                        Text(
                          'Lecturer Feedback:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      result['feedback']['comment'] ?? 'No comment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            // Handle
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                border: Border(
                  bottom: BorderSide(color: Colors.purple[200]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['itemName'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          result['courseCode'] + ' - ' + result['courseName'],
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
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grade Summary
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Grade',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                result['letterGrade'] ?? _calculateLetterGrade(
                                    ((result['grade'] ?? 0) / (result['points'] ?? 100)) * 100
                                ),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _getGradeColor(result['letterGrade'] ?? ''),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Points',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${result['grade']}/${result['points']}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Percentage',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${(((result['grade'] ?? 0) / (result['points'] ?? 100)) * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Feedback
                    if (result['feedback'] != null) ...[
                      SizedBox(height: 20),
                      Text(
                        'Instructor Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          result['feedback'] ?? 'No feedback provided',
                          style: TextStyle(
                            color: Colors.blue[900],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    // Rubric Details
                    if (result['rubric'] != null && result['criteriaScores'] != null) ...[
                      SizedBox(height: 20),
                      Text(
                        'Rubric Evaluation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ..._buildRubricDetails(result['rubric'], result['criteriaScores']),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRubricDetails(
      Map<String, dynamic> rubric,
      Map<String, dynamic> criteriaScores,
      ) {
    final criteria = rubric['criteria'] as List;
    List<Widget> widgets = [];

    for (var criterion in criteria) {
      final criterionId = criterion['id'];
      final score = criteriaScores[criterionId];

      if (score == null) continue;

      widgets.add(
        Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          criterion['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (criterion['description'] != null) ...[
                          SizedBox(height: 4),
                          Text(
                            criterion['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                      SizedBox(height: 4),
                      Text(
                        'Weight: ${criterion['weight']}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.purple[600], size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Level: ${score['levelId']}',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

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

  String _calculateLetterGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 75) return 'A-';
    if (percentage >= 70) return 'B+';
    if (percentage >= 65) return 'B';
    if (percentage >= 60) return 'B-';
    if (percentage >= 55) return 'C+';
    if (percentage >= 50) return 'C';
    return 'F';
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