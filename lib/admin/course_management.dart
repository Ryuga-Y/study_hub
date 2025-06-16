import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseManagementPage extends StatefulWidget {
  final String organizationId;

  const CourseManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _CourseManagementPageState createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _creditsController = TextEditingController();

  String _searchQuery = '';
  String _selectedFaculty = 'all';
  String _selectedProgram = 'all';
  String _selectedSemester = 'all';
  String? _selectedFacultyForNewCourse;
  String? _selectedProgramForNewCourse;
  String? _selectedSemesterForNewCourse;
  String? _selectedLecturer;

  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _programsForNewCourse = [];
  List<Map<String, dynamic>> _lecturers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadFaculties();
    await _loadLecturers();
    if (_selectedFaculty != 'all') {
      await _loadPrograms(_selectedFaculty);
    }
  }

  Future<void> _loadFaculties() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('faculties')
        .where('isActive', isEqualTo: true)
        .get();

    setState(() {
      _faculties = snapshot.docs
          .where((doc) => doc.id != '_placeholder')
          .map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'code': doc['code'],
      }).toList();
    });
  }

  Future<void> _loadPrograms(String facultyId) async {
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
        'name': doc['name'],
        'code': doc['code'],
      }).toList();
    });
  }

  Future<void> _loadProgramsForNewCourse(String facultyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('faculties')
        .doc(facultyId)
        .collection('programs')
        .where('isActive', isEqualTo: true)
        .get();

    setState(() {
      _programsForNewCourse = snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['name'],
        'code': doc['code'],
      }).toList();
    });
  }

  Future<void> _loadLecturers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: widget.organizationId)
        .where('role', isEqualTo: 'lecturer')
        .where('isActive', isEqualTo: true)
        .get();

    setState(() {
      _lecturers = snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['fullName'],
        'email': doc['email'],
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Course Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage courses across all programs',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _faculties.isEmpty ? null : () => _showAddCourseDialog(),
                      icon: Icon(Icons.add),
                      label: Text('Add Course'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search courses...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Faculty filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFaculty,
                        decoration: InputDecoration(
                          labelText: 'Faculty',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Faculties')),
                          ..._faculties.map((faculty) => DropdownMenuItem(
                            value: faculty['id'],
                            child: Text(faculty['code'] ?? ''),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFaculty = value!;
                            _selectedProgram = 'all';
                            if (value != 'all') {
                              _loadPrograms(value);
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Program filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedProgram,
                        decoration: InputDecoration(
                          labelText: 'Program',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Programs')),
                          ..._programs.map((program) => DropdownMenuItem(
                            value: program['id'],
                            child: Text(program['code'] ?? ''),
                          )),
                        ],
                        onChanged: _selectedFaculty == 'all' ? null : (value) {
                          setState(() {
                            _selectedProgram = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Semester filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSemester,
                        decoration: InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Semesters')),
                          DropdownMenuItem(value: '1', child: Text('Semester 1')),
                          DropdownMenuItem(value: '2', child: Text('Semester 2')),
                          DropdownMenuItem(value: '3', child: Text('Semester 3')),
                          DropdownMenuItem(value: '4', child: Text('Semester 4')),
                          DropdownMenuItem(value: '5', child: Text('Semester 5')),
                          DropdownMenuItem(value: '6', child: Text('Semester 6')),
                          DropdownMenuItem(value: '7', child: Text('Semester 7')),
                          DropdownMenuItem(value: '8', child: Text('Semester 8')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSemester = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _faculties.isEmpty
                ? _buildNoFacultiesState()
                : _buildCoursesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFacultiesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.orange[300],
          ),
          SizedBox(height: 16),
          Text(
            'No Active Faculties',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please add faculties and programs before creating courses',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          children: [
            // Table header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Course Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Program', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Semester', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Credits', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Lecturer', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Table content
            Expanded(
              child: _buildCoursesStreamBuilder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesStreamBuilder() {
    if (_selectedFaculty == 'all') {
      // Show courses from all faculties
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAllCourses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyCoursesState();
          }

          final courses = snapshot.data!.where((course) {
            if (_searchQuery.isNotEmpty) {
              final name = course['name'].toString().toLowerCase();
              final code = course['code'].toString().toLowerCase();
              if (!name.contains(_searchQuery) && !code.contains(_searchQuery)) {
                return false;
              }
            }

            if (_selectedSemester != 'all' && course['semester'].toString() != _selectedSemester) {
              return false;
            }

            return true;
          }).toList();

          if (courses.isEmpty) {
            return _buildEmptyCoursesState();
          }

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) => _buildCourseRow(courses[index]),
          );
        },
      );
    } else {
      // Show courses from selected faculty/program
      return _buildFilteredCourses();
    }
  }

  Widget _buildFilteredCourses() {
    if (_selectedProgram == 'all') {
      // Get courses from all programs in the faculty
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getCoursesForFaculty(_selectedFaculty),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyCoursesState();
          }

          final courses = _filterCourses(snapshot.data!);

          if (courses.isEmpty) {
            return _buildEmptyCoursesState();
          }

          return ListView.builder(
            itemCount: courses.length,
            itemBuilder: (context, index) => _buildCourseRow(courses[index]),
          );
        },
      );
    } else {
      // Get courses from specific program
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(_selectedFaculty)
            .collection('programs')
            .doc(_selectedProgram)
            .collection('courses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyCoursesState();
          }

          final faculty = _faculties.firstWhere(
                (f) => f['id'] == _selectedFaculty,
            orElse: () => {'name': 'Unknown', 'code': 'N/A'},
          );
          final program = _programs.firstWhere(
                (p) => p['id'] == _selectedProgram,
            orElse: () => {'name': 'Unknown', 'code': 'N/A'},
          );

          final courses = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'facultyId': _selectedFaculty,
              'programId': _selectedProgram,
              'facultyName': faculty['name'],
              'facultyCode': faculty['code'],
              'programName': program['name'],
              'programCode': program['code'],
              ...data,
            };
          }).toList();

          final filteredCourses = _filterCourses(courses);

          if (filteredCourses.isEmpty) {
            return _buildEmptyCoursesState();
          }

          return ListView.builder(
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) => _buildCourseRow(filteredCourses[index]),
          );
        },
      );
    }
  }

  List<Map<String, dynamic>> _filterCourses(List<Map<String, dynamic>> courses) {
    return courses.where((course) {
      if (_searchQuery.isNotEmpty) {
        final name = (course['name'] ?? '').toString().toLowerCase();
        final code = (course['code'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery) && !code.contains(_searchQuery)) {
          return false;
        }
      }

      if (_selectedSemester != 'all' && course['semester'].toString() != _selectedSemester) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _getAllCourses() async {
    List<Map<String, dynamic>> allCourses = [];

    for (var faculty in _faculties) {
      final programs = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(faculty['id'])
          .collection('programs')
          .where('isActive', isEqualTo: true)
          .get();

      for (var program in programs.docs) {
        final coursesSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(faculty['id'])
            .collection('programs')
            .doc(program.id)
            .collection('courses')
            .get();

        for (var doc in coursesSnapshot.docs) {
          final data = doc.data();
          allCourses.add({
            'id': doc.id,
            'facultyId': faculty['id'],
            'facultyName': faculty['name'],
            'facultyCode': faculty['code'],
            'programId': program.id,
            'programName': program['name'],
            'programCode': program['code'],
            ...data,
          });
        }
      }
    }

    return allCourses;
  }

  Future<List<Map<String, dynamic>>> _getCoursesForFaculty(String facultyId) async {
    List<Map<String, dynamic>> facultyCourses = [];

    final programs = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('faculties')
        .doc(facultyId)
        .collection('programs')
        .where('isActive', isEqualTo: true)
        .get();

    final faculty = _faculties.firstWhere(
          (f) => f['id'] == facultyId,
      orElse: () => {'name': 'Unknown', 'code': 'N/A'},
    );

    for (var program in programs.docs) {
      final coursesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .doc(program.id)
          .collection('courses')
          .get();

      for (var doc in coursesSnapshot.docs) {
        final data = doc.data();
        facultyCourses.add({
          'id': doc.id,
          'facultyId': facultyId,
          'facultyName': faculty['name'],
          'facultyCode': faculty['code'],
          'programId': program.id,
          'programName': program['name'],
          'programCode': program['code'],
          ...data,
        });
      }
    }

    return facultyCourses;
  }

  Widget _buildCourseRow(Map<String, dynamic> course) {
    final isActive = course['isActive'] ?? true;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Course Name
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course['name'] ?? 'Unnamed Course',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                if (course['description'] != null && course['description'].toString().isNotEmpty)
                  Text(
                    course['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Code
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                course['code'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[700],
                ),
              ),
            ),
          ),

          // Faculty
          Expanded(
            child: Text(
              course['facultyCode'] ?? 'N/A',
              style: TextStyle(fontSize: 14),
            ),
          ),

          // Program
          Expanded(
            child: Text(
              course['programCode'] ?? 'N/A',
              style: TextStyle(fontSize: 14),
            ),
          ),

          // Semester
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Sem ${course['semester'] ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ),

          // Credits
          Expanded(
            child: Text(
              '${course['credits'] ?? 'N/A'} credits',
              style: TextStyle(fontSize: 14),
            ),
          ),

          // Lecturer
          Expanded(
            child: FutureBuilder<String>(
              future: _getLecturerName(course['lecturerId']),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? '-',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),

          // Status
          Expanded(
            child: Switch(
              value: isActive,
              onChanged: (value) => _toggleCourseStatus(
                course['facultyId'],
                course['programId'],
                course['id'],
                value,
              ),
              activeColor: Colors.green,
            ),
          ),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditCourseDialog(course),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deleteCourse(
                    course['facultyId'],
                    course['programId'],
                    course['id'],
                    course['name'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getLecturerName(String? lecturerId) async {
    if (lecturerId == null || lecturerId.isEmpty) return '-';

    final lecturer = _lecturers.firstWhere(
          (l) => l['id'] == lecturerId,
      orElse: () => {'name': '-'},
    );

    return lecturer['name'] ?? '-';
  }

  Widget _buildEmptyCoursesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No courses found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Try adjusting your search criteria',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddCourseDialog({Map<String, dynamic>? existingCourse}) {
    if (existingCourse != null) {
      _nameController.text = existingCourse['name'] ?? '';
      _codeController.text = existingCourse['code'] ?? '';
      _descriptionController.text = existingCourse['description'] ?? '';
      _creditsController.text = existingCourse['credits']?.toString() ?? '';
      _selectedFacultyForNewCourse = existingCourse['facultyId'];
      _selectedProgramForNewCourse = existingCourse['programId'];
      _selectedSemesterForNewCourse = existingCourse['semester']?.toString();
      _selectedLecturer = existingCourse['lecturerId'];
      if (_selectedFacultyForNewCourse != null) {
        _loadProgramsForNewCourse(_selectedFacultyForNewCourse!);
      }
    } else {
      _nameController.clear();
      _codeController.clear();
      _descriptionController.clear();
      _creditsController.text = '3';
      _selectedFacultyForNewCourse = _faculties.isNotEmpty ? _faculties.first['id'] : null;
      _selectedProgramForNewCourse = null;
      _selectedSemesterForNewCourse = '1';
      _selectedLecturer = null;
      if (_selectedFacultyForNewCourse != null) {
        _loadProgramsForNewCourse(_selectedFacultyForNewCourse!);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingCourse == null ? 'Add New Course' : 'Edit Course'),
          content: Container(
            width: 500,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Faculty
                    DropdownButtonFormField<String>(
                      value: _selectedFacultyForNewCourse,
                      decoration: InputDecoration(
                        labelText: 'Faculty',
                        border: OutlineInputBorder(),
                      ),
                      items: _faculties.map((faculty) => DropdownMenuItem<String>(
                        value: faculty['id'].toString(),
                        child: Text('${faculty['code']} - ${faculty['name']}'),
                      )).toList(),
                      onChanged: existingCourse == null ? (value) {
                        setDialogState(() {
                          _selectedFacultyForNewCourse = value;
                          _selectedProgramForNewCourse = null;
                          if (value != null) {
                            _loadProgramsForNewCourse(value);
                          }
                        });
                      } : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a faculty';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Program
                    DropdownButtonFormField<String>(
                      value: _selectedProgramForNewCourse,
                      decoration: InputDecoration(
                        labelText: 'Program',
                        border: OutlineInputBorder(),
                      ),
                      items: _programsForNewCourse.isEmpty
                          ? [DropdownMenuItem(value: null, child: Text('Select Faculty First'))]
                          : _programsForNewCourse.map((program) => DropdownMenuItem<String>(
                        value: program['id'].toString(),
                        child: Text('${program['code']} - ${program['name']}'),
                      )).toList(),
                      onChanged: existingCourse == null ? (value) {
                        setDialogState(() {
                          _selectedProgramForNewCourse = value;
                        });
                      } : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a program';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Course Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Course Name',
                        hintText: 'e.g., Introduction to Programming',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Course Code
                    TextFormField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Course Code',
                        hintText: 'e.g., CS101',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter course code';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Semester and Credits Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSemesterForNewCourse,
                            decoration: InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(8, (index) => DropdownMenuItem(
                              value: (index + 1).toString(),
                              child: Text('Semester ${index + 1}'),
                            )),
                            onChanged: (value) {
                              setDialogState(() {
                                _selectedSemesterForNewCourse = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select semester';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _creditsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Credits',
                              hintText: 'e.g., 3',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter credits';
                              }
                              final credits = int.tryParse(value);
                              if (credits == null || credits < 1 || credits > 10) {
                                return 'Invalid credits (1-10)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Lecturer
                    DropdownButtonFormField<String>(
                      value: _selectedLecturer,
                      decoration: InputDecoration(
                        labelText: 'Lecturer',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Select Lecturer')),
                        ..._lecturers.map((lecturer) => DropdownMenuItem<String>(
                          value: lecturer['id'].toString(),
                          child: Text(lecturer['name'] ?? ''),
                        )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedLecturer = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Brief description of the course',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _saveCourse(existingCourse),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: Text(existingCourse == null ? 'Add Course' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCourseDialog(Map<String, dynamic> course) {
    _showAddCourseDialog(existingCourse: course);
  }

  Future<void> _saveCourse(Map<String, dynamic>? existingCourse) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final courseData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'description': _descriptionController.text.trim(),
        'credits': int.parse(_creditsController.text.trim()),
        'semester': int.parse(_selectedSemesterForNewCourse!),
        'lecturerId': _selectedLecturer ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingCourse == null) {
        // Adding new course
        courseData['createdAt'] = FieldValue.serverTimestamp();
        courseData['isActive'] = true;

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(_selectedFacultyForNewCourse!)
            .collection('programs')
            .doc(_selectedProgramForNewCourse!)
            .collection('courses')
            .add(courseData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Updating existing course
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(existingCourse['facultyId'])
            .collection('programs')
            .doc(existingCourse['programId'])
            .collection('courses')
            .doc(existingCourse['id'])
            .update(courseData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving course: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleCourseStatus(String facultyId, String programId, String courseId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .doc(programId)
          .collection('courses')
          .doc(courseId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course status updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteCourse(String facultyId, String programId, String courseId, String courseName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this course?'),
            SizedBox(height: 8),
            Text(
              courseName,
              style: TextStyle(fontWeight: FontWeight.bold),
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
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will affect all students enrolled in this course',
                      style: TextStyle(color: Colors.orange[700], fontSize: 14),
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
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('faculties')
                    .doc(facultyId)
                    .collection('programs')
                    .doc(programId)
                    .collection('courses')
                    .doc(courseId)
                    .delete();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Course deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting course'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _creditsController.dispose();
    super.dispose();
  }
}