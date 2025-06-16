import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyManagementPage extends StatefulWidget {
  final String organizationId;

  const FacultyManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _FacultyManagementPageState createState() => _FacultyManagementPageState();
}

class _FacultyManagementPageState extends State<FacultyManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _searchQuery = '';
  bool _showActiveOnly = true;

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
                            'Faculty Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage academic faculties and departments',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddFacultyDialog(),
                      icon: Icon(Icons.add),
                      label: Text('Add Faculty'),
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
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search faculties...',
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
                    // Filter toggle
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Text('Show active only'),
                          SizedBox(width: 8),
                          Switch(
                            value: _showActiveOnly,
                            onChanged: (value) {
                              setState(() {
                                _showActiveOnly = value;
                              });
                            },
                            activeColor: Colors.redAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('faculties')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var faculties = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (doc.id == '_placeholder') return false;

                  // Filter by active status
                  if (_showActiveOnly && !(data['isActive'] ?? true)) {
                    return false;
                  }

                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final code = (data['code'] ?? '').toString().toLowerCase();
                    if (!name.contains(_searchQuery) && !code.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (faculties.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildFacultyGrid(faculties);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No faculties found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search criteria'
                : 'Add your first faculty to get started',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () => _showAddFacultyDialog(),
                icon: Icon(Icons.add),
                label: Text('Add Faculty'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFacultyGrid(List<QueryDocumentSnapshot> faculties) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: faculties.length,
        itemBuilder: (context, index) {
          final faculty = faculties[index];
          final data = faculty.data() as Map<String, dynamic>;

          return _buildFacultyCard(faculty.id, data);
        },
      ),
    );
  }

  Widget _buildFacultyCard(String facultyId, Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isActive ? Colors.redAccent : Colors.grey[400],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['code'] ?? 'N/A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 40,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Unnamed Faculty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data['description'] != null && data['description'].toString().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            data['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),

                  // Statistics
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('organizations')
                        .doc(widget.organizationId)
                        .collection('faculties')
                        .doc(facultyId)
                        .collection('programs')
                        .where('isActive', isEqualTo: true)
                        .get(),
                    builder: (context, snapshot) {
                      final programCount = snapshot.data?.docs.length ?? 0;

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.book, size: 16, color: Colors.grey[700]),
                            SizedBox(width: 4),
                            Text(
                              '$programCount Programs',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _viewPrograms(facultyId, data['name']),
                        child: Text('View Programs'),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditFacultyDialog(facultyId, data),
                      ),
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => _toggleFacultyStatus(facultyId, !isActive),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFacultyDialog({String? facultyId, Map<String, dynamic>? existingData}) {
    if (existingData != null) {
      _nameController.text = existingData['name'] ?? '';
      _codeController.text = existingData['code'] ?? '';
      _descriptionController.text = existingData['description'] ?? '';
    } else {
      _nameController.clear();
      _codeController.clear();
      _descriptionController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(facultyId == null ? 'Add New Faculty' : 'Edit Faculty'),
        content: Container(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Faculty Name',
                    hintText: 'e.g., Faculty of Engineering and Technology',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter faculty name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Faculty Code',
                    hintText: 'e.g., FOET',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter faculty code';
                    }
                    if (value.trim().length > 10) {
                      return 'Code should be less than 10 characters';
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
                    hintText: 'Brief description of the faculty',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _saveFaculty(facultyId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: Text(facultyId == null ? 'Add Faculty' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showEditFacultyDialog(String facultyId, Map<String, dynamic> data) {
    _showAddFacultyDialog(facultyId: facultyId, existingData: data);
  }

  Future<void> _saveFaculty(String? facultyId) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final facultyData = {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().toUpperCase(),
        'description': _descriptionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (facultyId == null) {
        // Adding new faculty
        facultyData['createdAt'] = FieldValue.serverTimestamp();
        facultyData['isActive'] = true;

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .add(facultyData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Faculty added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Updating existing faculty
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('faculties')
            .doc(facultyId)
            .update(facultyData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Faculty updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving faculty: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFacultyStatus(String facultyId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('faculties')
          .doc(facultyId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faculty status updated'),
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

  void _viewPrograms(String facultyId, String facultyName) {
    // Navigate to programs page with faculty filter
    // This would typically navigate to a programs management page
    // filtered by this specific faculty
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing programs for $facultyName'),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}