import 'package:flutter/material.dart';
import 'package:study_hub/Authentication/sign_up.dart';
import 'auth_service.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (errorMessage != null)
                Text(errorMessage!, style: TextStyle(color: Colors.red)),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (val) =>
                val != null && val.contains('@') ? null : 'Enter valid email',
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (val) =>
                val != null && val.length >= 6 ? null : 'Min 6 chars',
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await _authService.signIn(
                          _emailController.text.trim(),
                          _passwordController.text.trim());
                      // Navigate to your app’s home screen after successful sign in
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => HomePage())); // Create a HomePage widget
                    } catch (e) {
                      setState(() {
                        errorMessage = e.toString();
                      });
                    }
                  }
                },
                child: Text('Sign In'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => SignUpPage(role: '',)),
                  );
                },
                child: Text('Don’t have an account? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dummy HomePage to show after sign in
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(child: Text('Welcome! You are signed in.')),
    );
  }
}
