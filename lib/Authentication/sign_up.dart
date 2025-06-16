import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Authentication/sign_in.dart';

class SignUpPage extends StatefulWidget {
  final String role; // The role passed from RoleSelectionPage (student or lecturer)

  const SignUpPage({super.key, required this.role});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationCodeController = TextEditingController();

  String? errorMessage;
  bool _isLoading = false;
  bool _isCheckingOrgCode = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _organizationId;
  String? _organizationName;
  String? _selectedFacultyId;
  String? _selectedProgramId;

  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _programs = [];

  // Check if organization code exists and get organization details
  Future<void> _checkOrganizationCode() async {
    if (_organizationCodeController.text.trim().isEmpty) {
      setState(() {
        _organizationId = null;
        _organizationName = null;
        _faculties = [];
        _programs = [];
        _selectedFacultyId = null;
        _selectedProgramId = null;
      });
      return;
    }

    setState(() {
      _isCheckingOrgCode = true;
    });

    try {
      String orgCode = _organizationCodeController.text.trim().toUpperCase();

      // Query organizations by code
      QuerySnapshot orgSnapshot = await _firestore
          .collection('organizations')
          .where('code', isEqualTo: orgCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (orgSnapshot.docs.isNotEmpty) {
        DocumentSnapshot orgDoc = orgSnapshot.docs.first;

        setState(() {
          _organizationId = orgDoc.id;
          _organizationName = orgDoc['name'];
          errorMessage = null;
        });

        // Load faculties for this organization
        await _loadFaculties();
      } else {
        setState(() {
          _organizationId = null;
          _organizationName = null;
          _faculties = [];
          _programs = [];
          _selectedFacultyId = null;
          _selectedProgramId = null;
          errorMessage = 'Invalid organization code';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error checking organization code';
      });
    } finally {
      setState(() {
        _isCheckingOrgCode = false;
      });
    }
  }

  // Load faculties for the organization
  Future<void> _loadFaculties() async {
    if (_organizationId == null) return;

    try {
      QuerySnapshot facultySnapshot = await _firestore
          .collection('organizations')
          .doc(_organizationId)
          .collection('faculties')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      setState(() {
        _faculties = facultySnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'code': doc['code'],
        }).toList();
      });
    } catch (e) {
      print('Error loading faculties: $e');
    }
  }

