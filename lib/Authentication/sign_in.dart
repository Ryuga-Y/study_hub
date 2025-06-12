import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Authentication/role_selection.dart';
import 'package:study_hub/lecturer_home.dart';
import 'package:study_hub/student_home.dart'; // Replace with actual student home page
//import 'package:study_hub/lecturer_home.dart';  // Replace with actual lecturer home page
//import 'package:study_hub/admin_home.dart'; // Replace with actual admin home page

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? errorMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in method
  Future<void> _signIn() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Basic validation to ensure email and password are not empty
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(context, 'Email and Password cannot be empty');
      return;
    }

    try {
      // Attempt to sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Fetch the user role from Firestore
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          String role = userDoc.data()?['role'] ?? '';

          // Navigate to different home pages based on the user's role
          if (role == 'student') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => StudentHomePage()),
            );
          } else if (role == 'lecturer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LecturerHomePage()),
            );
          } else if (role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => StudentHomePage()),
            );
          } else {
            setState(() {
              errorMessage = 'Role not found for this user.';
            });
          }
        } else {
          setState(() {
            errorMessage = 'User data not found in the database.';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      // Log the error code and message for debugging
      print('Error code: ${e.code}');
      print('Error message: ${e.message}');

      // Check if the context is still valid before showing the dialog
      if (!mounted) return;

      // Handle specific Firebase error codes
      if (e.code == 'invalid-credential') {
        _showErrorDialog(context, 'Invalid credentials. Please check your email and password.');
      } else if (e.code == 'wrong-password') {
        _showErrorDialog(context, 'Incorrect password.');
      } else if (e.code == 'user-not-found') {
        _showErrorDialog(context, 'Email not found.');
      } else if (e.code == 'too-many-requests') {
        _showErrorDialog(context, 'Too many attempts, please try later.');
      } else if (e.code == 'invalid-email') {
        _showErrorDialog(context, 'Invalid email format.');
      } else {
        _showErrorDialog(context, 'An unknown error occurred: ${e.message}');
      }
    }
  }

  // Email validation with RegEx
  bool isValidEmail(String email) {
    final emailRegEx = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegEx.hasMatch(email);
  }


  // Show error dialog if context is still valid
  void _showErrorDialog(BuildContext context, String message) {
    // Check if the widget is still part of the widget tree before showing the dialog
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Sign In'),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous page
          },
        ),
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Abeezee',
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 8),
                    Image.asset(
                      'assets/images/waving.png',
                      height: 35,
                      width: 35,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Sign in to Study Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Abeezee',
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 30),
                // Error message display
                if (errorMessage != null)
                  Text(errorMessage!, style: TextStyle(color: Colors.red)),
                _buildTextField(_emailController, 'Email', Icons.email),
                SizedBox(height: 15),
                _buildTextField(
                  _passwordController,
                  'Password',
                  Icons.lock,
                  obscureText: true,
                ),
                SizedBox(height: 30),
                // Sign In button
                ElevatedButton(
                  onPressed: () async {
                    String email = _emailController.text.trim();
                    String password = _passwordController.text.trim();

                    // Validate the email format
                    if (!isValidEmail(email)) {
                      _showErrorDialog(context, 'Please enter a valid email address.');
                      return;
                    }

                    // Check if email and password are not empty
                    if (email.isEmpty || password.isEmpty) {
                      _showErrorDialog(context, 'Email and Password cannot be empty.');
                      return;
                    }

                    // Proceed with sign-in if all validations are passed
                    if (_formKey.currentState!.validate()) {
                      await _signIn();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[400],
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                    'Sign In',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                )
                ,
                SizedBox(height: 15),
                // Sign Up button
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoleSelectionPage(),
                      ), // Navigate to role selection page
                    );
                  },
                  child: Text(
                    'Don\'t have an account? Sign Up',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontFamily: "Abeezee",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
  }) {
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
        return null;
      },
    );
  }
}
