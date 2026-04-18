import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final rollController = TextEditingController();
  final semesterController = TextEditingController();

  String role = "student";
  String selectedDepartment = "Computer Science";
  DateTime? selectedDob;
  bool loading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  // Password strength tracking
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final authService = AuthService();

  // Department list
  final List<String> departments = [
    "Computer Science",
    "Software Engineering",
    "Information Technology",
    "Electrical Engineering",
    "Mechanical Engineering",
    "Civil Engineering",
    "Business Administration",
    "Mathematics",
    "Physics",
    "Chemistry",
    "Biology",
    "Psychology",
    "Economics",
    "English Literature",
    "Media Studies",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
    
    // Add listener to password controller for real-time strength validation
    passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    setState(() {
      final password = passwordController.text;
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordValid() {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;
  }

  String? _validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    // Regular expression for email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    // Check for common email providers (optional)
    final domain = email.split('@').last.toLowerCase();
    if (!domain.contains('.') || domain.length < 4) {
      return 'Please enter a valid email domain';
    }
    
    return null;
  }

  String? _validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (confirmPassword != passwordController.text) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  String? _validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Full name is required';
    }
    
    if (name.length < 3) {
      return 'Name must be at least 3 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      return 'Name should only contain letters and spaces';
    }
    
    return null;
  }

  String? _validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }
    
    if (phone.length < 10 || phone.length > 15) {
      return 'Phone number must be between 10-15 digits';
    }
    
    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(phone)) {
      return 'Please enter a valid phone number';
    }
    
    return null;
  }

  String? _validateRollNumber(String? rollNo) {
    if (role == "student") {
      if (rollNo == null || rollNo.isEmpty) {
        return 'Roll number is required';
      }
      
      if (rollNo.length < 3) {
        return 'Please enter a valid roll number';
      }
    }
    return null;
  }

  String? _validateSemester(String? semester) {
    if (role == "student") {
      if (semester == null || semester.isEmpty) {
        return 'Semester is required';
      }
      
      final semesterNum = int.tryParse(semester);
      if (semesterNum == null || semesterNum < 1 || semesterNum > 8) {
        return 'Please enter a valid semester (1-8)';
      }
    }
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    rollController.dispose();
    semesterController.dispose();
    _animationController.dispose();
    passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  Future<void> pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF1A237E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        selectedDob = date;
      });
    }
  }

  void signup() async {
    // Validate all fields
    final nameError = _validateName(nameController.text.trim());
    if (nameError != null) {
      _showErrorSnackBar(nameError);
      return;
    }
    
    final emailError = _validateEmail(emailController.text.trim());
    if (emailError != null) {
      _showErrorSnackBar(emailError);
      return;
    }
    
    final passwordError = _validatePassword(passwordController.text);
    if (passwordError != null) {
      _showErrorSnackBar(passwordError);
      return;
    }
    
    final confirmPasswordError = _validateConfirmPassword(confirmPasswordController.text);
    if (confirmPasswordError != null) {
      _showErrorSnackBar(confirmPasswordError);
      return;
    }
    
    final phoneError = _validatePhone(phoneController.text.trim());
    if (phoneError != null) {
      _showErrorSnackBar(phoneError);
      return;
    }
    
    if (selectedDepartment.isEmpty) {
      _showErrorSnackBar('Please select your department');
      return;
    }
    
    if (selectedDob == null) {
      _showErrorSnackBar('Please select your date of birth');
      return;
    }
    
    final rollError = _validateRollNumber(rollController.text.trim());
    if (rollError != null) {
      _showErrorSnackBar(rollError);
      return;
    }
    
    final semesterError = _validateSemester(semesterController.text.trim());
    if (semesterError != null) {
      _showErrorSnackBar(semesterError);
      return;
    }

    setState(() => loading = true);

    try {
      final user = await authService.signup(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final uid = user!.uid;

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim().toLowerCase(),
        "phone": phoneController.text.trim(),
        "role": role,
        "department": selectedDepartment,
        "rollNo": role == "student" ? rollController.text.trim().toUpperCase() : null,
        "semester": role == "student" ? semesterController.text.trim() : null,
        "dob": selectedDob?.toIso8601String(),
        "createdAt": DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(child: Text('Account created successfully! Please login.')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }

    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    
                    if (loading)
                      LinearProgressIndicator(
                        value: null,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    _buildAnimatedTextField(
                      controller: nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: _validateName,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedTextField(
                      controller: emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedPasswordField(),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedConfirmPasswordField(),
                    
                    const SizedBox(height: 16),
                    
                    _buildPasswordStrengthIndicator(),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedTextField(
                      controller: phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedRoleDropdown(),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedDepartmentDropdown(),
                    
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: role == "student"
                          ? Column(
                              key: const ValueKey('student_fields'),
                              children: [
                                const SizedBox(height: 16),
                                _buildAnimatedTextField(
                                  controller: rollController,
                                  label: 'Roll Number',
                                  icon: Icons.numbers_outlined,
                                  keyboardType: TextInputType.text,
                                  validator: _validateRollNumber,
                                  textCapitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                _buildAnimatedTextField(
                                  controller: semesterController,
                                  label: 'Semester',
                                  icon: Icons.grade_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: _validateSemester,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildDobPicker(),
                    
                    const SizedBox(height: 24),
                    
                    _buildSignUpButton(),
                    
                    const SizedBox(height: 20),
                    
                    _buildLoginLink(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Column(
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.blue],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join our learning community',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedPasswordField() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextFormField(
          controller: passwordController,
          obscureText: !_isPasswordVisible,
          keyboardType: TextInputType.text,
          validator: (value) => _validatePassword(value),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Minimum 8 characters',
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A237E)),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedConfirmPasswordField() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextFormField(
          controller: confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          keyboardType: TextInputType.text,
          validator: (value) => _validateConfirmPassword(value),
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A237E)),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.grey.shade200,
            ),
            child: Row(
              children: [
                _buildStrengthBar(_hasMinLength, Colors.blue),
                _buildStrengthBar(_hasUppercase, Colors.blue),
                _buildStrengthBar(_hasLowercase, Colors.blue),
                _buildStrengthBar(_hasNumber, Colors.blue),
                _buildStrengthBar(_hasSpecialChar, Colors.blue),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getPasswordStrengthMessage(),
            style: TextStyle(
              fontSize: 12,
              color: _getPasswordStrengthColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthBar(bool isValid, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: isValid ? color : Colors.grey.shade200,
        ),
      ),
    );
  }

  String _getPasswordStrengthMessage() {
    if (_isPasswordValid()) {
      return '✓ Strong password!';
    } else if (_hasMinLength || _hasUppercase || _hasLowercase || _hasNumber || _hasSpecialChar) {
      final missing = <String>[];
      if (!_hasMinLength) missing.add('8+ chars');
      if (!_hasUppercase) missing.add('uppercase');
      if (!_hasLowercase) missing.add('lowercase');
      if (!_hasNumber) missing.add('number');
      if (!_hasSpecialChar) missing.add('special char');
      return 'Weak password - Missing: ${missing.join(", ")}';
    } else {
      return 'Enter a strong password';
    }
  }

  Color _getPasswordStrengthColor() {
    if (_isPasswordValid()) {
      return Colors.green;
    } else if (_hasMinLength || _hasUppercase || _hasLowercase || _hasNumber || _hasSpecialChar) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildAnimatedRoleDropdown() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: role,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: "student",
              child: Row(
                children: [
                  Icon(Icons.school, size: 20, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Student",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: "teacher",
              child: Row(
                children: [
                  Icon(Icons.cast_for_education, size: 20, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Teacher",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => role = value!);
          },
          decoration: InputDecoration(
            labelText: "Role",
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1A237E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDepartmentDropdown() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: selectedDepartment,
          isExpanded: true,
          items: departments.map<DropdownMenuItem<String>>((String department) {
            return DropdownMenuItem<String>(
              value: department,
              child: Row(
                children: [
                  Icon(Icons.business_center, size: 20, color: const Color(0xFF1A237E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      department,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedDepartment = newValue;
              });
            }
          },
          decoration: InputDecoration(
            labelText: "Department",
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF1A237E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildDobPicker() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: pickDob,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF1A237E)),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    selectedDob == null
                        ? "Select Date of Birth"
                        : "DOB: ${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}",
                    style: TextStyle(
                      color: selectedDob == null ? Colors.grey.shade600 : Colors.black,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (selectedDob != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        selectedDob = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: loading ? null : [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: loading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Already have an account? ',
            style: TextStyle(color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text(
              'Sign In',
              style: TextStyle(
                color: const Color(0xFF1A237E),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}