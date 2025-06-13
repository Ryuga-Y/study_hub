import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoursePage extends StatefulWidget {
  final String courseId;

  const CoursePage({Key? key, required this.courseId}) : super(key: key);

  @override
  _CoursePageState createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? courseData;
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> materials = [];
  bool isLoading = true;
  String? errorMessage;
  bool showCreateOptions = false;
  bool isLecturer = false;
  int _currentIndex = 2; // Course tab is selected

  @override
  void initState() {
    super.initState();
    _fetchCourseData();
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
        // Fetch assignments
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

        // Fetch materials
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

  void _showCreateDialog() {
    setState(() {
      showCreateOptions = !showCreateOptions;
    });
  }

  void _createAssignment() {
    // Navigate to create assignment page
    // Navigator.push(context, MaterialPageRoute(builder: (context) => CreateAssignmentPage(courseId: widget.courseId)));
    setState(() {
      showCreateOptions = false;
    });
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Create Assignment feature coming soon')),
    );
  }

  void _createMaterial() {
    // Navigate to create material page
    // Navigator.push(context, MaterialPageRoute(builder: (context) => CreateMaterialPage(courseId: widget.courseId)));
    setState(() {
      showCreateOptions = false;
    });
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Create Material feature coming soon')),
    );
  }

  Widget _buildCreateButton() {
    return Stack(
      children: [
        Positioned(
          bottom: 80,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showCreateDialog,
            backgroundColor: Colors.lightBlue,
            child: Icon(Icons.add, color: Colors.white),
          ),
        ),
        if (showCreateOptions)
          Positioned(
            bottom: 140,
            right: 16,
            child: Container(
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
                  ListTile(
                    leading: Icon(Icons.assignment, color: Colors.blue),
                    title: Text('Assignment'),
                    onTap: _createAssignment,
                    dense: true,
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.description, color: Colors.blue),
                    title: Text('Material'),
                    onTap: _createMaterial,
                    dense: true,
                  ),
                ],
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
        onTap: onTap,
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
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Course Header
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
                    ],
                  ),
                ),

                // Content List
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Assignments
                        ...assignments.map((assignment) => _buildContentItem(
                          title: assignment['title']?.toString() ?? 'Assignment',
                          subtitle: assignment['description']?.toString() ?? 'No description',
                          date: _formatDate(assignment['createdAt']),
                          icon: Icons.assignment,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening ${assignment['title']?.toString() ?? 'Assignment'}')),
                            );
                          },
                        )),

                        // Materials
                        ...materials.map((material) => _buildContentItem(
                          title: material['title']?.toString() ?? 'Material',
                          subtitle: material['description']?.toString() ?? 'No description',
                          date: _formatDate(material['createdAt']),
                          icon: Icons.description,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Opening ${material['title']?.toString() ?? 'Material'}')),
                            );
                          },
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
                  ),
                ),
              ],
            ),
          ),

          // Floating Action Button (only for lecturers)
          if (isLecturer) _buildCreateButton(),
        ],
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
}