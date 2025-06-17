import 'package:flutter/material.dart';
import 'auth_services.dart';
import 'custom_widgets.dart';
import 'validators.dart';

class AdminSignUpPage extends StatefulWidget {
  @override
  _AdminSignUpPageState createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends State<AdminSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _organizationNameController = TextEditingController();
  final _organizationCodeController = TextEditingController();
  final _authService = AuthService();

  bool _isJoiningExisting = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingOrganization = false;
  bool _organizationExists = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _organizationCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkOrganizationExists() async {
    final code = _organizationCodeController.text.trim();
    if (code.length < 3) return;

    setState(() => _isCheckingOrganization = true);
    final exists = await _authService.checkOrganizationExists(code);
    setState(() {
      _organizationExists = exists;
      _isCheckingOrganization = false;
    });
  }

  Future<void> _signUpAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _authService.signUpAdmin(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _fullNameController.text.trim(),
      organizationCode: _organizationCodeController.text.trim(),
      organizationName: _organizationNameController.text.trim(),
      isJoiningExisting: _isJoiningExisting,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      SuccessSnackbar.show(
        context,
        _isJoiningExisting
            ? 'Successfully joined organization!'
            : 'Organization created successfully!',
        subtitle: 'Please check your email to verify your account',
      );

      await Future.delayed(Duration(seconds: 2));
      Navigator.pushReplacementNamed(context, '/');
    } else {
      ErrorSnackbar.show(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Admin Sign Up'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                      'Create or join an organization',
                      style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),

              // Toggle buttons
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
                padding: EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isJoiningExisting = false),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: !_isJoiningExisting ? Colors.blue[600] : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
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
                                style: TextStyle(
                                  color: !_isJoiningExisting ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
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
                            color: _isJoiningExisting ? Colors.green[600] : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
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
                                style: TextStyle(
                                  color: _isJoiningExisting ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
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
              SizedBox(height: 32),

              // Form fields
              Container(
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
                  children: [
                    CustomTextField(
                      controller: _organizationCodeController,
                      label: 'Organization Code',
                      icon: Icons.business,
                      textCapitalization: TextCapitalization.characters,
                      helperText: _isJoiningExisting
                          ? 'Enter the code of organization to join'
                          : 'Create a unique code for your organization',
                      validator: (value) {
                        final error = Validators.organizationCode(value);
                        if (error != null) return error;
                        if (_isJoiningExisting && !_organizationExists) {
                          return 'Organization not found';
                        }
                        if (!_isJoiningExisting && _organizationExists) {
                          return 'Code already exists';
                        }
                        return null;
                      },
                      onChanged: (value) => _checkOrganizationExists(),
                      suffixIcon: _isCheckingOrganization
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : _organizationCodeController.text.length >= 3
                          ? Icon(
                        _organizationExists ? Icons.check_circle : Icons.cancel,
                        color: _organizationExists
                            ? (_isJoiningExisting ? Colors.green : Colors.red)
                            : (_isJoiningExisting ? Colors.red : Colors.green),
                      )
                          : null,
                    ),

                    if (!_isJoiningExisting) ...[
                      SizedBox(height: 20),
                      CustomTextField(
                        controller: _organizationNameController,
                        label: 'Organization Name',
                        icon: Icons.school,
                        validator: (value) => Validators.required(value, 'organization name'),
                      ),
                    ],

                    SizedBox(height: 30),
                    Divider(),
                    SizedBox(height: 20),

                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),

                    CustomTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) => Validators.required(value, 'full name'),
                    ),
                    SizedBox(height: 20),

                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    SizedBox(height: 20),

                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      validator: Validators.password,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    SizedBox(height: 20),

                    CustomTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      validator: (value) => Validators.confirmPassword(value, _passwordController.text),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Submit button
              CustomButton(
                text: _isLoading
                    ? (_isJoiningExisting ? 'Joining Organization...' : 'Creating Organization...')
                    : (_isJoiningExisting ? 'Join Organization' : 'Create Organization'),
                onPressed: _signUpAdmin,
                isLoading: _isLoading,
                backgroundColor: _isJoiningExisting ? Colors.green[600] : Colors.blue[600],
                icon: _isJoiningExisting ? Icons.group_add : Icons.add_business,
              ),

              SizedBox(height: 24),

              // Footer
              Center(
                child: Text(
                  'By signing up, you agree to our Terms of Service',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}