  // Load programs for selected faculty
  Future<void> _loadPrograms(String facultyId) async {
    if (_organizationId == null || facultyId.isEmpty) return;

    try {
      QuerySnapshot programSnapshot = await _firestore
          .collection('organizations')
          .doc(_organizationId)
          .collection('faculties')
          .doc(facultyId)
          .collection('programs')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      setState(() {
        _programs = programSnapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'code': doc['code'],
        }).toList();
      });
    } catch (e) {
      print('Error loading programs: $e');
    }
  }

  // Sign Up method
  Future<void> signUp() async {
    if (_organizationId == null) {
      setState(() {
        errorMessage = 'Please enter a valid organization code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = null;
    });

    try {
      // Create a new user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // Update display name
        await user.updateDisplayName(_nameController.text.trim());

        // Get selected faculty details
        Map<String, dynamic>? selectedFaculty = _faculties.firstWhere(
              (f) => f['id'] == _selectedFacultyId,
          orElse: () => {},
        );

        // Prepare user data
        Map<String, dynamic> userData = {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': widget.role,
          'organizationId': _organizationId,
          'organizationName': _organizationName,
          'facultyId': _selectedFacultyId,
          'facultyName': selectedFaculty['name'] ?? '',
          'facultyCode': selectedFaculty['code'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        };

        // Add program details for students
        if (widget.role == 'student' && _selectedProgramId != null) {
          Map<String, dynamic>? selectedProgram = _programs.firstWhere(
                (p) => p['id'] == _selectedProgramId,
            orElse: () => {},
          );

          userData['programId'] = _selectedProgramId;
          userData['programName'] = selectedProgram['name'] ?? '';
          userData['programCode'] = selectedProgram['code'] ?? '';
        }

        // Add user data to Firestore
        await _firestore.collection('users').doc(user.uid).set(userData);

        // Create audit log entry
        await _firestore
            .collection('organizations')
            .doc(_organizationId)
            .collection('audit_logs')
            .add({
          'action': '${widget.role}_account_created',
          'performedBy': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'userEmail': _emailController.text.trim(),
            'userName': _nameController.text.trim(),
            'role': widget.role,
            'faculty': selectedFaculty['name'] ?? '',
          }
        });

        setState(() {
          _isLoading = false;
        });

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome to $_organizationName! 🎉',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your ${widget.role} account has been created successfully.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(20),
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(Duration(seconds: 2));

        // Navigate to sign-in page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SignInPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        errorMessage = e.message ?? 'Error during sign-up';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage!),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.role == 'student' ? 'Student Sign Up' : 'Lecturer Sign Up'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Join Study Hub Today',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Abeezee',
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Image.asset(
                      'assets/images/sparkle.png',
                      height: 35,
                      width: 35,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  widget.role == 'student'
                      ? 'Create your Student account and unlock a world of study.'
                      : 'Create your Lecturer account and unlock a world of study',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontFamily: 'Abeezee'),
                ),
                SizedBox(height: 30),

                // Organization Code Field
                TextFormField(
                  controller: _organizationCodeController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.business, color: Colors.blueAccent),
                    suffixIcon: _isCheckingOrgCode
                        ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : IconButton(
                      icon: Icon(Icons.check_circle,
                          color: _organizationId != null ? Colors.green : Colors.grey),
                      onPressed: _checkOrganizationCode,
                    ),
                    labelText: 'Organization Code',
                    helperText: _organizationName ?? 'Enter your organization code',
                    helperStyle: TextStyle(
                      color: _organizationId != null ? Colors.green : null,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _checkOrganizationCode();
                    }
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter organization code';
                    }
                    if (_organizationId == null) {
                      return 'Invalid organization code';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),

                _buildTextField(_nameController, 'Full Name', Icons.person),
                SizedBox(height: 15),

                _buildTextField(_emailController, 'Email', Icons.email),
                SizedBox(height: 15),

                _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                // Faculty dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedFacultyId,
                  onChanged: _organizationId == null
                      ? null
                      : (newValue) {
                    setState(() {
                      _selectedFacultyId = newValue;
                      _selectedProgramId = null;
                      _programs = [];
                    });
                    if (newValue != null && widget.role == 'student') {
                      _loadPrograms(newValue);
                    }
                  },
                  items: _faculties.map((faculty) {
                    return DropdownMenuItem<String>(
                      value: faculty['id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            faculty['code'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            faculty['name'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    prefixIcon: Icon(Icons.school, color: Colors.blueAccent),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: _organizationId == null,
                    fillColor: _organizationId == null ? Colors.grey[100] : null,
                  ),
                  hint: Text(
                    _organizationId == null
                        ? 'Enter organization code first'
                        : 'Select faculty',
                    style: TextStyle(fontSize: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select faculty';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 15),

                // Program dropdown - only for students
                if (widget.role == 'student') ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedProgramId,
                    onChanged: _selectedFacultyId == null
                        ? null
                        : (newValue) {
                      setState(() {
                        _selectedProgramId = newValue;
                      });
                    },
                    items: _programs.map((program) {
                      return DropdownMenuItem<String>(
                        value: program['id'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              program['code'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              program['name'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Program',
                      prefixIcon: Icon(Icons.book, color: Colors.blueAccent),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: _selectedFacultyId == null,
                      fillColor: _selectedFacultyId == null ? Colors.grey[100] : null,
                    ),
                    hint: Text(
                      _selectedFacultyId == null
                          ? 'Select faculty first'
                          : 'Select program',
                      style: TextStyle(fontSize: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select program';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 30),
                ] else
                  SizedBox(height: 15),

                // Sign Up button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    if (_formKey.currentState!.validate()) {
                      await signUp();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[400],
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                    disabledBackgroundColor: Colors.purple[200],
                  ),
                  child: _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Creating Account...',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  )
                      : Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => SignInPage()),
                        );
                      },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.purple[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      obscureText: obscureText,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Please enter $label';
        }
        if (label == 'Email' && !val.contains('@')) {
          return 'Enter a valid email';
        }
        if (label == 'Password' && val.length < 6) {
          return 'Password must be at least 6 characters';
        }
        if (label == 'Confirm Password' && val != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}