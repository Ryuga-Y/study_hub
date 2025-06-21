import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgramManagementPage extends StatefulWidget {
  final String organizationId;

  const ProgramManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _ProgramManagementPageState createState() => _ProgramManagementPageState();
}

class _ProgramManagementPageState extends State<ProgramManagementPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showInactivePrograms = false;
  String? _selectedFacultyId;
  List<Map<String, dynamic>> _faculties = [];

  @override
  void initState() {
    super.initState();
    _loadFaculties();
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
                        'Program Management',
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
                            onPressed: () => setState(() => _showInactivePrograms = !_showInactivePrograms),
                            icon: Icon(
                              _showInactivePrograms ? Icons.visibility : Icons.visibility_off,
                              size: 16,
                            ),
                            label: Text(
                              _showInactivePrograms ? 'All Programs' : 'Active Only',
                              style: TextStyle(fontSize: 15),
                            ),
                          )
                        else
                          IconButton(
                            onPressed: () => setState(() => _showInactivePrograms = !_showInactivePrograms),
                            icon: Icon(
                              _showInactivePrograms ? Icons.visibility : Icons.visibility_off,
                            ),
                            tooltip: _showInactivePrograms ? 'All Programs' : 'Active Only',
                          ),
                        SizedBox(width: 8),
                        MediaQuery.of(context).size.width > 400
                            ? ElevatedButton.icon(
                          onPressed: () => _showAddProgramDialog(context),
                          icon: Icon(Icons.add, color: Colors.white, size: 20),
                          label: Text('Add Program', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                            : ElevatedButton(
                          onPressed: () => _showAddProgramDialog(context),
                          child: Icon(Icons.add, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.all(8),
                            minimumSize: Size(40, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
                          hintText: 'Search programs by name or code...',
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
                          setState(() => _selectedFacultyId = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Program List
          Expanded(
            child: _buildProgramList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramList() {
    if (_faculties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No faculties found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            Text(
              'Please add faculties before adding programs',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Build a stream that combines all programs from all faculties
    final facultiesToQuery = _selectedFacultyId != null
        ? [_faculties.firstWhere((f) => f['id'] == _selectedFacultyId)]
        : _faculties;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _createProgramsStream(facultiesToQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final programs = snapshot.data!.where((program) {
          final name = program['name']?.toString().toLowerCase() ?? '';
          final code = program['code']?.toString().toLowerCase() ?? '';
          return name.contains(_searchQuery) || code.contains(_searchQuery);
        }).toList();

        if (programs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No programs match your search',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(24),
          itemCount: programs.length,
          itemBuilder: (context, index) {
            final program = programs[index];
            return _buildProgramCard(program);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _createProgramsStream(List<Map<String, dynamic>> faculties) {
    return Stream.fromFuture(() async {
      List<Map<String, dynamic>> allPrograms = [];

      for (var faculty in faculties) {
        Query query = FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(faculty['id'])
            .collection('programs');

        if (!_showInactivePrograms) {
          query = query.where('isActive', isEqualTo: true);
        }

        final snapshot = await query.get();

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          allPrograms.add({
            ...data,
            'id': doc.id,
            'facultyId': faculty['id'],
            'facultyName': faculty['name'],
            'facultyCode': faculty['code'],
          });
        }
      }

      return allPrograms;
    }());
  }

  Widget _buildEmptyState() {
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
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _showInactivePrograms ? 'No programs in your organization' : 'No active programs',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          MediaQuery.of(context).size.width > 400
              ? ElevatedButton.icon(
            onPressed: () => _showAddProgramDialog(context),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text('Add Program', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
              : ElevatedButton(
            onPressed: () => _showAddProgramDialog(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: 8),
                Text('Add', style: TextStyle(color: Colors.white)),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final isActive = program['isActive'] ?? true;

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
                // Program Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.book,
                    size: 32,
                    color: Colors.purple,
                  ),
                ),
                SizedBox(width: 16),

                // Program Info
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
                            program['name'] ?? 'Unknown Program',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              program['code'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple[700],
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
                      Row(
                        children: [
                          Icon(Icons.school, size: 14, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Expanded(  // Add Expanded to handle overflow
                            child: Text(
                              '${program['facultyName']} (${program['facultyCode']})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,  // Add ellipsis for long text
                              maxLines: 1,  // Ensure single line
                            ),
                          ),
                        ],
                      ),
                      if (program['degree'] != null) ...[
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.school_outlined, size: 14, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                program['degree'],
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
                          Text('Edit Program'),
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
                          Text('Delete Program', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditProgramDialog(context, program);
                        break;
                      case 'activate':
                      case 'deactivate':
                        _toggleProgramStatus(program['facultyId'], program['id'], !isActive);
                        break;
                      case 'delete':
                        _showDeleteDialog(context, program);
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

  void _showAddProgramDialog(BuildContext context) {
    if (_faculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add faculties before adding programs'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedFacultyId = _selectedFacultyId;
    String? selectedDegree;

    // Degree type options
    final degreeTypes = ['Foundation', 'Diploma', 'Bachelor Degree'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Add New Program'),
          content: Container(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFacultyId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Faculty *',
                      prefixIcon: Icon(Icons.school),
                      helperText: selectedFacultyId != null
                          ? _faculties.firstWhere((f) => f['id'] == selectedFacultyId)['name']
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _faculties.map((faculty) => DropdownMenuItem<String>(
                      value: faculty['id'] as String,
                      child: Text(faculty['code'] ?? ''),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedFacultyId = value),
                    validator: (value) => value == null ? 'Please select a faculty' : null,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Program Name *',
                      hintText: 'e.g., Computer Science',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Program Code *',
                      hintText: 'e.g., CS',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDegree,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Degree Type *',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: degreeTypes.map((degree) => DropdownMenuItem<String>(
                      value: degree,
                      child: Text(degree),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedDegree = value),
                    validator: (value) => value == null ? 'Please select a degree type' : null,
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
                if (selectedFacultyId == null ||
                    nameController.text.isEmpty ||
                    codeController.text.isEmpty ||
                    selectedDegree == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(widget.organizationId)
                      .collection('faculties')
                      .doc(selectedFacultyId)
                      .collection('programs')
                      .add({
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim().toUpperCase(),
                    'degree': selectedDegree,
                    'isActive': true,
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Program added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding program: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add Program', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProgramDialog(BuildContext context, Map<String, dynamic> program) {
    final nameController = TextEditingController(text: program['name']);
    final codeController = TextEditingController(text: program['code']);
    String? selectedDegree = program['degree'];

    // Degree type options
    final degreeTypes = ['Foundation', 'Diploma', 'Bachelor Degree'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Edit Program'),
          content: Container(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display faculty info (read-only)
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
                          child: Text(
                            '${program['facultyName']} (${program['facultyCode']})',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Program Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Program Code *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDegree,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Degree Type *',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: degreeTypes.map((degree) => DropdownMenuItem<String>(
                      value: degree,
                      child: Text(degree),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedDegree = value),
                    validator: (value) => value == null ? 'Please select a degree type' : null,
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
                if (nameController.text.isEmpty ||
                    codeController.text.isEmpty ||
                    selectedDegree == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(widget.organizationId)
                      .collection('faculties')
                      .doc(program['facultyId'])
                      .collection('programs')
                      .doc(program['id'])
                      .update({
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim().toUpperCase(),
                    'degree': selectedDegree,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'updatedBy': FirebaseAuth.instance.currentUser?.uid,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Program updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating program: ${e.toString()}'),
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
              child: Text('Update Program', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleProgramStatus(String facultyId, String programId, bool isActive) async {
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
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Program activated successfully' : 'Program deactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating program status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> program) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Delete Program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${program['name']}"?'),
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
                      'This action cannot be undone. Students enrolled in this program will be affected.',
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
              try {
                await FirebaseFirestore.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('faculties')
                    .doc(program['facultyId'])
                    .collection('programs')
                    .doc(program['id'])
                    .delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Program deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting program: ${e.toString()}'),
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