import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationAnalyticsPage extends StatefulWidget {
  final String courseId;
  final String organizationCode;
  final Map<String, dynamic> courseData;

  const EvaluationAnalyticsPage({
    Key? key,
    required this.courseId,
    required this.organizationCode,
    required this.courseData,
  }) : super(key: key);

  @override
  _EvaluationAnalyticsPageState createState() => _EvaluationAnalyticsPageState();
}

class _EvaluationAnalyticsPageState extends State<EvaluationAnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  // Analytics data
  Map<String, dynamic> overallStats = {};
  List<Map<String, dynamic>> assignmentStats = [];
  List<Map<String, dynamic>> studentPerformance = [];
  Map<String, dynamic> rubricAnalytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    try {
      await Future.wait([
        _loadOverallStats(),
        _loadAssignmentStats(),
        _loadStudentPerformance(),
      ]);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadOverallStats() async {
    try {
      // Get all assignments
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .get();

      int totalAssignments = assignmentsSnapshot.docs.length;
      int totalSubmissions = 0;
      int gradedSubmissions = 0;
      double totalGradeSum = 0.0;
      int totalPossiblePoints = 0;

      for (var assignmentDoc in assignmentsSnapshot.docs) {
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentDoc.id)
            .collection('submissions')
            .get();

        totalSubmissions += submissionsSnapshot.docs.length;

        for (var submissionDoc in submissionsSnapshot.docs) {
          final submissionData = submissionDoc.data();
          if (submissionData['grade'] != null) {
            gradedSubmissions++;
            totalGradeSum += (submissionData['grade'] as num).toDouble();
            totalPossiblePoints += (assignmentDoc.data()['points'] as num? ?? 100).toInt();
          }
        }
      }

      setState(() {
        overallStats = {
          'totalAssignments': totalAssignments,
          'totalSubmissions': totalSubmissions,
          'gradedSubmissions': gradedSubmissions,
          'pendingGrading': totalSubmissions - gradedSubmissions,
          'averageGrade': gradedSubmissions > 0
              ? (totalGradeSum / totalPossiblePoints * 100)
              : 0,
        };
      });
    } catch (e) {
      print('Error loading overall stats: $e');
    }
  }

  Future<void> _loadAssignmentStats() async {
    try {
      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> stats = [];

      for (var assignmentDoc in assignmentsSnapshot.docs) {
        final assignmentData = assignmentDoc.data();

        // Get submissions for this assignment
        final submissionsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentDoc.id)
            .collection('submissions')
            .get();

        int submitted = submissionsSnapshot.docs.length;
        int graded = 0;
        double gradeSum = 0.0;
        List<int> grades = [];

        for (var submissionDoc in submissionsSnapshot.docs) {
          final submissionData = submissionDoc.data();
          if (submissionData['grade'] != null) {
            graded++;
            final grade = (submissionData['grade'] as num).toInt();
            gradeSum += grade.toDouble();
            grades.add(grade);
          }
        }

        // Calculate statistics
        double average = graded > 0 ? gradeSum / graded : 0.0;
        int? min = grades.isNotEmpty ? grades.reduce((a, b) => a < b ? a : b) : null;
        int? max = grades.isNotEmpty ? grades.reduce((a, b) => a > b ? a : b) : null;

        stats.add({
          'id': assignmentDoc.id,
          'title': assignmentData['title'],
          'points': (assignmentData['points'] as num? ?? 100).toInt(),
          'dueDate': assignmentData['dueDate'],
          'submitted': submitted,
          'graded': graded,
          'average': average,
          'min': min,
          'max': max,
        });
      }

      setState(() {
        assignmentStats = stats;
      });
    } catch (e) {
      print('Error loading assignment stats: $e');
    }
  }

  Future<void> _loadStudentPerformance() async {
    try {
      // Get all enrolled students
      final enrollmentsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      List<Map<String, dynamic>> performance = [];

      for (var enrollmentDoc in enrollmentsSnapshot.docs) {
        final studentId = enrollmentDoc.data()['studentId'];

        // Get student info
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (!studentDoc.exists) continue;

        final studentData = studentDoc.data()!;

        // Get all submissions for this student
        int totalSubmissions = 0;
        int gradedSubmissions = 0;
        double totalGradePercentage = 0.0;

        for (var assignment in assignmentStats) {
          final submissionsSnapshot = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(assignment['id'])
              .collection('submissions')
              .where('studentId', isEqualTo: studentId)
              .get();

          if (submissionsSnapshot.docs.isNotEmpty) {
            totalSubmissions++;
            final latestSubmission = submissionsSnapshot.docs.first;
            final grade = latestSubmission.data()['grade'];

            if (grade != null) {
              gradedSubmissions++;
              totalGradePercentage += ((grade as num).toDouble() / (assignment['points'] as num).toDouble() * 100);
            }
          }
        }

        performance.add({
          'studentId': studentId,
          'studentName': studentData['fullName'],
          'studentEmail': studentData['email'],
          'totalSubmissions': totalSubmissions,
          'gradedSubmissions': gradedSubmissions,
          'averageGrade': gradedSubmissions > 0
              ? totalGradePercentage / gradedSubmissions
              : 0,
          'submissionRate': assignmentStats.isNotEmpty
              ? (totalSubmissions / assignmentStats.length * 100)
              : 0,
        });
      }

      // Sort by average grade
      performance.sort((a, b) => (b['averageGrade'] as num).compareTo(a['averageGrade'] as num));

      setState(() {
        studentPerformance = performance;
      });
    } catch (e) {
      print('Error loading student performance: $e');
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
          'Evaluation Analytics',
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
          // Course Info Header
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.courseData['title'] ?? 'Lecturer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Code: ${widget.courseData['code'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quick Stats
          Container(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatCard(
                  'Total Assignments',
                  overallStats['totalAssignments']?.toString() ?? '0',
                  Icons.assignment,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Submissions',
                  overallStats['totalSubmissions']?.toString() ?? '0',
                  Icons.upload_file,
                  Colors.green,
                ),
                _buildStatCard(
                  'Graded',
                  overallStats['gradedSubmissions']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Pending',
                  overallStats['pendingGrading']?.toString() ?? '0',
                  Icons.pending,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Average',
                  '${overallStats['averageGrade']?.toStringAsFixed(1) ?? '0'}%',
                  Icons.grade,
                  Colors.teal,
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: EdgeInsets.all(16),
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
                Tab(text: 'Assignments'),
                Tab(text: 'Students'),
                Tab(text: 'Insights'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsTab(),
                _buildStudentsTab(),
                _buildInsightsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Add this
        children: [
          Icon(icon, color: color, size: 24), // Reduced from 28
          SizedBox(height: 4), // Reduced from 8
          Flexible( // Wrap in Flexible
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18, // Reduced from 20
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis, // Add this
            ),
          ),
          Flexible( // Wrap in Flexible
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11, // Reduced from 12
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis, // Add this
              maxLines: 2, // Add this
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    if (assignmentStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No assignments yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: assignmentStats.length,
      itemBuilder: (context, index) {
        final assignment = assignmentStats[index];
        return _buildAssignmentStatCard(assignment);
      },
    );
  }

  Widget _buildAssignmentStatCard(Map<String, dynamic> assignment) {
    final submissionRate = assignment['submitted'] > 0
        ? (assignment['graded'] / assignment['submitted'] * 100)
        : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['title'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Due: ${_formatDate(assignment['dueDate'])}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
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
                  '${assignment['points']} pts',
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Progress Bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${assignment['graded']}/${assignment['submitted']} graded',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${submissionRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              LinearProgressIndicator(
                value: assignment['submitted'] > 0
                    ? assignment['graded'] / assignment['submitted']
                    : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(
                'Average',
                '${assignment['average'].toStringAsFixed(1)}',
                Colors.blue,
              ),
              if (assignment['min'] != null)
                _buildMiniStat(
                  'Min',
                  '${assignment['min']}',
                  Colors.red,
                ),
              if (assignment['max'] != null)
                _buildMiniStat(
                  'Max',
                  '${assignment['max']}',
                  Colors.green,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    if (studentPerformance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No students enrolled',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: studentPerformance.length,
      itemBuilder: (context, index) {
        final student = studentPerformance[index];
        return _buildStudentPerformanceCard(student, index + 1);
      },
    );
  }

  Widget _buildStudentPerformanceCard(Map<String, dynamic> student, int rank) {
    final gradeColor = _getGradeColor((student['averageGrade'] as num).toDouble());

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3 ? Colors.amber[100] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.amber[700] : Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(width: 16),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['studentName'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  student['studentEmail'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gradeColor),
                ),
                child: Text(
                  '${student['averageGrade'].toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: gradeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${student['gradedSubmissions']}/${student['totalSubmissions']} graded',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Grade Distribution
          _buildInsightCard(
            'Grade Distribution',
            Icons.bar_chart,
            _buildGradeDistribution(),
          ),

          // Submission Patterns
          _buildInsightCard(
            'Submission Patterns',
            Icons.timeline,
            _buildSubmissionPatterns(),
          ),

          // Performance Trends
          _buildInsightCard(
            'Performance Indicators',
            Icons.trending_up,
            _buildPerformanceTrends(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, IconData icon, Widget content) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
              Icon(icon, color: Colors.purple[600], size: 24),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildGradeDistribution() {
    // Calculate grade distribution using the exact grading system
    Map<String, int> distribution = {
      'A+ (90-100)': 0,
      'A (80-89)': 0,
      'A- (75-79)': 0,
      'B+ (70-74)': 0,
      'B (65-69)': 0,
      'B- (60-64)': 0,
      'C+ (55-59)': 0,
      'C (50-54)': 0,
      'F (0-49)': 0,
    };

    for (var student in studentPerformance) {
      final grade = (student['averageGrade'] as num).toDouble();
      if (grade >= 90) {
        distribution['A+ (90-100)'] = distribution['A+ (90-100)']! + 1;
      } else if (grade >= 80) distribution['A (80-89)'] = distribution['A (80-89)']! + 1;
      else if (grade >= 75) distribution['A- (75-79)'] = distribution['A- (75-79)']! + 1;
      else if (grade >= 70) distribution['B+ (70-74)'] = distribution['B+ (70-74)']! + 1;
      else if (grade >= 65) distribution['B (65-69)'] = distribution['B (65-69)']! + 1;
      else if (grade >= 60) distribution['B- (60-64)'] = distribution['B- (60-64)']! + 1;
      else if (grade >= 55) distribution['C+ (55-59)'] = distribution['C+ (55-59)']! + 1;
      else if (grade >= 50) distribution['C (50-54)'] = distribution['C (50-54)']! + 1;
      else distribution['F (0-49)'] = distribution['F (0-49)']! + 1;
    }

    return Column(
      children: distribution.entries.map((entry) {
        final percentage = studentPerformance.isNotEmpty
            ? (entry.value / studentPerformance.length * 100)
            : 0;

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Container(
                      height: 24,
                      width: MediaQuery.of(context).size.width * percentage / 100 * 0.5,
                      decoration: BoxDecoration(
                        color: _getGradeBarColor(entry.key),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 40,
                alignment: Alignment.centerRight,
                child: Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmissionPatterns() {
    int onTimeSubmissions = 0;
    int lateSubmissions = 0;
    int missingSubmissions = 0;

    // Calculate submission patterns (simplified for demo)
    final totalExpected = studentPerformance.length * assignmentStats.length;
    final totalSubmitted = studentPerformance.fold<int>(
      0,
          (sum, student) => sum + student['totalSubmissions'] as int,
    );

    onTimeSubmissions = (totalSubmitted * 0.8).round(); // Assume 80% on time
    lateSubmissions = (totalSubmitted * 0.2).round(); // Assume 20% late
    missingSubmissions = totalExpected - totalSubmitted;

    return Column(
      children: [
        _buildPatternRow('On Time', onTimeSubmissions, Colors.green),
        _buildPatternRow('Late', lateSubmissions, Colors.orange),
        _buildPatternRow('Missing', missingSubmissions, Colors.red),
      ],
    );
  }

  Widget _buildPatternRow(String label, int value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrends() {
    // Calculate performance indicators
    final avgSubmissionRate = studentPerformance.isNotEmpty
        ? studentPerformance.fold<double>(
        0, (sum, student) => sum + student['submissionRate']) /
        studentPerformance.length
        : 0;

    final highPerformers = studentPerformance
        .where((s) => s['averageGrade'] >= 85).length;

    final needsSupport = studentPerformance
        .where((s) => s['averageGrade'] < 70).length;

    return Column(
      children: [
        _buildIndicatorRow(
          'Average Submission Rate',
          '${avgSubmissionRate.toStringAsFixed(1)}%',
          avgSubmissionRate >= 80 ? Colors.green : Colors.orange,
        ),
        _buildIndicatorRow(
          'High Performers (85%+)',
          '$highPerformers students',
          Colors.green,
        ),
        _buildIndicatorRow(
          'Needs Support (<70%)',
          '$needsSupport students',
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildIndicatorRow(String label, String value, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 90) return Colors.green[600]!;
    if (percentage >= 75) return Colors.green[500]!;
    if (percentage >= 70) return Colors.blue[600]!;
    if (percentage >= 60) return Colors.blue[500]!;
    if (percentage >= 55) return Colors.orange[600]!;
    if (percentage >= 50) return Colors.orange[500]!;
    return Colors.red[600]!;
  }

  Color _getGradeBarColor(String grade) {
    if (grade.startsWith('A+') || grade.startsWith('A ') || grade.startsWith('A-')) {
      return Colors.green[600]!;
    }
    if (grade.startsWith('B+') || grade.startsWith('B ') || grade.startsWith('B-')) {
      return Colors.blue[600]!;
    }
    if (grade.startsWith('C+') || grade.startsWith('C ')) {
      return Colors.orange[600]!;
    }
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