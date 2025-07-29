import 'package:flutter/material.dart';
import 'auth_services.dart';
import 'custom_widgets.dart';
import 'validators.dart';

class SignUpPage extends StatefulWidget {
  final String role;

  const SignUpPage({Key? key, required this.role}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationCodeController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCheckingOrgCode = false;

  String? _organizationId;
  String? _organizationName;
  String? _selectedFacultyId;
  String? _selectedProgramId;

  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _programs = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkOrganizationCode() async {
    final code = _organizationCodeController.text.trim().toUpperCase();
    print('Checking organization code: $code');
    if (code.isEmpty || code.length < 3) {
      setState(() {
        _organizationId = null;
        _organizationName = null;
        _faculties = [];
        _programs = [];
      });
      return;
    }

    setState(() => _isCheckingOrgCode = true);

    final orgDetails = await _authService.getOrganizationDetails(code);

    if (orgDetails != null) {
      setState(() {
        _organizationId = orgDetails['id'];
        _organizationName = orgDetails['name'];
      });
      await _loadFaculties();
    } else {
      setState(() {
        _organizationId = null;
        _organizationName = null;
        _faculties = [];
        _programs = [];
      });
    }

    setState(() => _isCheckingOrgCode = false);
  }

  Future<void> _loadFaculties() async {
    if (_organizationId == null) return;
    final faculties = await _authService.getFaculties(_organizationId!);
    setState(() => _faculties = faculties);
  }

  Future<void> _loadPrograms(String facultyId) async {
    if (_organizationId == null) return;
    final programs = await _authService.getPrograms(_organizationId!, facultyId);
    setState(() => _programs = programs);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Get selected faculty details
    final selectedFaculty = _faculties.firstWhere(
          (f) => f['id'] == _selectedFacultyId,
      orElse: () => {},
    );

    // Get selected program details (for students)
    String? programId;
    String? programName;

    if (widget.role == 'student' && _selectedProgramId != null) {
      final selectedProgram = _programs.firstWhere(
            (p) => p['id'] == _selectedProgramId,
        orElse: () => {},
      );
      programId = _selectedProgramId;
      programName = selectedProgram.isNotEmpty ? selectedProgram['name'] : null;
    }

    final result = await _authService.signUpUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _nameController.text.trim(),
      role: widget.role,
      organizationCode: _organizationCodeController.text.trim().toUpperCase(), // FIX: Convert to uppercase
      facultyId: _selectedFacultyId,
      facultyName: selectedFaculty['name'],
      programId: programId,
      programName: programName,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      SuccessSnackbar.show(
        context,
        'Welcome to $_organizationName! 🎉',
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.role == 'student' ? 'Student' : 'Lecturer'} Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Join Study Hub Today',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E4A89),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Image.asset(
                      'assets/images/sparkle.png',
                      height: 30,
                      width: 30,
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  widget.role == 'student'
                      ? 'Create your student account and start learning'
                      : 'Create your lecturer account and start teaching',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),

                // Organization code field
                CustomTextField(
                  controller: _organizationCodeController,
                  label: 'Organization Code',
                  icon: Icons.business,
                  textCapitalization: TextCapitalization.characters,
                  helperText: _organizationName,
                  validator: (value) {
                    final error = Validators.organizationCode(value);
                    if (error != null) return error;
                    if (_organizationId == null) {
                      return 'Invalid organization code';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length >= 3) {
                      _checkOrganizationCode();
                    } else {
                      setState(() {
                        _organizationId = null;
                        _organizationName = null;
                        _faculties = [];
                        _programs = [];
                      });
                    }
                  },
                  suffixIcon: _isCheckingOrgCode
                      ? Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : _organizationId != null
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                SizedBox(height: 20),

                // Personal information
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (value) => Validators.required(value, 'full name'),
                ),
                SizedBox(height: 20),

                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
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
                SizedBox(height: 20),

                // Faculty dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedFacultyId,
                  onChanged: _organizationId == null
                      ? null
                      : (value) {
                    setState(() {
                      _selectedFacultyId = value;
                      _selectedProgramId = null;
                      _programs = [];
                    });
                    if (value != null && widget.role == 'student') {
                      _loadPrograms(value);
                    }
                  },
                  items: _faculties.map((faculty) {
                    return DropdownMenuItem<String>(
                      value: faculty['id'],
                      child: Text(
                        '${faculty['code']} - ${faculty['name']}',
                        overflow: TextOverflow.ellipsis, // Add ellipsis for long text
                        maxLines: 1, // Ensure single line
                      ),
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    prefixIcon: Icon(Icons.school, color: Colors.purple[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: _organizationId == null,
                    fillColor: _organizationId == null ? Colors.grey[200] : null,
                  ),
                  hint: Text(_organizationId == null ? 'Enter organization code first' : 'Select faculty'),
                  validator: (value) => Validators.required(value, 'faculty'),
                ),

// Apply the same fix to the Program dropdown
                if (widget.role == 'student') ...[
                  SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    isExpanded: true, // Add this
                    value: _selectedProgramId,
                    onChanged: _selectedFacultyId == null ? null : (value) => setState(() => _selectedProgramId = value),
                    items: _programs.map((program) {
                      return DropdownMenuItem<String>(
                        value: program['id'],
                        child: Text(
                          '${program['code']} - ${program['name']}',
                          overflow: TextOverflow.ellipsis, // Add ellipsis
                          maxLines: 1, // Single line
                        ),
                      );
                    }).toList(),
                    decoration: InputDecoration(
                      labelText: 'Program',
                      prefixIcon: Icon(Icons.book, color: Colors.purple[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: _selectedFacultyId == null,
                      fillColor: _selectedFacultyId == null ? Colors.grey[200] : null,
                    ),
                    hint: Text(_selectedFacultyId == null ? 'Select faculty first' : 'Select program'),
                    validator: (value) => Validators.required(value, 'program'),
                  ),
                ],

                SizedBox(height: 32),

                // Sign up button
                CustomButton(
                  text: _isLoading ? 'Creating Account...' : 'Sign Up',
                  onPressed: _signUp,
                  isLoading: _isLoading,
                ),

                SizedBox(height: 20),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: Colors.grey[600])),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/signIn'),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.purple[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}