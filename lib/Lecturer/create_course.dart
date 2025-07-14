import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';

class CreateCoursePage extends StatefulWidget {
  @override
  _CreateCoursePageState createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _descriptionController = TextEditingController();

  // Data
  Map<String, dynamic>? _userData;
  String? _organizationCode;
  String? _selectedBaseCourseId;
  List<Map<String, dynamic>> _baseCourses = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'User not authenticated');
        return;
      }

      final userData = await _authService.getUserData(user.uid);
      if (userData == null) {
        setState(() => _errorMessage = 'User data not found');
        return;
      }

      setState(() {
        _userData = userData;
        _organizationCode = userData['organizationCode'];
      });

      await _loadBaseCourses();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: $e';
      });
    }
  }

  Future<void> _loadBaseCourses() async {
    if (_organizationCode == null || _userData == null) return;

    try {
      List<Map<String, dynamic>> courseTemplates = [];

      // Get the lecturer's faculty
      final lecturerFacultyId = _userData!['facultyId'];

      if (lecturerFacultyId != null) {
        // Load programs for lecturer's faculty
        final programsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(_organizationCode)
            .collection('faculties')
            .doc(lecturerFacultyId)
            .collection('programs')
            .where('isActive', isEqualTo: true)
            .get();

        // For each program, load course templates
        for (var programDoc in programsSnapshot.docs) {
          final programData = programDoc.data();
          final programId = programDoc.id;

          final templatesSnapshot = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(_organizationCode)
              .collection('faculties')
              .doc(lecturerFacultyId)
              .collection('programs')
              .doc(programId)
              .collection('courseTemplates')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

          // Add course templates
          for (var templateDoc in templatesSnapshot.docs) {
            courseTemplates.add({
              'id': templateDoc.id,
              'name': templateDoc.data()['name'],
              'code': templateDoc.data()['code'],
              'defaultDescription': templateDoc.data()['defaultDescription'],
              'facultyId': lecturerFacultyId,
              'programId': programId,
              'programName': programData['name'],
            });
          }
        }
      }

      setState(() {
        _baseCourses = courseTemplates;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading course templates: $e';
      });
    }
  }

  Future<void> _createCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBaseCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a course template'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null || _organizationCode == null) {
        throw Exception('User not authenticated or organization not found');
      }

      // Get selected course template details
      final selectedCourseTemplate = _baseCourses.firstWhere(
            (course) => course['id'] == _selectedBaseCourseId,
      );

      // Create course data
      final courseData = {
        'courseTemplateId': _selectedBaseCourseId,
        'courseTemplateName': selectedCourseTemplate['name'],
        'code': selectedCourseTemplate['code'],
        'name': selectedCourseTemplate['name'], // Use course template name
        'title': selectedCourseTemplate['name'], // Keep for backward compatibility
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : selectedCourseTemplate['defaultDescription'] ?? '',
        'facultyId': _userData?['facultyId'],
        'facultyName': _userData?['facultyName'] ?? _userData?['faculty'] ?? '',
        'programId': selectedCourseTemplate['programId'],
        'programName': selectedCourseTemplate['programName'],
        'lecturerId': user.uid,
        'lecturerName': _userData?['fullName'] ?? 'Unknown',
        'enrolledCount': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add course to organization's courses collection
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationCode)
          .collection('courses')
          .add(courseData);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course created successfully!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Navigate back with success result
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating course: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Create New Course',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_userData == null && _errorMessage == null) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
        ),
      );
    }

    return Form(
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

            // Course Information Card
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
                    'Course Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[600],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Course Template Selection
                  if (_baseCourses.isEmpty)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No course templates available for your faculty. Contact your administrator to create course templates.',
                              style: TextStyle(color: Colors.orange[700]),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedBaseCourseId,
                      isExpanded: true,  // IMPORTANT: This prevents overflow
                      menuMaxHeight: 300,  // Limit dropdown height
                      decoration: InputDecoration(
                        labelText: 'Select Course Template *',
                        hintText: 'Choose a course template',
                        prefixIcon: Icon(Icons.library_books, color: Colors.purple[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      // Custom builder for selected item display
                      selectedItemBuilder: (BuildContext context) {
                        return _baseCourses.map<Widget>((courseTemplate) {
                          return Container(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${courseTemplate['code']} - ${courseTemplate['name']}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList();
                      },
                      // Dropdown menu items
                      items: _baseCourses.map((courseTemplate) => DropdownMenuItem<String>(
                        value: courseTemplate['id'] as String,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      courseTemplate['code'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple[800],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      courseTemplate['name'],
                                      style: TextStyle(fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Program: ${courseTemplate['programName']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBaseCourseId = value;
                          // Pre-fill description if available
                          if (value != null) {
                            final selectedCourse = _baseCourses.firstWhere(
                                  (course) => course['id'] == value,
                            );
                            if (selectedCourse['defaultDescription'] != null &&
                                selectedCourse['defaultDescription'].isNotEmpty &&
                                _descriptionController.text.isEmpty) {
                              _descriptionController.text = selectedCourse['defaultDescription'];
                            }
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a course template';
                        }
                        return null;
                      },
                    ),

                    // Show selected course details below dropdown
                    if (_selectedBaseCourseId != null) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 20, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Course Template',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Builder(builder: (context) {
                                    final selected = _baseCourses.firstWhere(
                                          (c) => c['id'] == _selectedBaseCourseId,
                                    );
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${selected['code']} - ${selected['name']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Program: ${selected['programName']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[600],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: 16),

                  // Course Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Course Description *',
                      hintText: 'Enter a description for this course section',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.description, color: Colors.purple[400]),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter course description';
                      }
                      return null;
                    },
                  ),

                  // Faculty Information (Read-only)
                  if (_userData != null) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.school, size: 20, color: Colors.grey[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Faculty',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _userData!['facultyName'] ?? _userData!['faculty'] ?? 'Not specified',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),

            // Additional Information Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.purple[600],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'After creating this course, you can enroll students from your faculty or manually add them by email.',
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isLoading ? 'Creating...' : 'Create Course',
                onPressed: _isLoading || _baseCourses.isEmpty ? () {} : _createCourse,
                isLoading: _isLoading,
              ),
            ),
            SizedBox(height: 16),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.purple[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.purple[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}