import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../Authentication/validators.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  // Controllers for editable fields
  final _nameController = TextEditingController();

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'User not authenticated');
        return;
      }

      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        setState(() {
          _userData = userData;
          _nameController.text = userData['fullName'] ?? '';
        });
        _animationController.forward();
      } else {
        setState(() => _errorMessage = 'User data not found');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_userData == null) return;

    setState(() => _isUpdating = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Create audit log
      await _authService.createAuditLog(
        organizationCode: _userData!['organizationCode'],
        action: 'profile_updated',
        userId: user.uid,
        details: {
          'updatedFields': ['fullName'],
          'fullName': _nameController.text.trim(),
        },
      );

      // Reload user data
      await _loadUserData();

      SuccessSnackbar.show(
        context,
        'Profile Updated! ✅',
        subtitle: 'Your changes have been saved successfully',
      );
    } catch (e) {
      ErrorSnackbar.show(context, 'Error updating profile: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_userData == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: Colors.orange),
            SizedBox(width: 12),
            Text('Reset Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A password reset link will be sent to your email address:',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _userData!['email'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Continue with password reset?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Send Reset Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      final result = await _authService.resetPassword(_userData!['email']);

      setState(() => _isLoading = false);

      if (result.success) {
        SuccessSnackbar.show(
          context,
          'Password Reset Link Sent! 📧',
          subtitle: 'Check your email inbox and spam folder',
        );
      } else {
        ErrorSnackbar.show(context, result.message);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.mark_email_unread, color: Colors.orange),
            SizedBox(width: 12),
            Text('Email Verification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your email address is not verified.'),
            SizedBox(height: 12),
            Text(
              'Please check your email inbox and click the verification link to verify your account.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && !user.emailVerified) {
                  await user.sendEmailVerification();
                  Navigator.pop(context);
                  SuccessSnackbar.show(
                    context,
                    'Verification Email Sent! 📧',
                    subtitle: 'Check your inbox for the verification link',
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ErrorSnackbar.show(context, 'Error sending verification email: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Resend Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getJoinDate() {
    if (_userData?['createdAt'] != null) {
      final date = (_userData!['createdAt'] as Timestamp).toDate();
      final months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month]} ${date.year}';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('Profile'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text('Profile'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Error', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
              SizedBox(height: 24),
              CustomButton(
                text: 'Retry',
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadUserData();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.purple[100],
                          child: _userData?['avatarUrl'] != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              _userData!['avatarUrl'],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildAvatarText(),
                            ),
                          )
                              : _buildAvatarText(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple[400],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _userData?['role'] == 'student' ? Icons.school : Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Name
                    Text(
                      _userData?['fullName'] ?? 'Unknown User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Role Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _userData?['role'] == 'student' ? Colors.blue[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (_userData?['role'] ?? 'user').toUpperCase(),
                        style: TextStyle(
                          color: _userData?['role'] == 'student' ? Colors.blue[800] : Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Email with verification status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined, color: Colors.grey[600], size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _userData?['email'] ?? '',
                            style: TextStyle(color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: _userData?['emailVerified'] != true ? _showEmailVerificationDialog : null,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _userData?['emailVerified'] == true ? Colors.green[100] : Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _userData?['emailVerified'] == true ? Icons.verified : Icons.warning_outlined,
                                  size: 14,
                                  color: _userData?['emailVerified'] == true ? Colors.green[700] : Colors.orange[700],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _userData?['emailVerified'] == true ? 'Verified' : 'Not Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _userData?['emailVerified'] == true ? Colors.green[700] : Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Edit Profile Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),

                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      validator: (value) => Validators.required(value, 'full name'),
                    ),
                    SizedBox(height: 20),

                    CustomButton(
                      text: _isUpdating ? 'Updating...' : 'Update Profile',
                      onPressed: _updateProfile,
                      isLoading: _isUpdating,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Account Information
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),

                    _buildInfoRow(
                      icon: Icons.business_outlined,
                      label: 'Organization',
                      value: _userData?['organizationName'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.code,
                      label: 'Organization Code',
                      value: _userData?['organizationCode'] ?? 'Unknown',
                    ),
                    _buildInfoRow(
                      icon: Icons.school_outlined,
                      label: 'Faculty',
                      value: _userData?['facultyName'] ?? 'Not specified',
                    ),
                    if (_userData?['role'] == 'student' && _userData?['programName'] != null)
                      _buildInfoRow(
                        icon: Icons.book_outlined,
                        label: 'Program',
                        value: _userData!['programName'],
                      ),
                    _buildInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Member Since',
                      value: _getJoinDate(),
                    ),
                    _buildInfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Account Status',
                      value: _userData?['isActive'] == true ? 'Active' : 'Inactive',
                      valueColor: _userData?['isActive'] == true ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Account Actions
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Action Buttons
                    CustomButton(
                      text: 'Reset Password',
                      onPressed: _resetPassword,
                      backgroundColor: Colors.blue,
                      icon: Icons.lock_reset,
                    ),

                    SizedBox(height: 16),

                    CustomButton(
                      text: 'Logout',
                      onPressed: _handleLogout,
                      backgroundColor: Colors.red,
                      icon: Icons.logout,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarText() {
    return Text(
      (_userData?['fullName'] ?? 'U').substring(0, 1).toUpperCase(),
      style: TextStyle(
        color: Colors.purple[600],
        fontSize: 40,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}