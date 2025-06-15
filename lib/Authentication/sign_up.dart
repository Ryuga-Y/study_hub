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
  String? errorMessage;
  bool _isLoading = false; // Track loading state

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedFaculty;
  String? _selectedProgram;

  // Faculty list with short forms and full names
  final Map<String, String> faculties = {
    'FAFB': 'Faculty of Accountancy, Finance and Business',
    'FOAS': 'Faculty of Applied Sciences',
    'FOCS': 'Faculty of Computing and Information Technology',
    'FOBE': 'Faculty of Built Environment',
    'FOET': 'Faculty of Engineering and Technology',
    'FCCI': 'Faculty of Communication and Creative Industries',
    'FSSH': 'Faculty of Social Science and Humanities',
  };

  // Programs for each faculty (3 programs per faculty)
  final Map<String, List<String>> facultyPrograms = {
    'FAFB': [
      'Bachelor of Accounting',
      'Bachelor of Finance',
      'Bachelor of Business Administration'
    ],
    'FOAS': [
      'Bachelor of Science (Biology)',
      'Bachelor of Science (Chemistry)',
      'Bachelor of Science (Physics)'
    ],
    'FOCS': [
      'Bachelor of Computer Science',
      'Bachelor of Information Technology',
      'Bachelor of Software Engineering'
    ],
    'FOBE': [
      'Bachelor of Architecture',
      'Bachelor of Quantity Surveying',
      'Bachelor of Construction Management'
    ],
    'FOET': [
      'Bachelor of Electrical Engineering',
      'Bachelor of Mechanical Engineering',
      'Bachelor of Civil Engineering'
    ],
    'FCCI': [
      'Bachelor of Communication',
      'Bachelor of Graphic Design',
      'Bachelor of Multimedia'
    ],
    'FSSH': [
      'Bachelor of Psychology',
      'Bachelor of English Language',
      'Bachelor of Public Relations'
    ],
  };

  // Get programs for selected faculty
  List<String> getProgramsForFaculty() {
    if (_selectedFaculty == null) return [];
    return facultyPrograms[_selectedFaculty] ?? [];
  }

  // Sign Up method with loading and snackbar
  Future<void> signUp() async {
    // Start loading
    setState(() {
      _isLoading = true;
      errorMessage = null; // Clear any previous errors
    });

    try {
      // Create a new user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Get the user data
      User? user = userCredential.user;

      if (user != null) {
        // Reference to the users collection in Firestore
        CollectionReference users = _firestore.collection('users');

        // Prepare user data
        Map<String, dynamic> userData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': widget.role,
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'faculty': _selectedFaculty,
          'facultyFullName': faculties[_selectedFaculty], // Store full name too
        };

        // Add program only for students
        if (widget.role == 'student') {
          userData['program'] = _selectedProgram;
        }

        // Add user data to Firestore
        await users.doc(user.uid).set(userData);

        // Stop loading
        setState(() {
          _isLoading = false;
        });

        // Show custom success snackbar
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
                          'Welcome to Study Hub! 🎉',
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
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        // Wait a moment for the user to see the snackbar
        await Future.delayed(Duration(seconds: 2));

        // Navigate to sign-in page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SignInPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Stop loading
      setState(() {
        _isLoading = false;
        errorMessage = e.message ?? 'Error during sign-up';
      });

      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // Handle any other errors
      setState(() {
        _isLoading = false;
        errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
        backgroundColor: Colors.white,
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

                // Error message display (if not shown in snackbar)
                if (errorMessage != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red[700], fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildTextField(_nameController, 'Name', Icons.person),
                SizedBox(height: 15),

                _buildTextField(_emailController, 'Email', Icons.email),
                SizedBox(height: 15),

                _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                // Faculty dropdown for both students and lecturers
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedFaculty,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFaculty = newValue;
                      if (widget.role == 'student') {
                        _selectedProgram = null;
                      }
                    });
                  },
                  selectedItemBuilder: (BuildContext context) {
                    return faculties.entries.map((entry) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          entry.key,
                          style: TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList();
                  },
                  items: faculties.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 100,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    helperText: _selectedFaculty != null
                        ? faculties[_selectedFaculty]
                        : 'Select your faculty',
                    helperMaxLines: 2,
                    helperStyle: TextStyle(fontSize: 12),
                    prefixIcon: Icon(Icons.school, color: Colors.blueAccent),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    value: _selectedProgram,
                    onChanged: _selectedFaculty == null ? null : (newValue) {
                      setState(() {
                        _selectedProgram = newValue;
                      });
                    },
                    items: getProgramsForFaculty().map((program) {
                      return DropdownMenuItem<String>(
                        value: program,
                        child: Text(
                          program,
                          style: TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
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
                      filled: _selectedFaculty == null,
                      fillColor: _selectedFaculty == null ? Colors.grey[100] : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select program';
                      }
                      return null;
                    },
                    hint: Text(
                      _selectedFaculty == null
                          ? 'Select faculty first'
                          : 'Select program',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(height: 30),
                ] else
                  SizedBox(height: 15),

                // Sign Up button with loading state
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
                SizedBox(height: 15),
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