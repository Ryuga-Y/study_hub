import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:study_hub/Authentication/sign_in.dart';

class LecturerSignUpPage extends StatefulWidget {
  @override
  _LecturerSignUpPageState createState() => _LecturerSignUpPageState();
}

class _LecturerSignUpPageState extends State<LecturerSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _programController = TextEditingController();
  final _departmentController = TextEditingController();
  final AuthService _authService = AuthService();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Join Study Hub Today')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Create your account and unlock a world of study.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 16),
              ),
              SizedBox(height: 20),
              if (errorMessage != null)
                Text(errorMessage!, style: TextStyle(color: Colors.red)),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Enter a valid name',
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (val) => val != null && val.contains('@') ? null : 'Enter valid email',
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (val) => val != null && val.length >= 6 ? null : 'Password should be at least 6 characters',
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (val) {
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _programController,
                decoration: InputDecoration(labelText: 'Program'),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Enter your program',
              ),
              TextFormField(
                controller: _departmentController,
                decoration: InputDecoration(labelText: 'Department'),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Enter your department',
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await _authService.signUp(
                          _emailController.text.trim(),
                          _passwordController.text.trim());
                      // Navigate to Sign In page after successful sign up
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => SignInPage()));
                    } catch (e) {
                      setState(() {
                        errorMessage = e.toString();
                      });
                    }
                  }
                },
                child: Text('Sign Up'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SignInPage()),
                  );
                },
                child: Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
