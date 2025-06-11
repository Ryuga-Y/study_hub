import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:study_hub/Authentication/sign_in.dart';

class StudentSignUpPage extends StatefulWidget {
  const StudentSignUpPage({super.key});

  @override
  StudentSignUpPageState createState() => StudentSignUpPageState();
}

class StudentSignUpPageState extends State<StudentSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _programController = TextEditingController();
  final AuthService _authService = AuthService();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(''),
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
                  'Create your account and unlock a world of study.',
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

                _buildTextField(_programController, 'Program', Icons.school),
                SizedBox(height: 30),

                // Sign Up button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        // Call sign up and pass all the required fields
                        await _authService.signUp(
                          _emailController.text.trim(),
                          _passwordController.text.trim(),
                          _nameController.text.trim(),
                          _programController.text.trim(), // This is the "program" field for students
                          'student', // Role as student
                        );

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => SignInPage()),
                        );
                      } catch (e) {
                        setState(() {
                          errorMessage = e.toString();
                        });
                      }
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

                // Sign In button
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => SignInPage()),
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft, // Aligns the text to the left
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        color: Colors.blue,
                        fontFamily: 'Abeezee',
                        fontSize: 18, // Font size set to 18
                      ),
                    ),
                  ),
                )
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
