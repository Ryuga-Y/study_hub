import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';
import '../Authentication/auth_services.dart';
import '../Authentication/custom_widgets.dart';
import '../Authentication/validators.dart';
import '../community/community_services.dart';
import '../community/models.dart';
// Import your ProfileChangeNotifier here
// import 'path/to/profile_change_notifier.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final CommunityService _communityService = CommunityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  // Controllers for editable fields
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

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
    _bioController.dispose();
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
          _bioController.text = userData['bio'] ?? '';
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

  // Enhanced profile update with community service integration
  Future<void> _updateProfile({
    String? fullName,
    String? bio,
    File? avatarFile,
    bool removeAvatar = false,
  }) async {
    if (_userData == null) return;

    setState(() => _isUpdating = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Use community service for comprehensive profile update
      await _communityService.updateUserProfile(
        fullName: fullName?.trim(),
        bio: bio?.trim(),
        avatarFile: avatarFile,
        removeAvatar: removeAvatar,
      );

      // Update Firebase Auth display name if name changed
      if (fullName != null && fullName.trim().isNotEmpty) {
        await user.updateDisplayName(fullName.trim());
      }

      // Create audit log
      List<String> updatedFields = [];
      Map<String, dynamic> details = {};

      if (fullName != null) {
        updatedFields.add('fullName');
        details['fullName'] = fullName.trim();
      }
      if (bio != null) {
        updatedFields.add('bio');
        details['bio'] = bio.trim();
      }
      if (avatarFile != null) {
        updatedFields.add('avatar');
        details['avatarUpdated'] = true;
      }
      if (removeAvatar) {
        updatedFields.add('avatar');
        details['avatarRemoved'] = true;
      }

      if (updatedFields.isNotEmpty) {
        await _authService.createAuditLog(
          organizationCode: _userData!['organizationCode'],
          action: 'profile_updated',
          userId: user.uid,
          details: {
            'updatedFields': updatedFields,
            ...details,
          },
        );
      }

      // Reload user data to reflect changes
      await _loadUserData();

      // Notify other parts of the app about profile changes
      // ProfileChangeNotifier().notifyProfileUpdate({
      //   'fullName': _userData?['fullName'],
      //   'bio': _userData?['bio'],
      //   'avatarUrl': _userData?['avatarUrl'],
      // });

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

  // Enhanced edit profile dialog with name and bio
  void _showEditProfileDialog() {
    // Reset controllers with current data
    _nameController.text = _userData?['fullName'] ?? '';
    _bioController.text = _userData?['bio'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.purple[600]),
            SizedBox(width: 12),
            Text('Edit Profile'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (value) => Validators.required(value, 'full name'),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.edit_outlined),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.purple[600]!),
                    ),
                  ),
                  maxLines: 3,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = _nameController.text.trim();
              final newBio = _bioController.text.trim();

              // Check if there are actual changes
              bool hasChanges = false;
              String? nameToUpdate;
              String? bioToUpdate;

              if (newName.isNotEmpty && newName != (_userData?['fullName'] ?? '')) {
                hasChanges = true;
                nameToUpdate = newName;
              }

              if (newBio != (_userData?['bio'] ?? '')) {
                hasChanges = true;
                bioToUpdate = newBio.isEmpty ? null : newBio;
              }

              if (hasChanges) {
                Navigator.pop(context);
                _updateProfile(
                  fullName: nameToUpdate,
                  bio: bioToUpdate,
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No changes detected'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Avatar management methods
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue[600]),
              ),
              title: Text('Take Photo'),
              subtitle: Text('Capture a new profile picture'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.green[600]),
              ),
              title: Text('Choose from Gallery'),
              subtitle: Text('Select from your photo gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_userData?['avatarUrl'] != null)
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete, color: Colors.red[600]),
                ),
                title: Text('Remove Photo'),
                subtitle: Text('Use default avatar'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveAvatarConfirmation();
                },
              ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showRemoveAvatarConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Profile Picture'),
        content: Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile(removeAvatar: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? imageFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imageFile != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Updating profile picture...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await _updateProfile(avatarFile: File(imageFile.path));

        // Close loading dialog
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
            icon: Icon(Icons.edit, color: Colors.purple[600]),
            onPressed: _showEditProfileDialog,
            tooltip: 'Edit Profile',
          ),
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
              // Enhanced Profile Header Card with avatar editing
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
                    // Enhanced Avatar with editing capability
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.purple[100]!,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.purple[100],
                            child: _userData?['avatarUrl'] != null && _userData!['avatarUrl'].isNotEmpty
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: CachedNetworkImage(
                                imageUrl: _userData!['avatarUrl'],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 100,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => _buildAvatarText(),
                              ),
                            )
                                : _buildAvatarText(),
                          ),
                        ),
                        // Enhanced camera button
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showAvatarOptions,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple[600],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        // Role indicator
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _userData?['role'] == 'student' ? Colors.blue[600] : Colors.green[600],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _userData?['role'] == 'student' ? Icons.school : Icons.person,
                              color: Colors.white,
                              size: 14,
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

                    // Bio section
                    if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userData!['bio'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

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

                    // Enhanced action buttons
                    CustomButton(
                      text: 'Edit Profile',
                      onPressed: _showEditProfileDialog,
                      backgroundColor: Colors.purple[600],
                      icon: Icons.edit,
                    ),

                    SizedBox(height: 12),

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

              // Loading indicator when updating
              if (_isUpdating)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  margin: EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
                        strokeWidth: 2,
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Updating profile...',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
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