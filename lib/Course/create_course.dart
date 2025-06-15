import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateCoursePage extends StatefulWidget {
  final String lecturerUid;

  const CreateCoursePage({Key? key, required this.lecturerUid}) : super(key: key);

  @override
  _CreateCoursePageState createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _manualEmailController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourseId;
  String? _selectedCourseTitle;
  String? _lecturerFaculty;
  String? _lecturerName;

  List<Map<String, dynamic>> _facultyStudents = [];
  List<String> _selectedStudentIds = [];
  List<String> _manuallyAddedEmails = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Course codes and titles for each faculty
  final Map<String, List<Map<String, String>>> facultyCourses = {
    'FAFB': [
      {'code': 'FAFB1001', 'title': 'Principles of Accounting'},
      {'code': 'FAFB1002', 'title': 'Financial Management'},
      {'code': 'FAFB1003', 'title': 'Business Statistics'},
      {'code': 'FAFB2001', 'title': 'Corporate Finance'},
      {'code': 'FAFB2002', 'title': 'Marketing Management'},
      {'code': 'FAFB2003', 'title': 'Business Ethics'},
      {'code': 'FAFB3001', 'title': 'Strategic Management'},
      {'code': 'FAFB3002', 'title': 'Investment Analysis'},
      {'code': 'FAFB3003', 'title': 'Entrepreneurship'},
      {'code': 'FAFB4001', 'title': 'International Business'},
    ],
    'FOAS': [
      {'code': 'FOAS1001', 'title': 'General Chemistry'},
      {'code': 'FOAS1002', 'title': 'Cell Biology'},
      {'code': 'FOAS1003', 'title': 'Physics Fundamentals'},
      {'code': 'FOAS2001', 'title': 'Organic Chemistry'},
      {'code': 'FOAS2002', 'title': 'Genetics'},
      {'code': 'FOAS2003', 'title': 'Quantum Physics'},
      {'code': 'FOAS3001', 'title': 'Biochemistry'},
      {'code': 'FOAS3002', 'title': 'Molecular Biology'},
      {'code': 'FOAS3003', 'title': 'Environmental Science'},
      {'code': 'FOAS4001', 'title': 'Research Methods in Science'},
    ],
    'FOCS': [
      {'code': 'FOCS1001', 'title': 'Programming Fundamentals'},
      {'code': 'FOCS1002', 'title': 'Data Structures'},
      {'code': 'FOCS1003', 'title': 'Database Systems'},
      {'code': 'FOCS2001', 'title': 'Web Development'},
      {'code': 'FOCS2002', 'title': 'Operating Systems'},
      {'code': 'FOCS2003', 'title': 'Software Engineering'},
      {'code': 'FOCS3001', 'title': 'Artificial Intelligence'},
      {'code': 'FOCS3002', 'title': 'Mobile App Development'},
      {'code': 'FOCS3003', 'title': 'Computer Networks'},
      {'code': 'FOCS4001', 'title': 'Machine Learning'},
    ],
    'FOBE': [
      {'code': 'FOBE1001', 'title': 'Architectural Design I'},
      {'code': 'FOBE1002', 'title': 'Building Technology'},
      {'code': 'FOBE1003', 'title': 'Construction Materials'},
      {'code': 'FOBE2001', 'title': 'Structural Analysis'},
      {'code': 'FOBE2002', 'title': 'Urban Planning'},
      {'code': 'FOBE2003', 'title': 'Building Services'},
      {'code': 'FOBE3001', 'title': 'Sustainable Architecture'},
      {'code': 'FOBE3002', 'title': 'Project Management'},
      {'code': 'FOBE3003', 'title': 'Construction Law'},
      {'code': 'FOBE4001', 'title': 'Advanced Building Design'},
    ],
    'FOET': [
      {'code': 'FOET1001', 'title': 'Engineering Mathematics'},
      {'code': 'FOET1002', 'title': 'Circuit Theory'},
      {'code': 'FOET1003', 'title': 'Thermodynamics'},
      {'code': 'FOET2001', 'title': 'Electronics'},
      {'code': 'FOET2002', 'title': 'Mechanics of Materials'},
      {'code': 'FOET2003', 'title': 'Fluid Mechanics'},
      {'code': 'FOET3001', 'title': 'Control Systems'},
      {'code': 'FOET3002', 'title': 'Power Systems'},
      {'code': 'FOET3003', 'title': 'Manufacturing Processes'},
      {'code': 'FOET4001', 'title': 'Engineering Design Project'},
    ],
    'FCCI': [
      {'code': 'FCCI1001', 'title': 'Introduction to Communication'},
      {'code': 'FCCI1002', 'title': 'Design Principles'},
      {'code': 'FCCI1003', 'title': 'Digital Media Production'},
      {'code': 'FCCI2001', 'title': 'Advertising and PR'},
      {'code': 'FCCI2002', 'title': 'Typography and Layout'},
      {'code': 'FCCI2003', 'title': 'Video Production'},
      {'code': 'FCCI3001', 'title': 'Brand Development'},
      {'code': 'FCCI3002', 'title': 'Interactive Design'},
      {'code': 'FCCI3003', 'title': 'Media Ethics'},
      {'code': 'FCCI4001', 'title': 'Creative Campaign Development'},
    ],
    'FSSH': [
      {'code': 'FSSH1001', 'title': 'Introduction to Psychology'},
      {'code': 'FSSH1002', 'title': 'English Literature'},
      {'code': 'FSSH1003', 'title': 'Public Speaking'},
      {'code': 'FSSH2001', 'title': 'Cognitive Psychology'},
      {'code': 'FSSH2002', 'title': 'Linguistics'},
      {'code': 'FSSH2003', 'title': 'Media and Society'},
      {'code': 'FSSH3001', 'title': 'Research Methods'},
      {'code': 'FSSH3002', 'title': 'Organizational Communication'},
      {'code': 'FSSH3003', 'title': 'Social Psychology'},
      {'code': 'FSSH4001', 'title': 'Applied Psychology'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchLecturerData();
  }

  Future<void> _fetchLecturerData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch lecturer data
      DocumentSnapshot lecturerDoc = await _firestore
          .collection('users')
          .doc(widget.lecturerUid)
          .get();

      if (lecturerDoc.exists) {
        setState(() {
          _lecturerFaculty = lecturerDoc['faculty'];
          _lecturerName = lecturerDoc['name'];
        });

        // Fetch students from the same faculty
        if (_lecturerFaculty != null) {
          QuerySnapshot studentQuery = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('faculty', isEqualTo: _lecturerFaculty)
              .get();

          setState(() {
            _facultyStudents = studentQuery.docs.map((doc) {
              return {
                'uid': doc.id,
                'name': doc['name'],
                'email': doc['email'],
                'program': doc['program'] ?? 'N/A',
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, String>> getCoursesForFaculty() {
    if (_lecturerFaculty == null) return [];
    return facultyCourses[_lecturerFaculty] ?? [];
  }

  void _addManualEmail() {
    final email = _manualEmailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        if (!_manuallyAddedEmails.contains(email)) {
          _manuallyAddedEmails.add(email);
          _manualEmailController.clear();
        }
      });
    }
  }

  Future<void> _createCourse() async {
    if (_formKey.currentState!.validate() && _selectedCourseId != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Create course document
        Map<String, dynamic> courseData = {
          'courseId': _selectedCourseId,
          'title': _selectedCourseTitle,
          'description': _descriptionController.text.trim(),
          'lecturerUid': widget.lecturerUid,
          'lecturerName': _lecturerName,
          'faculty': _lecturerFaculty,
          'createdAt': FieldValue.serverTimestamp(),
          'enrolledStudents': [],
        };

        // Add course to lecturer's courses collection
        DocumentReference courseRef = await _firestore
            .collection('users')
            .doc(widget.lecturerUid)
            .collection('courses')
            .add(courseData);

        // Also add to global courses collection for easier querying
        await _firestore
            .collection('courses')
            .doc(courseRef.id)
            .set({
          ...courseData,
          'docId': courseRef.id,
        });

        // Enroll selected students
        List<String> allEnrolledStudentIds = [];

        // Add selected students from faculty
        allEnrolledStudentIds.addAll(_selectedStudentIds);

        // Add manually entered students (by email)
        for (String email in _manuallyAddedEmails) {
          QuerySnapshot userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .where('role', isEqualTo: 'student')
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            allEnrolledStudentIds.add(userQuery.docs.first.id);
          }
        }

        // Update course with enrolled students
        if (allEnrolledStudentIds.isNotEmpty) {
          await courseRef.update({
            'enrolledStudents': allEnrolledStudentIds,
          });

          await _firestore
              .collection('courses')
              .doc(courseRef.id)
              .update({
            'enrolledStudents': allEnrolledStudentIds,
          });

          // Add course to each student's enrolled courses
          for (String studentId in allEnrolledStudentIds) {
            await _firestore
                .collection('users')
                .doc(studentId)
                .collection('enrolledCourses')
                .doc(courseRef.id)
                .set({
              'courseId': _selectedCourseId,
              'courseDocId': courseRef.id,
              'title': _selectedCourseTitle,
              'lecturerName': _lecturerName,
              'enrolledAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Course created successfully!',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(20),
          ),
        );

        // Navigate back
        Navigator.pop(context);
      } catch (e) {
        setState(() {
          _errorMessage = 'Error creating course: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _manualEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = getCoursesForFaculty();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Create New Course'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _facultyStudents.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Course selection card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Course Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Course dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCourseId,
                        itemHeight: 60, // Increased height to accommodate both lines
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedCourseId = value;
                            _selectedCourseTitle = courses
                                .firstWhere((course) => course['code'] == value)['title'];
                          });
                        },
                        selectedItemBuilder: (BuildContext context) {
                          return courses.map((course) {
                            return Container(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${course['code']} - ${course['title']}',
                                style: TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList();
                        },
                        items: courses.map((course) {
                          return DropdownMenuItem<String>(
                            value: course['code'],
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    course['code']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    course['title']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                          labelText: 'Select Course',
                          prefixIcon: Icon(Icons.book, color: Colors.blueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a course';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Course description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Course Description',
                          prefixIcon: Icon(Icons.description, color: Colors.blueAccent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter course description';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Student enrollment card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Enrollment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select students from your faculty or add by email',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 16),

                      // Faculty students list
                      if (_facultyStudents.isNotEmpty) ...[
                        Text(
                          'Students in $_lecturerFaculty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _facultyStudents.length,
                            itemBuilder: (context, index) {
                              final student = _facultyStudents[index];
                              final isSelected = _selectedStudentIds.contains(student['uid']);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStudentIds.add(student['uid']);
                                    } else {
                                      _selectedStudentIds.remove(student['uid']);
                                    }
                                  });
                                },
                                title: Text(student['name']),
                                subtitle: Text('${student['email']} • ${student['program']}'),
                                dense: true,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Manual email entry
                      Text(
                        'Add Students by Email',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualEmailController,
                              decoration: InputDecoration(
                                hintText: 'Enter student email',
                                prefixIcon: Icon(Icons.email, color: Colors.blueAccent),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addManualEmail,
                            child: Icon(Icons.add),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),

                      // Display manually added emails
                      if (_manuallyAddedEmails.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _manuallyAddedEmails.map((email) {
                            return Chip(
                              label: Text(email),
                              deleteIcon: Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _manuallyAddedEmails.remove(email);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Create Course',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}