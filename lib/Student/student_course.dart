import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Student/student_submit_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../Course/feedback.dart';

class StudentCoursePage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final String? focusAssignmentId;

  const StudentCoursePage({
    Key? key,
    required this.courseId,
    required this.courseData,
    this.focusAssignmentId,
  }) : super(key: key);

  @override
  _StudentCoursePageState createState() => _StudentCoursePageState();
}

class _StudentCoursePageState extends State<StudentCoursePage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Data
  String? _organizationCode;
  String? _studentId;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> enrolledStudents = [];
  Map<String, Map<String, dynamic>> submissionStatus = {};
  Map<String, bool> hasRubric = {};

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
        _studentId = user.uid;
      });

      // Load course content
      await Future.wait([
        _fetchAssignments(),
        _fetchMaterials(),
        _fetchEnrolledStudents(),
        _fetchSubmissionStatus(),
      ]);

      setState(() {
        isLoading = false;
      });

      // If focusAssignmentId is provided, switch to content tab
      if (widget.focusAssignmentId != null) {
        _tabController.animateTo(0);
      }
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

      List<Map<String, dynamic>> fetchedAssignments = [];
      Map<String, bool> rubricStatus = {};

      for (var doc in assignmentQuery.docs) {
        final assignmentData = {
          'id': doc.id,
          ...doc.data(),
        };
        fetchedAssignments.add(assignmentData);

        // Check if assignment has rubric
        final rubricDoc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(doc.id)
            .collection('rubric')
            .doc('main')
            .get();

        rubricStatus[doc.id] = rubricDoc.exists;
      }

      setState(() {
        assignments = fetchedAssignments;
        hasRubric = rubricStatus;
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

  Future<void> _fetchEnrolledStudents() async {
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
            'enrolledAt': doc.data()['enrolledAt'],
          });
        }
      }

      setState(() {
        enrolledStudents = students;
      });
    } catch (e) {
      print('Error fetching enrolled students: $e');
    }
  }

  Future<void> _fetchSubmissionStatus() async {
    if (_organizationCode == null || _studentId == null) return;

    try {
      Map<String, Map<String, dynamic>> status = {};

      for (var assignment in assignments) {
        var submissionQuery = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .where('studentId', isEqualTo: _studentId)
            .orderBy('submittedAt', descending: true)
            .get();

        if (submissionQuery.docs.isNotEmpty) {
          final latestSubmission = submissionQuery.docs.first;

          // Check if evaluation exists
          final evalDoc = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(_organizationCode)
              .collection('courses')
              .doc(widget.courseId)
              .collection('assignments')
              .doc(assignment['id'])
              .collection('submissions')
              .doc(latestSubmission.id)
              .collection('evaluations')
              .doc('current')
              .get();

          status[assignment['id']] = {
            'submitted': true,
            'submissionId': latestSubmission.id,
            'submittedAt': latestSubmission.data()['submittedAt'],
            'fileUrl': latestSubmission.data()['fileUrl'],
            'fileName': latestSubmission.data()['fileName'],
            'grade': latestSubmission.data()['grade'],
            'feedback': latestSubmission.data()['feedback'],
            'hasDetailedEvaluation': evalDoc.exists,
            'submissionCount': submissionQuery.docs.length,
          };
        } else {
          status[assignment['id']] = {'submitted': false};
        }
      }

      setState(() {
        submissionStatus = status;
      });
    } catch (e) {
      print('Error fetching submission status: $e');
    }
  }

  void _navigateToSubmissionView(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentSubmissionView(
          courseId: widget.courseId,
          assignmentId: assignment['id'],
          assignmentData: assignment,
          organizationCode: _organizationCode!,
        ),
      ),
    ).then((_) => _fetchSubmissionStatus());
  }

  void _navigateToFeedbackHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackHistoryPage(
          courseId: widget.courseId,
          organizationCode: _organizationCode!,
          studentId: _studentId,
          isStudent: true,
        ),
      ),
    );
  }

  void _navigateToMaterialDetail(Map<String, dynamic> material) {
    _showMaterialDetailDialog(material);
  }

  void _showMaterialDetailDialog(Map<String, dynamic> material) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 600,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      material['title'] ?? 'Material',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Material Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        material['description'] ?? 'No description available',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 16),

                      // Content
                      if (material['content'] != null) ...[
                        Text(
                          'Content',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          material['content'],
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Upload Date
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            'Uploaded: ${_formatDate(material['createdAt'])}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Files
                      if (material['attachments'] != null && (material['attachments'] as List).isNotEmpty) ...[
                        Text(
                          'Files',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...(material['attachments'] as List).map((attachment) {
                          return InkWell(
                            onTap: () => _launchUrl(attachment['url']),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getFileIcon(attachment['name'] ?? ''),
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      attachment['name'] ?? 'File',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.download, color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAssignment(Map<String, dynamic> assignment) async {
    final dueDate = assignment['dueDate'] as Timestamp?;
    final isOverdue = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

    if (isOverdue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot submit - assignment is overdue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'jpg', 'jpeg', 'png', 'zip'],
      );

      if (result != null) {
        setState(() => isLoading = true);

        PlatformFile file = result.files.first;

        // Upload file to Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('submissions')
            .child(widget.courseId)
            .child(assignment['id'])
            .child('${_studentId}_${DateTime.now().millisecondsSinceEpoch}_${file.name}');

        final uploadTask = ref.putData(file.bytes!);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Create submission document
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignment['id'])
            .collection('submissions')
            .add({
          'studentId': _studentId,
          'submittedAt': FieldValue.serverTimestamp(),
          'fileUrl': downloadUrl,
          'fileName': file.name,
          'fileSize': file.size,
          'status': 'submitted',
        });

        await _fetchSubmissionStatus();
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to submission view
        _navigateToSubmissionView(assignment);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting assignment: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
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
                    if (widget.courseData['courseTemplateId'] != null) ...[
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
                            Icon(Icons.link, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Course Template',
                              style: TextStyle(
                                color: Colors.white,
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
                    Icon(Icons.people, color: Colors.white.withValues(alpha: 0.9), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '${enrolledStudents.length} students',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
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
                Tab(text: 'Students'),
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
                _buildStudentsTab(),
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
          icon: Icon(Icons.feedback_outlined, color: Colors.purple[600]),
          onPressed: _navigateToFeedbackHistory,
          tooltip: 'Feedback History',
        ),
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
          _fetchSubmissionStatus(),
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
              ...assignments.map((assignment) {
                final submission = submissionStatus[assignment['id']] ?? {'submitted': false};
                final dueDate = assignment['dueDate'] as Timestamp?;
                final isOverdue = dueDate != null && dueDate.toDate().isBefore(DateTime.now());

                return _buildAssignmentCard(
                  assignment: assignment,
                  submission: submission,
                  isOverdue: isOverdue,
                  highlighted: widget.focusAssignmentId == assignment['id'],
                );
              }),
              SizedBox(height: 24),
            ],

            // Materials Section
            if (materials.isNotEmpty) ...[
              _buildSectionHeader('Materials', Icons.description),
              ...materials.map((material) => _buildContentCard(
                title: material['title'] ?? 'Material',
                subtitle: material['description'] ?? 'No description',
                date: _formatDate(material['createdAt']),
                icon: Icons.description,
                color: Colors.green,
                onTap: () => _navigateToMaterialDetail(material),
              )),
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

  Widget _buildAssignmentCard({
    required Map<String, dynamic> assignment,
    required Map<String, dynamic> submission,
    required bool isOverdue,
    bool highlighted = false,
  }) {
    final hasAssignmentRubric = hasRubric[assignment['id']] ?? false;
    final hasDetailedEvaluation = submission['hasDetailedEvaluation'] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: highlighted ? Colors.purple[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: highlighted ? Border.all(color: Colors.purple[400]!, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: submission['submitted']
            ? () => _navigateToSubmissionView(assignment)
            : () => _showSubmitDialog(assignment, isOverdue),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.assignment, color: Colors.orange, size: 28),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                assignment['title'] ?? 'Assignment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (hasAssignmentRubric)
                              Container(
                                margin: EdgeInsets.only(left: 4),
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.rule,
                                  size: 16,
                                  color: Colors.purple[600],
                                ),
                              ),
                          ],
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
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isOverdue ? Colors.red : Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Due: ${_formatDate(assignment['dueDate'])}',
                              style: TextStyle(
                                color: isOverdue ? Colors.red : Colors.grey[500],
                                fontSize: 12,
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (assignment['points'] != null) ...[
                              SizedBox(width: 12),
                              Icon(Icons.grade, size: 14, color: Colors.grey[500]),
                              SizedBox(width: 4),
                              Text(
                                '${assignment['points']} pts',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildSubmissionStatus(submission, hasDetailedEvaluation),
                ],
              ),
              if (submission['submitted'] && submission['submissionCount'] != null && submission['submissionCount'] > 1) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        '${submission['submissionCount']} submissions',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
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

  Widget _buildSubmissionStatus(Map<String, dynamic> submission, bool hasDetailedEvaluation) {
    if (submission['submitted']) {
      final hasGrade = submission['grade'] != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasGrade)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grade, size: 16, color: Colors.green[700]),
                  SizedBox(width: 4),
                  Text(
                    '${submission['grade']}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Text(
                'Submitted',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (hasDetailedEvaluation) ...[
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.feedback, size: 12, color: Colors.purple[600]),
                  SizedBox(width: 4),
                  Text(
                    'View Feedback',
                    style: TextStyle(
                      color: Colors.purple[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Text(
          'Pending',
          style: TextStyle(
            color: Colors.orange[700],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  void _showSubmitDialog(Map<String, dynamic> assignment, bool isOverdue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Submit Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assignment['title'] ?? 'Assignment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            if (isOverdue)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This assignment is overdue and cannot be submitted.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'Select a file to submit for this assignment.',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          if (!isOverdue)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitAssignment(assignment);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Choose File', style: TextStyle(color: Colors.white)),
            ),
        ],
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

  Widget _buildContentCard({
    required String title,
    required String subtitle,
    required String date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    return enrolledStudents.isEmpty
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
            'No students enrolled in this course yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _fetchEnrolledStudents,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: enrolledStudents.length,
        itemBuilder: (context, index) {
          return _buildStudentCard(enrolledStudents[index]);
        },
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
    final totalAssignments = assignments.length;
    final submittedAssignments = submissionStatus.values.where((s) => s['submitted'] == true).length;
    final gradedAssignments = submissionStatus.values.where((s) => s['grade'] != null).length;
    final pendingAssignments = totalAssignments - submittedAssignments;

    // Calculate average grade
    double totalGrade = 0;
    int gradedCount = 0;
    submissionStatus.values.forEach((submission) {
      if (submission['grade'] != null) {
        totalGrade += submission['grade'];
        gradedCount++;
      }
    });
    final averageGrade = gradedCount > 0 ? (totalGrade / gradedCount).toStringAsFixed(1) : 'N/A';

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Submitted',
                  submittedAssignments.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Graded',
                  gradedAssignments.toString(),
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
                  'Pending',
                  pendingAssignments.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Grade',
                  averageGrade,
                  Icons.analytics,
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
                _buildDetailRow('Created', _formatDate(widget.courseData['createdAt'])),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          ...(_getRecentActivity().map((item) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
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
                Icon(
                  item['type'] == 'assignment' ? Icons.assignment : Icons.description,
                  color: Colors.purple[400],
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(item['createdAt']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item['type'] == 'assignment' && submissionStatus[item['id']]?['grade'] != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${submissionStatus[item['id']]!['grade']}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ))),
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
          icon: Icon(Icons.home),
          label: 'Home',
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

  List<Map<String, dynamic>> _getRecentActivity() {
    List<Map<String, dynamic>> recentItems = [];

    // Add assignments
    for (var assignment in assignments) {
      recentItems.add({
        'id': assignment['id'],
        'title': assignment['title'] ?? 'Assignment',
        'type': 'assignment',
        'createdAt': assignment['createdAt'],
      });
    }

    // Add materials
    for (var material in materials) {
      recentItems.add({
        'title': material['title'] ?? 'Material',
        'type': 'material',
        'createdAt': material['createdAt'],
      });
    }

    // Sort by creation date (most recent first)
    recentItems.sort((a, b) {
      if (a['createdAt'] == null && b['createdAt'] == null) return 0;
      if (a['createdAt'] == null) return 1;
      if (b['createdAt'] == null) return -1;

      DateTime dateA = a['createdAt'] is Timestamp
          ? (a['createdAt'] as Timestamp).toDate()
          : a['createdAt'] as DateTime;
      DateTime dateB = b['createdAt'] is Timestamp
          ? (b['createdAt'] as Timestamp).toDate()
          : b['createdAt'] as DateTime;

      return dateB.compareTo(dateA);
    });

    // Return only the most recent 5 items
    return recentItems.take(5).toList();
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