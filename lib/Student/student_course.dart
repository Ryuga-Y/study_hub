import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';

class StudentCoursePage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const StudentCoursePage({
    Key? key,
    required this.courseId,
    required this.courseData,
  }) : super(key: key);

  @override
  _StudentCoursePageState createState() => _StudentCoursePageState();
}

class _StudentCoursePageState extends State<StudentCoursePage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Data
  String? _organizationCode;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  Map<String, Map<String, dynamic>> submissions = {};
  List<Map<String, dynamic>> classmates = [];

  bool isLoading = true;
  String? errorMessage;
  int _currentIndex = 2; // Course tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      if (user == null) {
        setState(() => errorMessage = 'User not authenticated');
        return;
      }

      // Load user data
      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        setState(() => errorMessage = 'User data not found');
        return;
      }

      setState(() {
        _organizationCode = userData['organizationCode'];
      });

      // Load course content
      await Future.wait([
        _fetchAssignments(),
        _fetchMaterials(),
        _fetchSubmissions(user.uid),
        _fetchClassmates(user.uid),
      ]);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAssignments() async {
    if (_organizationCode == null) return;

    try {
      var assignmentQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('assignments')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        assignments = assignmentQuery.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching assignments: $e');
    }
  }

  Future<void> _fetchMaterials() async {
    if (_organizationCode == null) return;

    try {
      var materialQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('materials')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        materials = materialQuery.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching materials: $e');
    }
  }

  Future<void> _fetchSubmissions(String studentId) async {
    if (_organizationCode == null) return;

    try {
      Map<String, Map<String, dynamic>> submissionMap = {};

      for (var assignment in assignments) {
        var submissionQuery = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .where('studentId', isEqualTo: studentId)
            .get();

        if (submissionQuery.docs.isNotEmpty) {
          submissionMap[assignment['id']] = {
            'id': submissionQuery.docs.first.id,
            ...submissionQuery.docs.first.data(),
          };
        }
      }

      setState(() {
        submissions = submissionMap;
      });
    } catch (e) {
      print('Error fetching submissions: $e');
    }
  }

  Future<void> _fetchClassmates(String currentStudentId) async {
    if (_organizationCode == null) return;

    try {
      var enrollmentQuery = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in enrollmentQuery.docs) {
        String studentId = doc.data()['studentId'];
        if (studentId != currentStudentId) {
          var studentDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .get();

          if (studentDoc.exists) {
            students.add({
              'id': studentId,
              'fullName': studentDoc.data()?['fullName'] ?? 'Unknown Student',
              'email': studentDoc.data()?['email'] ?? 'No email',
              'facultyName': studentDoc.data()?['facultyName'] ?? studentDoc.data()?['faculty'] ?? '',
            });
          }
        }
      }

      setState(() {
        classmates = students;
      });
    } catch (e) {
      print('Error fetching classmates: $e');
    }
  }

  Future<void> _submitAssignment(Map<String, dynamic> assignment) async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Check if due date has passed
    final dueDate = assignment['dueDate'] as Timestamp?;
    if (dueDate != null && dueDate.toDate().isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assignment deadline has passed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png', 'zip'],
      );

      if (result != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                ),
                SizedBox(width: 20),
                Text('Submitting assignment...'),
              ],
            ),
          ),
        );

        // Get user data
        final userData = await _authService.getUserData(user.uid);
        final studentName = userData?['fullName'] ?? 'Unknown Student';

        // TODO: Upload file to storage and get URL
        // For now, we'll use the file name as a placeholder
        String fileUrl = result.files.single.name;

        // Submit assignment
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .add({
          'studentId': user.uid,
          'studentName': studentName,
          'submittedAt': FieldValue.serverTimestamp(),
          'fileUrl': fileUrl,
          'fileName': result.files.single.name,
          'status': 'submitted',
          'grade': null,
          'feedback': null,
        });

        Navigator.pop(context); // Close loading dialog

        // Reload submissions
        await _fetchSubmissions(user.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewMaterial(Map<String, dynamic> material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['title'] ?? 'Material',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'By ${widget.courseData['lecturerName'] ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (material['description'] != null) ...[
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        material['description'],
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 16),
                    ],
                    if (material['content'] != null) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            material['content'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    if (material['fileUrl'] != null) ...[
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadFile(material['fileUrl'], material['title']),
                          icon: Icon(Icons.download, color: Colors.white),
                          label: Text('Download Material', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[400],
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
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

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final Uri url = Uri.parse(fileUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
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

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _loadData();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Course Header
          Container(
            width: double.infinity,
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
                      child: Text(
                        widget.courseData['code'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  widget.courseData['title'] ?? widget.courseData['name'] ?? 'Course Title',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.courseData['description'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Text(
                      widget.courseData['lecturerName'] ?? 'Unknown Lecturer',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(width: 24),
                    Icon(Icons.school, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.courseData['facultyName'] ?? 'Faculty',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
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
                Tab(text: 'Content'),
                Tab(text: 'Classmates'),
                Tab(text: 'Overview'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContentTab(),
                _buildClassmatesTab(),
                _buildOverviewTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 32,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.school,
              color: Colors.purple[400],
              size: 32,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Study Hub',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: Colors.black87),
          onPressed: () {
            // TODO: Implement notifications
          },
        ),
      ],
    );
  }

  Widget _buildContentTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _fetchAssignments(),
          _fetchMaterials(),
          _fetchSubmissions(_authService.currentUser!.uid),
        ]);
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Assignments Section
            if (assignments.isNotEmpty) ...[
              _buildSectionHeader('Assignments', Icons.assignment),
              ...assignments.map((assignment) => _buildAssignmentCard(assignment)),
              SizedBox(height: 24),
            ],

            // Materials Section
            if (materials.isNotEmpty) ...[
              _buildSectionHeader('Materials', Icons.description),
              ...materials.map((material) => _buildMaterialCard(material)),
            ],

            // Empty state
            if (assignments.isEmpty && materials.isEmpty)
              Container(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No content available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple[400], size: 24),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final hasSubmitted = submissions.containsKey(assignment['id']);
    final submission = submissions[assignment['id']];
    final dueDate = assignment['dueDate'] as Timestamp?;
    final isDuePassed = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

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
        onTap: () {
          _showAssignmentDetails(assignment);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.assignment,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['title'] ?? 'Assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      assignment['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        if (dueDate != null) ...[
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            'Due: ${_formatDate(dueDate)}',
                            style: TextStyle(
                              color: isDuePassed ? Colors.red : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 16),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasSubmitted
                                ? Colors.green.withValues(alpha: 0.1)
                                : (isDuePassed
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hasSubmitted
                                ? 'Submitted'
                                : (isDuePassed ? 'Missing' : 'Pending'),
                            style: TextStyle(
                              color: hasSubmitted
                                  ? Colors.green
                                  : (isDuePassed ? Colors.red : Colors.orange),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (hasSubmitted && submission?['grade'] != null) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Grade: ${submission!['grade']}',
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
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
        onTap: () => _viewMaterial(material),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.description,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material['title'] ?? 'Material',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      material['description'] ?? 'No description',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatDate(material['createdAt']),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                material['fileUrl'] != null ? Icons.download : Icons.visibility,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassmatesTab() {
    return classmates.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No classmates found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: () => _fetchClassmates(_authService.currentUser!.uid),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: classmates.length,
        itemBuilder: (context, index) {
          return _buildClassmateCard(classmates[index]);
        },
      ),
    );
  }

  Widget _buildClassmateCard(Map<String, dynamic> student) {
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
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.purple[100],
          child: Text(
            student['fullName'].toString().substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Colors.purple[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student['fullName'] ?? 'Unknown Student',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student['email'] ?? 'No email',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (student['facultyName'] != null && student['facultyName'].toString().isNotEmpty)
              Text(
                'Faculty: ${student['facultyName']}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final completedAssignments = assignments.where((a) => submissions.containsKey(a['id'])).length;
    final pendingAssignments = assignments.length - completedAssignments;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedAssignments.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  pendingAssignments.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Materials',
                  materials.length.toString(),
                  Icons.description,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Classmates',
                  classmates.length.toString(),
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Course Details
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                _buildDetailRow('Code', widget.courseData['code'] ?? 'N/A'),
                _buildDetailRow('Faculty', widget.courseData['facultyName'] ?? 'N/A'),
                _buildDetailRow('Lecturer', widget.courseData['lecturerName'] ?? 'N/A'),
                _buildDetailRow('Enrolled', _formatDate(widget.courseData['enrolledAt'])),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Progress Summary
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                if (assignments.isNotEmpty) ...[
                  LinearProgressIndicator(
                    value: completedAssignments / assignments.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${(completedAssignments / assignments.length * 100).toStringAsFixed(0)}% assignments completed',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ] else
                  Text(
                    'No assignments yet',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        // Handle navigation
        switch (index) {
          case 0:
            Navigator.pop(context);
            break;
          case 1:
          // TODO: Navigate to community
            break;
          case 2:
          // Already on course page
            break;
          case 3:
          // TODO: Navigate to calendar
            break;
          case 4:
          // TODO: Navigate to profile
            break;
        }
      },
      selectedItemColor: Colors.purple[400],
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.library_books),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Community',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    );
  }

  void _showAssignmentDetails(Map<String, dynamic> assignment) {
    final hasSubmitted = submissions.containsKey(assignment['id']);
    final submission = submissions[assignment['id']];
    final dueDate = assignment['dueDate'] as Timestamp?;
    final isDuePassed = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

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
            Container(
              margin: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignment['title'] ?? 'Assignment',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasSubmitted
                                ? Colors.green.withValues(alpha: 0.1)
                                : (isDuePassed
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasSubmitted
                                ? 'Submitted'
                                : (isDuePassed ? 'Missing' : 'Pending'),
                            style: TextStyle(
                              color: hasSubmitted
                                  ? Colors.green
                                  : (isDuePassed ? Colors.red : Colors.orange),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (dueDate != null)
                      Text(
                        'Due: ${_formatDate(dueDate)}',
                        style: TextStyle(
                          color: isDuePassed ? Colors.red : Colors.grey[600],
                          fontSize: 14,
                          fontWeight: isDuePassed ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    SizedBox(height: 16),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      assignment['description'] ?? 'No description provided',
                      style: TextStyle(fontSize: 14),
                    ),
                    if (assignment['content'] != null) ...[
                      SizedBox(height: 16),
                      Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            assignment['content'],
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    if (hasSubmitted && submission != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Submission Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Submitted: ${_formatDate(submission['submittedAt'])}',
                              style: TextStyle(fontSize: 14),
                            ),
                            if (submission['fileName'] != null)
                              Text(
                                'File: ${submission['fileName']}',
                                style: TextStyle(fontSize: 14),
                              ),
                            if (submission['grade'] != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'Grade: ${submission['grade']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                            if (submission['feedback'] != null) ...[
                              SizedBox(height: 8),
                              Text(
                                'Feedback: ${submission['feedback']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    if (!hasSubmitted && !isDuePassed)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _submitAssignment(assignment);
                          },
                          icon: Icon(Icons.upload, color: Colors.white),
                          label: Text('Submit Assignment', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[400],
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}