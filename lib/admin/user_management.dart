import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserManagementPage extends StatefulWidget {
  final String organizationId;

  const UserManagementPage({Key? key, required this.organizationId}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();

  String _searchQuery = '';
  String _selectedRole = 'all';
  String _selectedStatus = 'active';
  String? _selectedFaculty;
  String? _selectedProgram;
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _programs = [];

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
                            'User Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage students and lecturers in your organization',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUserDialog(),
                      icon: Icon(Icons.person_add),
                      label: Text('Add User'),
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
                          hintText: 'Search users...',
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
                    // Role filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'student', child: Text('Students')),
                          DropdownMenuItem(value: 'lecturer', child: Text('Lecturers')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    // Status filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(value: 'all', child: Text('All')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
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
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('organizationId', isEqualTo: widget.organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final role = data['role'] ?? '';

          // Filter by role
          if (_selectedRole != 'all' && role != _selectedRole) {
            return false;
          }

          // Filter by status
          final isActive = data['isActive'] ?? true;
          if (_selectedStatus == 'active' && !isActive) return false;
          if (_selectedStatus == 'inactive' && isActive) return false;

          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            final fullName = (data['fullName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final studentId = (data['studentId'] ?? '').toString().toLowerCase();
            if (!fullName.contains(_searchQuery) &&
                !email.contains(_searchQuery) &&
                !studentId.contains(_searchQuery)) {
              return false;
            }
          }

          return true;
        }).toList();

        if (users.isEmpty) {
          return _buildEmptyState();
        }

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
                      Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

                // Table content
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) => _buildUserRow(users[index]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserRow(DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final isActive = data['isActive'] ?? true;
    final role = data['role'] ?? '';
    final facultyId = data['facultyId'] ?? '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: role == 'student' ? Colors.blue : Colors.green,
                  child: Text(
                    data['fullName']?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['fullName'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Email
          Expanded(
            flex: 2,
            child: Text(
              data['email'] ?? '',
              style: TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Role
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'student' ? Colors.blue[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                role == 'student' ? 'Student' : 'Lecturer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: role == 'student' ? Colors.blue[700] : Colors.green[700],
                ),
              ),
            ),
          ),

          // Student ID
          Expanded(
            child: Text(
              data['studentId'] ?? '-',
              style: TextStyle(fontSize: 14),
            ),
          ),

          // Faculty
          Expanded(
            child: FutureBuilder<String>(
              future: _getFacultyName(facultyId),
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
              onChanged: (value) => _toggleUserStatus(userDoc.id, value),
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
                  onPressed: () => _showEditUserDialog(userDoc.id, data),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deleteUser(userDoc.id, data['fullName']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getFacultyName(String facultyId) async {
    if (facultyId.isEmpty) return '-';

    final doc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('faculties')
        .doc(facultyId)
        .get();

    if (doc.exists) {
      return doc['code'] ?? '-';
    }
    return '-';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No users found',
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
                : 'Add your first user to get started',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          if (_searchQuery.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(),
                icon: Icon(Icons.person_add),
                label: Text('Add User'),
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

  void _showAddUserDialog({String? userId, Map<String, dynamic>? existingData}) {
    String selectedRole = 'student';

    if (existingData != null) {
      _emailController.text = existingData['email'] ?? '';
      _fullNameController.text = existingData['fullName'] ?? '';
      _studentIdController.text = existingData['studentId'] ?? '';
      selectedRole = existingData['role'] ?? 'student';
      _selectedFaculty = existingData['facultyId'];
      _selectedProgram = existingData['programId'];
      if (_selectedFaculty != null && _selectedFaculty!.isNotEmpty) {
        _loadPrograms(_selectedFaculty!);
      }
    } else {
      _emailController.clear();
      _fullNameController.clear();
      _passwordController.clear();
      _studentIdController.clear();
      _selectedFaculty = null;
      _selectedProgram = null;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(userId == null ? 'Add New User' : 'Edit User'),
          content: Container(
            width: 500,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role selection
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'lecturer', child: Text('Lecturer')),
                      ],
                      onChanged: userId == null ? (value) {
                        setDialogState(() {
                          selectedRole = value!;
                        });
                      } : null,
                    ),
                    SizedBox(height: 16),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter full name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      enabled: userId == null,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Password (only for new users)
                    if (userId == null)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter password',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    if (userId == null) SizedBox(height: 16),

                    // Student ID (only for students)
                    if (selectedRole == 'student')
                      TextFormField(
                        controller: _studentIdController,
                        decoration: InputDecoration(
                          labelText: 'Student ID',
                          hintText: 'Enter student ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (selectedRole == 'student' && (value == null || value.trim().isEmpty)) {
                            return 'Please enter student ID';
                          }
                          return null;
                        },
                      ),
                    if (selectedRole == 'student') SizedBox(height: 16),

                    // Faculty
                    DropdownButtonFormField<String>(
                      value: _selectedFaculty,
                      decoration: InputDecoration(
                        labelText: 'Faculty',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Select Faculty')),
                        ..._faculties.map((faculty) => DropdownMenuItem<String>(
                          value: faculty['id'].toString(),
                          child: Text('${faculty['code']} - ${faculty['name']}'),
                        )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedFaculty = value;
                          _selectedProgram = null;
                          if (value != null) {
                            _loadPrograms(value);
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a faculty';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Program (only for students)
                    if (selectedRole == 'student' && _selectedFaculty != null)
                      DropdownButtonFormField<String>(
                        value: _selectedProgram,
                        decoration: InputDecoration(
                          labelText: 'Program',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Select Program')),
                          ..._programs.map((program) => DropdownMenuItem<String>(
                            value: program['id'].toString(),
                            child: Text('${program['code']} - ${program['name']}'),
                          )),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedProgram = value;
                          });
                        },
                        validator: (value) {
                          if (selectedRole == 'student' && (value == null || value.isEmpty)) {
                            return 'Please select a program';
                          }
                          return null;
                        },
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
              onPressed: () => _saveUser(userId, selectedRole),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: Text(userId == null ? 'Add User' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> data) {
    _showAddUserDialog(userId: userId, existingData: data);
  }

  Future<void> _saveUser(String? userId, String role) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userData = {
        'fullName': _fullNameController.text.trim(),
        'role': role,
        'facultyId': _selectedFaculty ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (role == 'student') {
        userData['studentId'] = _studentIdController.text.trim();
        userData['programId'] = _selectedProgram ?? '';
      }

      if (userId == null) {
        // Creating new user
        userData['email'] = _emailController.text.trim();
        userData['organizationId'] = widget.organizationId;
        userData['createdAt'] = FieldValue.serverTimestamp();
        userData['isActive'] = true;

        // Create auth user
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Save user data to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Updating existing user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update(userData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User status updated'),
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

  void _deleteUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this user?'),
            SizedBox(height: 8),
            Text(
              userName,
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
                      'This action cannot be undone',
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
                    .collection('users')
                    .doc(userId)
                    .delete();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user'),
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
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }
}