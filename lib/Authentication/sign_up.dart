import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Authentication/sign_in.dart'; // Assuming you have this page

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
  //final _programOrDepartmentController = TextEditingController();
  String? errorMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedProgramOrDepartment;

  // Define lists of programs for students and departments for lecturers
  final List<String> studentPrograms = ['Computer Science', 'Electrical Engineering', 'Mechanical Engineering'];
  final List<String> lecturerDepartments = ['Mathematics', 'Physics', 'Computer Science'];

  // Sign Up method
  Future<void> signUp() async {
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

        // Add user data to Firestore
        await users.doc(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': widget.role, // Store role as either 'student' or 'lecturer'
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(), // Timestamp of when the account was created
          widget.role == 'student' ? 'program' : 'department': _selectedProgramOrDepartment,
        });

        // Navigate to sign-in page after successful signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SignInPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'Error during sign-up';
      });
    }
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
                  widget.role == 'student' ? 'Create your Student account and unlock a world of study.' : 'Create your Lecturer account and unlock a world of study',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontFamily: 'Abeezee'),
                ),
                SizedBox(height: 30),

                // Error message display
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),

                _buildTextField(_nameController, 'Name', Icons.person),
                SizedBox(height: 15),

                _buildTextField(_emailController, 'Email', Icons.email),
                SizedBox(height: 15),

                _buildTextField(_passwordController, 'Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock, obscureText: true),
                SizedBox(height: 15),

                // Dropdown for program or department based on the role
                DropdownButtonFormField<String>(
                  value: _selectedProgramOrDepartment,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedProgramOrDepartment = newValue;
                    });
                  },
                  items: widget.role == 'student'
                      ? studentPrograms.map((program) {
                    return DropdownMenuItem<String>(
                      value: program,
                      child: Text(program),
                    );
                  }).toList()
                      : lecturerDepartments.map((department) {
                    return DropdownMenuItem<String>(
                      value: department,
                      child: Text(department),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: widget.role == 'student' ? 'Program' : 'Department',
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
                      return 'Please select ${widget.role == 'student' ? 'program' : 'department'}';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 30),

                // Sign Up button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await signUp();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[400],
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
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
