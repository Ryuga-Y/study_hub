import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_services.dart';
import 'email_verification_screen.dart';
import 'onboarding_screen.dart';
import '../admin/admin_dashboard.dart';
import '../Course/lecturer_home.dart';
import '../student_home.dart';

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasData) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _authService.getUserData(snapshot.data!.uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingScreen();
              }

              if (userSnapshot.hasData && userSnapshot.data != null) {
                final userData = userSnapshot.data!;
                final role = userData['role'] ?? '';

                // Check email verification if required
                if (!snapshot.data!.emailVerified) {
                  return EmailVerificationScreen();
                }

                // Navigate based on role
                switch (role) {
                  case 'admin':
                    return AdminDashboard();
                  case 'lecturer':
                    return LecturerHomePage();
                  case 'student':
                    return StudentHomePage();
                  default:
                    return OnboardingScreen();
                }
              }

              return OnboardingScreen();
            },
          );
        }

        return OnboardingScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
            ),
            SizedBox(height: 20),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}