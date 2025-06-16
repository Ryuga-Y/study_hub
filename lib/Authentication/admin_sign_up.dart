import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSignUpPage extends StatefulWidget {
  @override
  _AdminSignUpPageState createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends State<AdminSignUpPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _organizationNameController = TextEditingController();
  final _organizationCodeController = TextEditingController();

  bool _isJoiningExisting = false;
  bool _isLoading = false;
  bool _organizationExists = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingOrganization = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _organizationCodeController.dispose();
    super.dispose();
  }

  Future<void> _signUpAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create Firebase Auth user
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String orgCode = _organizationCodeController.text.trim().toUpperCase();

      if (_isJoiningExisting) {
        await _joinExistingOrganization(userCredential.user!.uid, orgCode);
      } else {
        await _createNewOrganization(userCredential.user!.uid, orgCode);
      }

      await userCredential.user!.updateDisplayName(_fullNameController.text.trim());

      _showSuccessMessage();
      Navigator.pushReplacementNamed(context, '/admin_dashboard');

    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNewOrganization(String uid, String orgCode) async {
    // Check if organization already exists
    DocumentSnapshot orgDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgCode)
        .get();

    if (orgDoc.exists) {
      throw Exception('Organization code already exists');
    }

    // Use batch write for consistency
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Create user document
    batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'email': _emailController.text.trim(),
          'fullName': _fullNameController.text.trim(),
          'role': 'admin',
          'organizationCode': orgCode,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }
    );

    // Create organization document
    batch.set(
        FirebaseFirestore.instance.collection('organizations').doc(orgCode),
        {
          'name': _organizationNameController.text.trim(),
          'code': orgCode,
          'createdBy': uid,
          'admins': [uid], // Start with one admin
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'settings': {
            'allowStudentRegistration': true,
            'allowLecturerRegistration': false,
            'requireEmailVerification': true,
          }
        }
    );

    await batch.commit();
  }

  Future<void> _joinExistingOrganization(String uid, String orgCode) async {
    // Check if organization exists
    DocumentSnapshot orgDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgCode)
        .get();

    if (!orgDoc.exists) {
      throw Exception('Organization not found');
    }

    // Use batch write for consistency
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Create user document
    batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'email': _emailController.text.trim(),
          'fullName': _fullNameController.text.trim(),
          'role': 'admin',
          'organizationCode': orgCode,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }
    );

    // Add admin to organization's admin list
    batch.update(
        FirebaseFirestore.instance.collection('organizations').doc(orgCode),
        {
          'admins': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }
    );

    await batch.commit();
  }

  Future<bool> _checkOrganizationExists(String orgCode) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgCode)
        .get();
    return doc.exists;
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(_isJoiningExisting
                ? 'Successfully joined organization!'
                : 'Organization created successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _handleError(dynamic error) {
    String message = 'An error occurred';
    IconData icon = Icons.error;

    if (error.toString().contains('Organization code already exists')) {
      message = 'Organization code already exists. Try joining instead.';
      icon = Icons.business_center;
    } else if (error.toString().contains('Organization not found')) {
      message = 'Organization not found. Try creating a new one.';
      icon = Icons.search_off;
    } else if (error.toString().contains('email-already-in-use')) {
      message = 'Email already registered';
      icon = Icons.email;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Admin Sign Up', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Welcome Admin!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create or join an organization to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // Toggle Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isJoiningExisting = false),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: !_isJoiningExisting
                                    ? Colors.blue[600]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !_isJoiningExisting ? [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ] : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_business,
                                    color: !_isJoiningExisting ? Colors.white : Colors.grey[600],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create New',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isJoiningExisting ? Colors.white : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isJoiningExisting = true),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: _isJoiningExisting
                                    ? Colors.green[600]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isJoiningExisting ? [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ] : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.group_add,
                                    color: _isJoiningExisting ? Colors.white : Colors.grey[600],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Join Existing',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isJoiningExisting ? Colors.white : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
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
                SizedBox(height: 32),

                // Form Fields
                _buildFormCard([
                  _buildTextField(
                    controller: _organizationCodeController,
                    label: 'Organization Code',
                    icon: Icons.business,
                    textCapitalization: TextCapitalization.characters,
                    helperText: _isJoiningExisting
                        ? 'Enter the code of organization you want to join'
                        : 'Create a unique code for your organization',
                    suffixIcon: _isCheckingOrganization
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : _organizationCodeController.text.length >= 3
                        ? Icon(
                      _organizationExists ? Icons.check_circle : Icons.cancel,
                      color: _organizationExists ? Colors.green : Colors.red,
                    )
                        : null,
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => _isCheckingOrganization = true);
                        bool exists = await _checkOrganizationExists(value.toUpperCase());
                        setState(() {
                          _organizationExists = exists;
                          _isCheckingOrganization = false;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter organization code';
                      }
                      if (value.trim().length < 3) {
                        return 'Code must be at least 3 characters';
                      }
                      return null;
                    },
                  ),

                  if (!_isJoiningExisting) ...[
                    SizedBox(height: 20),
                    _buildTextField(
                      controller: _organizationNameController,
                      label: 'Organization Name',
                      icon: Icons.school,
                      validator: (value) {
                        if (!_isJoiningExisting && (value == null || value.trim().isEmpty)) {
                          return 'Please enter organization name';
                        }
                        return null;
                      },
                    ),
                  ],

                  SizedBox(height: 20),
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ]),

                SizedBox(height: 32),

                // Submit Button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUpAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isJoiningExisting ? Colors.green[600] : Colors.blue[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: (_isJoiningExisting ? Colors.green : Colors.blue).withValues(alpha: 0.3),
                    ),
                    child: _isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isJoiningExisting ? Icons.group_add : Icons.add_business,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _isJoiningExisting
                              ? 'Join Organization'
                              : 'Create Organization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Footer
                Center(
                  child: Text(
                    'By signing up, you agree to our Terms of Service',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Container(
          margin: EdgeInsets.only(right: 12),
          child: Icon(icon, color: Colors.grey[600]),
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}