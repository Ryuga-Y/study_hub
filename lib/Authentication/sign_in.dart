import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_hub/Authentication/role_selection.dart';
import 'package:study_hub/Course/lecturer_home.dart';
import 'package:study_hub/student_home.dart';
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
  bool _isLoading = false;
  bool _obscurePassword = true; // For password visibility toggle

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in method with loading and snackbar
  Future<void> _signIn() async {
    // Start loading
    setState(() {
      _isLoading = true;
      errorMessage = null; // Clear any previous errors
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

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
          String userName = userDoc.data()?['name'] ?? 'User';

          // Stop loading
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
                            'Welcome back, $userName! 👋',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Successfully signed in as ${role}',
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
              duration: Duration(seconds: 2),
            ),
          );

          // Small delay to show snackbar
          await Future.delayed(Duration(milliseconds: 1500));

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
              _isLoading = false;
              errorMessage = 'Role not found for this user.';
            });
            _showErrorSnackbar('Role not found for this user.');
          }
        } else {
          setState(() {
            _isLoading = false;
            errorMessage = 'User data not found in the database.';
          });
          _showErrorSnackbar('User data not found in the database.');
        }
      }
    } on FirebaseAuthException catch (e) {
      // Stop loading
      setState(() {
        _isLoading = false;
      });

      // Handle specific Firebase error codes
      String errorMsg = '';
      if (e.code == 'invalid-credential') {
        errorMsg = 'Invalid credentials. Please check your email and password.';
      } else if (e.code == 'wrong-password') {
        errorMsg = 'Incorrect password.';
      } else if (e.code == 'user-not-found') {
        errorMsg = 'No account found with this email.';
      } else if (e.code == 'too-many-requests') {
        errorMsg = 'Too many failed attempts. Please try again later.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'Invalid email format.';
      } else if (e.code == 'user-disabled') {
        errorMsg = 'This account has been disabled.';
      } else {
        errorMsg = 'Sign in failed. Please try again.';
      }

      setState(() {
        errorMessage = errorMsg;
      });
      _showErrorSnackbar(errorMsg);
    } catch (e) {
      // Handle any other errors
      setState(() {
        _isLoading = false;
        errorMessage = 'An unexpected error occurred.';
      });
      _showErrorSnackbar('An unexpected error occurred. Please try again.');
    }
  }

  // Show error snackbar
  void _showErrorSnackbar(String message) {
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
                message,
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
  }

  // Email validation with RegEx
  bool isValidEmail(String email) {
    final emailRegEx = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegEx.hasMatch(email);
  }

  // Forgot password functionality
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your email address to receive a password reset link.'),
              SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String email = resetEmailController.text.trim();
                if (email.isEmpty || !isValidEmail(email)) {
                  _showErrorSnackbar('Please enter a valid email address.');
                  return;
                }

                try {
                  await _auth.sendPasswordResetEmail(email: email);
                  Navigator.of(context).pop();

                  // Show success snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.email, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Password reset link sent to $email',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.blue[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.all(20),
                      duration: Duration(seconds: 4),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  Navigator.of(context).pop();
                  String errorMsg = 'Failed to send reset email.';
                  if (e.code == 'user-not-found') {
                    errorMsg = 'No account found with this email.';
                  }
                  _showErrorSnackbar(errorMsg);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[400],
              ),
              child: Text('Send Reset Link', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RoleSelectionPage()),
            );
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

                // Error message display (optional, since we're using snackbars)
                if (errorMessage != null && !_isLoading)
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

                _buildTextField(_emailController, 'Email', Icons.email),
                SizedBox(height: 15),

                // Password field with visibility toggle
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    labelText: 'Password',
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
                  obscureText: _obscurePassword,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter Password';
                    }
                    if (val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 10),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.purple[400],
                        fontSize: 14,
                        fontFamily: "Abeezee",
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Sign In button with loading state
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    if (_formKey.currentState!.validate()) {
                      await _signIn();
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
                        'Signing In...',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ],
                  )
                      : Text(
                    'Sign In',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),

                SizedBox(height: 15),

                // Sign Up link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleSelectionPage(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: "Abeezee",
                        ),
                        children: [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: Colors.purple[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
        return null;
      },
    );
  }
}