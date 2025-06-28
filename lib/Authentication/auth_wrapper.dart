import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Lecturer/lecturer_home.dart';
import '../Student/student_home.dart';
import 'auth_services.dart';
import 'email_verification_screen.dart';
import 'onboarding_screen.dart';
import '../admin/admin_dashboard.dart';


class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _hasShownDialog = false;

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
                final isActive = userData['isActive'] ?? true;
                final requiresActivation = userData['requiresActivation'] ?? false;

                // Check if user is active
                if (!isActive) {
                  // Special case for pending admin
                  if (role == 'admin' && requiresActivation && !_hasShownDialog) {
                    _hasShownDialog = true;
                    // Use addPostFrameCallback to show dialog after build
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await _handlePendingAdmin(context);
                      if (mounted) {
                        setState(() {
                          _hasShownDialog = false;
                        });
                      }
                    });
                    return _buildPendingScreen();
                  }

                  // Regular inactive user
                  if (!_hasShownDialog) {
                    _hasShownDialog = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await _handleInactiveUser(context);
                      if (mounted) {
                        setState(() {
                          _hasShownDialog = false;
                        });
                      }
                    });
                    return _buildPendingScreen();
                  }
                }

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

  Future<void> _handlePendingAdmin(BuildContext context) async {
    await _authService.signOut();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.hourglass_empty, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Account Pending Activation',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your admin account is pending activation by the organization creator.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please contact your organization creator to activate your account.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInactiveUser(BuildContext context) async {
    await _authService.signOut();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Account Inactive'),
            ],
          ),
          content: Text(
            'Your account has been deactivated. Please contact your administrator for assistance.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'),
            ),
          ],
        ),
      ),
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

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 80,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              'Processing...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}