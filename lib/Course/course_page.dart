import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_hub/Course/create_assignment.dart';

import 'assignment_details.dart';
import 'create_material.dart';
import 'material_details.dart';


class CoursePage extends StatefulWidget {
  final String courseId;

  const CoursePage({Key? key, required this.courseId}) : super(key: key);

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with TickerProviderStateMixin {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? courseData;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  List<Map<String, dynamic>> enrolledStudents = [];
  bool isLoading = true;
  String? errorMessage;
  bool showCreateOptions = false;
  bool isLecturer = false;
  int _currentIndex = 2; // Course tab is selected
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB visibility
    });
    _fetchCourseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourseData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // First, find which lecturer owns this course
      QuerySnapshot lecturerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'lecturer')
          .get();

      String? lecturerUid;
      for (var doc in lecturerQuery.docs) {
        var courseDoc = await _firestore
            .collection('users')
            .doc(doc.id)
            .collection('courses')
            .doc(widget.courseId)
            .get();

        if (courseDoc.exists) {
          lecturerUid = doc.id;
          final courseDocData = courseDoc.data();
          final lecturerDocData = doc.data() as Map<String, dynamic>?;
          setState(() {
            courseData = {
              if (courseDocData != null) ...courseDocData,
              'lecturerName': lecturerDocData?['name'] ?? 'Unknown Lecturer',
              'lecturerUid': lecturerUid,
            };
            isLecturer = currentUser.uid == lecturerUid;
          });
          break;
        }
      }

      if (lecturerUid != null) {
        await Future.wait([
          _fetchAssignments(lecturerUid),
          _fetchMaterials(lecturerUid),
          _fetchEnrolledStudents(lecturerUid),
        ]);
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading course data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAssignments(String lecturerUid) async {
    var assignmentQuery = await _firestore
        .collection('users')
        .doc(lecturerUid)
        .collection('courses')
        .doc(widget.courseId)
        .collection('assignments')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      assignments = assignmentQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'id': doc.id,
          if (data != null) ...data,
        };
      }).toList();
    });
  }

  Future<void> _fetchMaterials(String lecturerUid) async {
    var materialQuery = await _firestore
        .collection('users')
        .doc(lecturerUid)
        .collection('courses')
        .doc(widget.courseId)
        .collection('materials')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      materials = materialQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return {
          'id': doc.id,
          if (data != null) ...data,
        };
      }).toList();
    });
  }

  Future<void> _fetchEnrolledStudents(String lecturerUid) async {
    try {
      var enrollmentQuery = await _firestore
          .collection('users')
          .doc(lecturerUid)
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in enrollmentQuery.docs) {
        String studentId = doc.data()['studentId'];
        var studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          students.add({
            'id': studentId,
            'name': studentDoc.data()?['name'] ?? 'Unknown Student',
            'email': studentDoc.data()?['email'] ?? 'No email',
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

  void _showCreateDialog() {
    setState(() {
      showCreateOptions = !showCreateOptions;
    });
  }

  void _navigateToCreateAssignment() async {
    setState(() {
      showCreateOptions = false;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAssignmentPage(
          courseId: widget.courseId,
          courseData: courseData!,
        ),
      ),
    );

    if (result == true) {
      _fetchAssignments(courseData!['lecturerUid']);
    }
  }

  void _navigateToCreateMaterial() async {
    setState(() {
      showCreateOptions = false;
    });

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaterialPage(
          courseId: widget.courseId,
          courseData: courseData!,
        ),
      ),
    );

    if (result == true) {
      _fetchMaterials(courseData!['lecturerUid']);
    }
  }

  void _navigateToAssignmentDetail(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignmentDetailPage(
          assignment: assignment,
          courseId: widget.courseId,
          courseData: courseData!,
          isLecturer: isLecturer,
        ),
      ),
    );
  }

  void _navigateToMaterialDetail(Map<String, dynamic> material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialDetailPage(
          material: material,
          courseId: widget.courseId,
          courseData: courseData!,
          isLecturer: isLecturer,
        ),
      ),
    );
  }

  void _showEnrollStudentDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enroll Student'),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Student Email',
            border: OutlineInputBorder(),
            hintText: 'Enter student email address',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter student email')),
                );
                return;
              }

              try {
                // Find student by email
                var studentQuery = await _firestore
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .where('role', isEqualTo: 'student')
                    .get();

                if (studentQuery.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Student not found with this email')),
                  );
                  return;
                }

                String studentId = studentQuery.docs.first.id;

                // Check if already enrolled
                var existingEnrollment = await _firestore
                    .collection('users')
                    .doc(courseData!['lecturerUid'])
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('enrollments')
                    .where('studentId', isEqualTo: studentId)
                    .get();

                if (existingEnrollment.docs.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Student is already enrolled in this course')),
                  );
                  Navigator.pop(context);
                  return;
                }

                // Enroll student
                await _firestore
                    .collection('users')
                    .doc(courseData!['lecturerUid'])
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('enrollments')
                    .add({
                  'studentId': studentId,
                  'enrolledAt': FieldValue.serverTimestamp(),
                  'enrolledBy': _auth.currentUser!.uid,
                });

                // Also add course to student's enrolled courses
                await _firestore
                    .collection('users')
                    .doc(studentId)
                    .collection('enrolledCourses')
                    .doc(widget.courseId)
                    .set({
                  'courseId': widget.courseId,
                  'lecturerUid': courseData!['lecturerUid'],
                  'enrolledAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                _fetchEnrolledStudents(courseData!['lecturerUid']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Student enrolled successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error enrolling student: $e')),
                );
              }
            },
            child: Text('Enroll'),
          ),
        ],
      ),
    );
  }

  void _removeStudent(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Student'),
        content: Text('Are you sure you want to remove $studentName from this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Remove from course enrollments
                var enrollmentQuery = await _firestore
                    .collection('users')
                    .doc(courseData!['lecturerUid'])
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('enrollments')
                    .where('studentId', isEqualTo: studentId)
                    .get();

                for (var doc in enrollmentQuery.docs) {
                  await doc.reference.delete();
                }

                // Remove from student's enrolled courses
                await _firestore
                    .collection('users')
                    .doc(studentId)
                    .collection('enrolledCourses')
                    .doc(widget.courseId)
                    .delete();

                Navigator.pop(context);
                _fetchEnrolledStudents(courseData!['lecturerUid']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Student removed successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error removing student: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showCreateOptions) ...[
          Container(
            margin: EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToCreateAssignment,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Assignment', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _navigateToCreateMaterial,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Material', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showCreateDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentItem({
    required String title,
    required String subtitle,
    required String date,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFFE8E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue, size: 28),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
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
        trailing: isLecturer && onDelete != null
            ? IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        )
            : null,
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildStudentItem(Map<String, dynamic> student) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFFE8E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            student['name'].toString().substring(0, 1).toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student['name']?.toString() ?? 'Unknown Student',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student['email']?.toString() ?? 'No email',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Enrolled: ${_formatDate(student['enrolledAt'])}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isLecturer
            ? IconButton(
          icon: Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () => _removeStudent(
              student['id'],
              student['name']?.toString() ?? 'Unknown Student'
          ),
        )
            : null,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Assignments
          ...assignments.map((assignment) => _buildContentItem(
            title: assignment['title']?.toString() ?? 'Assignment',
            subtitle: assignment['description']?.toString() ?? 'No description',
            date: _formatDate(assignment['createdAt']),
            icon: Icons.assignment,
            onTap: () => _navigateToAssignmentDetail(assignment),
            onDelete: isLecturer ? () async {
              try {
                await _firestore
                    .collection('users')
                    .doc(courseData!['lecturerUid'])
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('assignments')
                    .doc(assignment['id'])
                    .delete();
                _fetchAssignments(courseData!['lecturerUid']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Assignment deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting assignment: $e')),
                );
              }
            } : null,
          )),

          // Materials
          ...materials.map((material) => _buildContentItem(
            title: material['title']?.toString() ?? 'Material',
            subtitle: material['description']?.toString() ?? 'No description',
            date: _formatDate(material['createdAt']),
            icon: Icons.description,
            onTap: () => _navigateToMaterialDetail(material),
            onDelete: isLecturer ? () async {
              try {
                await _firestore
                    .collection('users')
                    .doc(courseData!['lecturerUid'])
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('materials')
                    .doc(material['id'])
                    .delete();
                _fetchMaterials(courseData!['lecturerUid']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Material deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting material: $e')),
                );
              }
            } : null,
          )),

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
                    isLecturer
                        ? 'No assignments or materials yet.\nTap + to create content.'
                        : 'No assignments or materials available yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 100), // Space for floating button
        ],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        if (isLecturer)
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showEnrollStudentDialog,
              icon: Icon(Icons.person_add),
              label: Text('Enroll Student'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        Expanded(
          child: enrolledStudents.isEmpty
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
                  isLecturer
                      ? 'No students enrolled yet.\nTap "Enroll Student" to add students.'
                      : 'No students enrolled in this course yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: enrolledStudents.length,
            itemBuilder: (context, index) {
              return _buildStudentItem(enrolledStudents[index]);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            'StudyHub',
            style: TextStyle(
              fontFamily: 'Abeezee',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.menu, color: Colors.blue),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: Colors.blue),
                  onPressed: () {},
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('StudyHub'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage!),
              ElevatedButton(
                onPressed: _fetchCourseData,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'StudyHub',
          style: TextStyle(
            fontFamily: 'Abeezee',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.blue),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Colors.blue),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Course Header with Create Button
            // Course Header with Create Button
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFE8E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseData?['title']?.toString() ?? 'Course Title',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7DB3),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    courseData?['description']?.toString() ?? 'Course description not available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    courseData?['lecturerName']?.toString() ?? 'Lecturer name not available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7DB3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Row containing students enrolled text and Create Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${enrolledStudents.length} students enrolled',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (isLecturer && _tabController.index == 0)
                        _buildCreateButton(),
                    ],
                  ),
                ],
              ),
            ),
            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Content'),
                Tab(text: 'Students'),
                Tab(text: 'Overview'),
              ],
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Handle navigation based on index
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.grey[200],
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Course',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Evaluation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
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
                  'Students',
                  enrolledStudents.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Assignments',
                  assignments.length.toString(),
                  Icons.assignment,
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
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Content',
                  (assignments.length + materials.length).toString(),
                  Icons.library_books,
                  Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),

          // Combine and sort recent items
          ...(_getRecentActivity().map((item) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFE8E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item['type'] == 'assignment' ? Icons.assignment : Icons.description,
                  color: Colors.blue,
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
              ],
            ),
          ))),

          if (assignments.isEmpty && materials.isEmpty)
            Container(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No activity yet. Start by creating assignments or materials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
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

  List<Map<String, dynamic>> _getRecentActivity() {
    List<Map<String, dynamic>> recentItems = [];

    // Add assignments
    for (var assignment in assignments) {
      recentItems.add({
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
}