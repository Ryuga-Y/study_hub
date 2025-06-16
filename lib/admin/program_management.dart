import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgramManagementPage extends StatefulWidget {
  final String organizationId;

  const ProgramManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _ProgramManagementPageState createState() => _ProgramManagementPageState();
}

class _ProgramManagementPageState extends State<ProgramManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();

  String _searchQuery = '';
  String _selectedFaculty = 'all';
  List<Map<String, dynamic>> _faculties = [];
  String? _selectedFacultyForNewProgram;

  @override
  void initState() {
    super.initState();
    _loadFaculties();
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
                            'Program Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage academic programs across all faculties',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _faculties.isEmpty ? null : () => _showAddProgramDialog(),
                      icon: Icon(Icons.add),
                      label: Text('Add Program'),
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
                          hintText: 'Search programs...',
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
                : _buildProgramsList(),
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
            'Please add faculties before creating programs',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to faculties page
              // This would be handled by the parent dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Go to Faculties'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramsList() {
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
                  Expanded(flex: 2, child: Text('Program Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Students', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Table content
            Expanded(
              child: _buildProgramsStreamBuilder(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsStreamBuilder() {
    if (_selectedFaculty == 'all') {
      // Show programs from all faculties
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAllPrograms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyProgramsState();
          }

          final programs = snapshot.data!.where((program) {
            if (_searchQuery.isEmpty) return true;
            final name = program['name'].toString().toLowerCase();
            final code = program['code'].toString().toLowerCase();
            return name.contains(_searchQuery) || code.contains(_searchQuery);
          }).toList();

          if (programs.isEmpty) {
            return _buildEmptyProgramsState();
          }

          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) => _buildProgramRow(programs[index]),
          );
        },
      );
    } else {
      // Show programs from selected faculty
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(_selectedFaculty)
            .collection('programs')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyProgramsState();
          }

          final programs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (_searchQuery.isEmpty) return true;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final code = (data['code'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || code.contains(_searchQuery);
          }).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final faculty = _faculties.firstWhere(
                  (f) => f['id'] == _selectedFaculty,
              orElse: () => {'name': 'Unknown', 'code': 'N/A'},
            );
            return {
              'id': doc.id,
              'facultyId': _selectedFaculty,
              'facultyName': faculty['name'],
              'facultyCode': faculty['code'],
              ...data,
            };
          }).toList();

          if (programs.isEmpty) {
            return _buildEmptyProgramsState();
          }

          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) => _buildProgramRow(programs[index]),
          );
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getAllPrograms() async {
    List<Map<String, dynamic>> allPrograms = [];

    for (var faculty in _faculties) {
      final programsSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(faculty['id'])
          .collection('programs')
          .get();

      for (var doc in programsSnapshot.docs) {
        final data = doc.data();
        allPrograms.add({
          'id': doc.id,
          'facultyId': faculty['id'],
          'facultyName': faculty['name'],
          'facultyCode': faculty['code'],
          ...data,
        });
      }
    }

    return allPrograms;
  }

  Widget _buildProgramRow(Map<String, dynamic> program) {
    final isActive = program['isActive'] ?? true;

    return FutureBuilder<int>(
      future: _getStudentCount(program['facultyId'], program['id']),
      builder: (context, snapshot) {
        final studentCount = snapshot.data ?? 0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program['name'] ?? 'Unnamed Program',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (program['description'] != null && program['description'].toString().isNotEmpty)
                      Text(
                        program['description'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    program['code'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  program['facultyCode'] ?? 'N/A',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Expanded(
                child: Text(
                  '${program['duration'] ?? 'N/A'} years',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '$studentCount',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Switch(
                  value: isActive,
                  onChanged: (value) => _toggleProgramStatus(
                    program['facultyId'],
                    program['id'],
                    value,
                  ),
                  activeColor: Colors.green,
                ),
              ),
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditProgramDialog(program),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteProgram(
                        program['facultyId'],
                        program['id'],
                        program['name'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _getStudentCount(String facultyId, String programId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: widget.organizationId)
        .where('role', isEqualTo: 'student')
        .where('facultyId', isEqualTo: facultyId)
        .where('programId', isEqualTo: programId)
        .where('isActive', isEqualTo: true)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Widget _buildEmptyProgramsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No programs found',
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

  void _showAddProgramDialog({Map<String, dynamic>? existingProgram}) {
    if (existingProgram != null) {
      _nameController.text = existingProgram['name'] ?? '';
      _codeController.text = existingProgram['code'] ?? '';
      _descriptionController.text = existingProgram['description'] ?? '';
      _durationController.text = existingProgram['duration']?.toString() ?? '';
      _selectedFacultyForNewProgram = existingProgram['facultyId'];
    } else {
      _nameController.clear();
      _codeController.clear();
      _descriptionController.clear();
      _durationController.text = '4';
      _selectedFacultyForNewProgram = _faculties.isNotEmpty ? _faculties.first['id'] : null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(existingProgram == null ? 'Add New Program' : 'Edit Program'),
        content: Container(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedFacultyForNewProgram,
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    border: OutlineInputBorder(),
                  ),
                  items: _faculties.map((faculty) => DropdownMenuItem<String>(
                    value: faculty['id'].toString(),
                    child: Text('${faculty['code']} - ${faculty['name']}'),
                  )).toList(),
                  onChanged: existingProgram == null
                      ? (value) {
                    setState(() {
                      _selectedFacultyForNewProgram = value;
                    });
                  }
                      : null,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a faculty';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Program Name',
                    hintText: 'e.g., Bachelor of Computer Science',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter program name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Program Code',
                    hintText: 'e.g., BCS',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter program code';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (Years)',
                    hintText: 'e.g., 4',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter duration';
                    }
                    final duration = int.tryParse(value);
                    if (duration == null || duration < 1 || duration > 10) {
                      return 'Please enter a valid duration (1-10 years)';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of the program',
                    border: OutlineInputBorder(),
                  ),
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
            onPressed: () => _saveProgram(existingProgram),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(existingProgram == null ? 'Add Program' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showEditProgramDialog(Map<String, dynamic> program) {
    _showAddProgramDialog(existingProgram: program);
  }

  Future<void> _saveProgram(Map<String, dynamic>? existingProgram) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final programData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'description': _descriptionController.text.trim(),
        'duration': int.parse(_durationController.text.trim()),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingProgram == null) {
        // Adding new program
        programData['createdAt'] = FieldValue.serverTimestamp();
        programData['isActive'] = true;

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(_selectedFacultyForNewProgram!)
            .collection('programs')
            .add(programData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Program added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Updating existing program
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(existingProgram['facultyId'])
            .collection('programs')
            .doc(existingProgram['id'])
            .update(programData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Program updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving program: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleProgramStatus(String facultyId, String programId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .doc(programId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Program status updated'),
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

  void _deleteProgram(String facultyId, String programId, String programName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this program?'),
            SizedBox(height: 8),
            Text(
              programName,
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
                      'This will affect all students enrolled in this program',
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
                    .delete();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Program deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting program'),
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
    _durationController.dispose();
    super.dispose();
  }
}