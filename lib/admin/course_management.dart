import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Authentication/auth_services.dart';

class CourseManagementPage extends StatefulWidget {
  final String organizationId;

  const CourseManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _CourseManagementPageState createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showInactiveCourses = false;
  String? _selectedFacultyId;
  String? _selectedProgramId;
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _baseCourses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadFaculties();
    await _loadBaseCourses();
  }

  Future<void> _loadBaseCourses() async {
    try {
      List<Map<String, dynamic>> allCourseTemplates = [];

      // Load all faculties first (without isActive filter for debugging)
      final facultiesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .get();

      // For each faculty, load programs and then course templates
      for (var facultyDoc in facultiesSnapshot.docs) {
        final facultyData = facultyDoc.data();
        final facultyId = facultyDoc.id;

        // Load programs for this faculty (without isActive filter for debugging)
        final programsSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(facultyId)
            .collection('programs')
            .get();

        // For each program, load course templates
        for (var programDoc in programsSnapshot.docs) {
          final programData = programDoc.data();
          final programId = programDoc.id;

          // Load course templates (without any filters for debugging)
          final templatesSnapshot = await FirebaseFirestore.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('faculties')
              .doc(facultyId)
              .collection('programs')
              .doc(programId)
              .collection('courseTemplates')
              .get();

          // Add course templates with full hierarchy info
          for (var templateDoc in templatesSnapshot.docs) {
            final templateData = templateDoc.data();

            // Only include if isActive is true or doesn't exist
            if (templateData['isActive'] != false) {
              allCourseTemplates.add({
                'id': templateDoc.id,
                'name': templateData['name'],
                'code': templateData['code'],
                'defaultDescription': templateData['defaultDescription'],
                'facultyId': facultyId,
                'facultyName': facultyData['name'],
                'facultyCode': facultyData['code'],
                'programId': programId,
                'programName': programData['name'],
                'programCode': programData['code'],
              });
            }
          }
        }
      }

      setState(() {
        _baseCourses = allCourseTemplates;
      });
    } catch (e) {
      print('Error loading course templates: $e');
    }
  }

  Future<void> _loadFaculties() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _faculties = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'],
          'code': doc.data()['code'],
        }).toList();
      });
    } catch (e) {
      print('Error loading faculties: $e');
    }
  }

  Future<void> _loadPrograms(String facultyId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _programs = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'],
          'code': doc.data()['code'],
        }).toList();
      });
    } catch (e) {
      print('Error loading programs: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Course Management',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (MediaQuery.of(context).size.width > 600)
                          TextButton.icon(
                            onPressed: () => setState(() => _showInactiveCourses = !_showInactiveCourses),
                            icon: Icon(
                              _showInactiveCourses ? Icons.visibility : Icons.visibility_off,
                              size: 16,
                            ),
                            label: Text(
                              _showInactiveCourses ? 'All Courses' : 'Active Only',
                              style: TextStyle(fontSize: 15),
                            ),
                          )
                        else
                          IconButton(
                            onPressed: () => setState(() => _showInactiveCourses = !_showInactiveCourses),
                            icon: Icon(
                              _showInactiveCourses ? Icons.visibility : Icons.visibility_off,
                            ),
                            tooltip: _showInactiveCourses ? 'All Courses' : 'Active Only',
                          ),
                        SizedBox(width: 8),
                        MediaQuery.of(context).size.width > 400
                            ? ElevatedButton.icon(
                          onPressed: () => _showAddCourseDialog(context),
                          icon: Icon(Icons.add, color: Colors.white, size: 20),
                          label: Text('Add Course', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                            : ElevatedButton(
                          onPressed: () => _showAddCourseDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.all(8),
                            minimumSize: Size(40, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Filters Row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // Search bar
                    Container(
                      width: MediaQuery.of(context).size.width > 800 ? 300 : double.infinity,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search courses by name or code...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                      ),
                    ),
                    // Faculty Filter
                    Container(
                      width: MediaQuery.of(context).size.width > 800 ? 250 : double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: _selectedFacultyId,
                        isExpanded: true,  // Add this to expand dropdown items
                        decoration: InputDecoration(
                          labelText: 'Filter by Faculty',
                          prefixIcon: Icon(Icons.school),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All Faculties'),
                          ),
                          ..._faculties.map((faculty) => DropdownMenuItem<String>(
                            value: faculty['id'] as String,
                            child: Text(
                              faculty['name'],
                              overflow: TextOverflow.ellipsis,  // Add overflow handling
                              maxLines: 1,
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFacultyId = value;
                            _selectedProgramId = null;
                            _programs = [];
                          });
                          if (value != null) {
                            _loadPrograms(value);
                          }
                        },
                      ),
                    ),
                    // Program Filter
                    if (_selectedFacultyId != null && _programs.isNotEmpty)
                      Container(
                        width: MediaQuery.of(context).size.width > 800 ? 250 : double.infinity,
                        child: DropdownButtonFormField<String>(
                          value: _selectedProgramId,
                          isExpanded: true,  // Add this to expand dropdown items
                          decoration: InputDecoration(
                            labelText: 'Filter by Program',
                            prefixIcon: Icon(Icons.book),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('All Programs'),
                            ),
                            ..._programs.map((program) => DropdownMenuItem<String>(
                              value: program['id'] as String,
                              child: Text(
                                program['name'],
                                overflow: TextOverflow.ellipsis,  // Add overflow handling
                                maxLines: 1,
                              ),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedProgramId = value);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Template Courses Section
          Container(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Course Templates',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () => _showCourseTemplatesList(context),
                  child: Text('View All (${_baseCourses.length})'),
                ),
              ],
            ),
          ),

          // Course List
          Expanded(
            child: _buildCourseList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    Query query = FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('courses');

    if (!_showInactiveCourses) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (_selectedFacultyId != null) {
      query = query.where('facultyId', isEqualTo: _selectedFacultyId);
    }

    if (_selectedProgramId != null) {
      query = query.where('programId', isEqualTo: _selectedProgramId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final courses = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final code = data['code']?.toString().toLowerCase() ?? '';
          return name.contains(_searchQuery) || code.contains(_searchQuery);
        }).toList();

        if (courses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No courses match your search',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(24),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            final data = course.data() as Map<String, dynamic>;
            return _buildCourseCard(course.id, data);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No courses found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _showInactiveCourses ? 'No courses in your organization' : 'No active courses',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Lecturers can create courses from base courses',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(String courseId, Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Course Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.library_books,
                    size: 32,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 16),

                // Course Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            data['name'] ?? 'Unknown Course',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['code'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.cancel,
                                  size: 12,
                                  color: isActive ? Colors.green[700] : Colors.red[700],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive ? Colors.green[700] : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      // Faculty and Program info
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          if (data['facultyName'] != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school, size: 14, color: Colors.grey[500]),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    data['facultyName'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (data['programName'] != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.book, size: 14, color: Colors.grey[500]),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    data['programName'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (data['lecturerName'] != null) ...[
                        SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                data['lecturerName'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          data['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 12),
                          Text('Edit Course'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 18,
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                          SizedBox(width: 12),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete Course', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditCourseDialog(context, courseId, data);
                        break;
                      case 'activate':
                      case 'deactivate':
                        _toggleCourseStatus(courseId, !isActive, data);
                        break;
                      case 'delete':
                        _showDeleteDialog(context, courseId, data['name'], data);
                        break;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final defaultDescriptionController = TextEditingController();
    String? selectedFacultyId;
    String? selectedProgramId;
    List<Map<String, dynamic>> tempPrograms = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Add Course Template'),
          content: Container(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Faculty Selection
                  DropdownButtonFormField<String>(
                    value: selectedFacultyId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Faculty *',
                      prefixIcon: Icon(Icons.school),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _faculties.map((faculty) => DropdownMenuItem<String>(
                      value: faculty['id'] as String,
                      child: Text(
                        '${faculty['name']} (${faculty['code']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedFacultyId = value;
                        selectedProgramId = null;
                        tempPrograms = [];
                      });
                      if (value != null) {
                        // Load programs for selected faculty
                        final snapshot = await FirebaseFirestore.instance
                            .collection('organizations')
                            .doc(widget.organizationId)
                            .collection('faculties')
                            .doc(value)
                            .collection('programs')
                            .where('isActive', isEqualTo: true)
                            .get();

                        setState(() {
                          tempPrograms = snapshot.docs.map((doc) => {
                            'id': doc.id,
                            'name': doc.data()['name'],
                            'code': doc.data()['code'],
                          }).toList();
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  // Program Selection
                  if (tempPrograms.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedProgramId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Program *',
                        prefixIcon: Icon(Icons.book),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: tempPrograms.map((program) => DropdownMenuItem<String>(
                        value: program['id'] as String,
                        child: Text(
                          '${program['name']} (${program['code']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedProgramId = value),
                    ),
                  if (tempPrograms.isNotEmpty) SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Course Name *',
                      hintText: 'e.g., Introduction to Programming',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Course Code *',
                      hintText: 'e.g., CS101',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: defaultDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Default Description',
                      hintText: 'Default description for this course',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Store context references before async operations
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                if (selectedFacultyId == null ||
                    selectedProgramId == null ||
                    nameController.text.isEmpty ||
                    codeController.text.isEmpty) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final selectedFaculty = _faculties.firstWhere((f) => f['id'] == selectedFacultyId);
                  final selectedProgram = tempPrograms.firstWhere((p) => p['id'] == selectedProgramId);

                  final templateData = {
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim().toUpperCase(),
                    'defaultDescription': defaultDescriptionController.text.trim(),
                    'facultyId': selectedFacultyId,
                    'facultyName': selectedFaculty['name'],
                    'facultyCode': selectedFaculty['code'],
                    'programId': selectedProgramId,
                    'programName': selectedProgram['name'],
                    'programCode': selectedProgram['code'],
                    'isActive': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  };

                  await FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(widget.organizationId)
                      .collection('faculties')
                      .doc(selectedFacultyId)
                      .collection('programs')
                      .doc(selectedProgramId)
                      .collection('courseTemplates')
                      .add(templateData);

                  // Create audit log
                  await AuthService.createManagementAuditLog(
                    organizationCode: widget.organizationId,
                    action: 'course_template_created',
                    details: {
                      'courseName': templateData['name'],
                      'courseCode': templateData['code'],
                      'facultyName': selectedFaculty['name'],
                      'programName': selectedProgram['name'],
                      'description': templateData['defaultDescription'],
                    },
                  );

                  navigator.pop();
                  _loadBaseCourses();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Course template added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error adding course template: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Course', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCourseTemplatesList(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 700,
          height: 600,
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Course Templates',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // Adds "..." if text is too long
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: _baseCourses.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text('No course templates created yet', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: _baseCourses.length,
                  itemBuilder: (context, index) {
                    final courseTemplate = _baseCourses[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.library_books, color: Colors.blue[700]),
                        ),
                        title: Text(
                          courseTemplate['name'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Code: ${courseTemplate['code']}'),
                            Text(
                              'Faculty: ${courseTemplate['facultyName']} > Program: ${courseTemplate['programName']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (courseTemplate['defaultDescription'] != null && courseTemplate['defaultDescription'].isNotEmpty)
                              Text(
                                courseTemplate['defaultDescription'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            Navigator.pop(context);
                            if (value == 'edit') {
                              _showEditCourseTemplateDialog(context, courseTemplate);
                            } else if (value == 'delete') {
                              _deleteCourseTemplate(courseTemplate);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCourseTemplateDialog(BuildContext context, Map<String, dynamic> courseTemplate) {
    final nameController = TextEditingController(text: courseTemplate['name']);
    final codeController = TextEditingController(text: courseTemplate['code']);
    final defaultDescriptionController = TextEditingController(text: courseTemplate['defaultDescription'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Edit Course Template'),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display faculty and program info (read-only)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, size: 20, color: Colors.grey[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Faculty: ${courseTemplate['facultyName']} (${courseTemplate['facultyCode']})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.book, size: 20, color: Colors.grey[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Program: ${courseTemplate['programName']} (${courseTemplate['programCode']})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Course Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: defaultDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Default Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store context references before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final updatedData = {
                  'name': nameController.text.trim(),
                  'code': codeController.text.trim().toUpperCase(),
                  'defaultDescription': defaultDescriptionController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                };

                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('faculties')
                    .doc(courseTemplate['facultyId'])
                    .collection('programs')
                    .doc(courseTemplate['programId'])
                    .collection('courseTemplates')
                    .doc(courseTemplate['id'])
                    .update(updatedData);

                // Create audit log
                await AuthService.createManagementAuditLog(
                  organizationCode: widget.organizationId,
                  action: 'course_template_updated',
                  details: {
                    'courseTemplateId': courseTemplate['id'],
                    'oldName': courseTemplate['name'],
                    'newName': updatedData['name'],
                    'oldCode': courseTemplate['code'],
                    'newCode': updatedData['code'],
                    'facultyName': courseTemplate['facultyName'],
                    'programName': courseTemplate['programName'],
                  },
                );

                navigator.pop();
                _loadBaseCourses();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Course template updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error updating course template: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Update Course', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteCourseTemplate(Map<String, dynamic> courseTemplate) async {
    // Store context reference before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Course Template'),
        content: Text('Are you sure you want to delete this course template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(courseTemplate['facultyId'])
            .collection('programs')
            .doc(courseTemplate['programId'])
            .collection('courseTemplates')
            .doc(courseTemplate['id'])
            .delete();

        // Create audit log
        await AuthService.createManagementAuditLog(
          organizationCode: widget.organizationId,
          action: 'course_template_deleted',
          details: {
            'courseTemplateId': courseTemplate['id'],
            'courseName': courseTemplate['name'],
            'courseCode': courseTemplate['code'],
            'facultyName': courseTemplate['facultyName'],
            'programName': courseTemplate['programName'],
          },
        );

        _loadBaseCourses();

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Course template deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error deleting course template: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditCourseDialog(BuildContext context, String courseId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final codeController = TextEditingController(text: data['code']);
    final descriptionController = TextEditingController(text: data['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Edit Course'),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display faculty and program info (read-only)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school, size: 20, color: Colors.grey[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${data['facultyName']} (${data['facultyCode']})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (data['programName'] != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.book, size: 20, color: Colors.grey[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${data['programName']} (${data['programCode']})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Course Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'Course Code *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store context references before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final updatedData = {
                  'name': nameController.text.trim(),
                  'code': codeController.text.trim().toUpperCase(),
                  'description': descriptionController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                };

                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('courses')
                    .doc(courseId)
                    .update(updatedData);

                // Create audit log
                await AuthService.createManagementAuditLog(
                  organizationCode: widget.organizationId,
                  action: 'course_updated',
                  details: {
                    'courseId': courseId,
                    'oldName': data['name'],
                    'newName': updatedData['name'],
                    'oldCode': data['code'],
                    'newCode': updatedData['code'],
                    'facultyName': data['facultyName'],
                    'programName': data['programName'],
                  },
                );

                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Course updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error updating course: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Update Course', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleCourseStatus(String courseId, bool isActive, Map<String, dynamic> data) async {
    // Store context reference before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('courses')
          .doc(courseId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Create audit log
      await AuthService.createManagementAuditLog(
        organizationCode: widget.organizationId,
        action: isActive ? 'course_activated' : 'course_deactivated',
        details: {
          'courseId': courseId,
          'courseName': data['name'],
          'courseCode': data['code'],
          'facultyName': data['facultyName'],
          'programName': data['programName'],
          'newStatus': isActive ? 'active' : 'inactive',
        },
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Course activated successfully' : 'Course deactivated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error updating course status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, String courseId, String courseName, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$courseName"?'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All course data will be permanently deleted.',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store context references before async operations
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('courses')
                    .doc(courseId)
                    .delete();

                // Create audit log
                await AuthService.createManagementAuditLog(
                  organizationCode: widget.organizationId,
                  action: 'course_deleted',
                  details: {
                    'courseId': courseId,
                    'courseName': data['name'],
                    'courseCode': data['code'],
                    'facultyName': data['facultyName'],
                    'programName': data['programName'],
                  },
                );

                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Course deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error deleting course: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}