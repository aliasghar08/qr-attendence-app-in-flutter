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
  final phoneController = TextEditingController();
  final rollController = TextEditingController();
  final semesterController = TextEditingController();

  String role = "student";
  String selectedDepartment = "Computer Science";
  DateTime? selectedDob;
  bool loading = false;
  bool _isPasswordVisible = false;
  
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
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    rollController.dispose();
    semesterController.dispose();
    _animationController.dispose();
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
    // Validation
    if (nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your full name');
      return;
    }
    if (emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email');
      return;
    }
    if (!emailController.text.contains('@')) {
      _showErrorSnackBar('Please enter a valid email');
      return;
    }
    if (passwordController.text.length < 6) {
      _showErrorSnackBar('Password must be at least 6 characters');
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your phone number');
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
    if (role == "student" && rollController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your roll number');
      return;
    }
    if (role == "student" && semesterController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your semester');
      return;
    }

    setState(() => loading = true);

    try {
      // 1. Create Auth user
      final user = await authService.signup(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final uid = user!.uid;

      // 2. Save full profile in Firestore
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(),
        "role": role,
        "department": selectedDepartment,
        "rollNo": role == "student" ? rollController.text.trim() : null,
        "semester": role == "student" ? semesterController.text.trim() : null,
        "dob": selectedDob?.toIso8601String(),
        "createdAt": DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Show success message
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
        
        // Navigate to login screen after a short delay
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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
                    // Animated Header
                    _buildHeader(),
                    
                    const SizedBox(height: 32),
                    
                    // Progress Indicator
                    if (loading)
                      LinearProgressIndicator(
                        value: null,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Form Fields
                    _buildAnimatedTextField(
                      controller: nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedTextField(
                      controller: emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedTextField(
                      controller: passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: !_isPasswordVisible,
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
                      hintText: 'Minimum 6 characters',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildAnimatedTextField(
                      controller: phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Role Dropdown
                    _buildAnimatedRoleDropdown(),
                    
                    const SizedBox(height: 16),
                    
                    // Department Dropdown
                    _buildAnimatedDepartmentDropdown(),
                    
                    // Conditional Student Fields with Number Input Only
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
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
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
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date of Birth Picker
                    _buildDobPicker(),
                    
                    const SizedBox(height: 24),
                    
                    // Sign Up Button
                    _buildSignUpButton(),
                    
                    const SizedBox(height: 20),
                    
                    // Login Link
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
          ),
          const SizedBox(height: 8),
          Text(
            'Join our learning community',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
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
          items: const [
            DropdownMenuItem(
              value: "student",
              child: Row(
                children: [
                  Icon(Icons.school, size: 20, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Text("Student"),
                ],
              ),
            ),
            DropdownMenuItem(
              value: "teacher",
              child: Row(
                children: [
                  Icon(Icons.cast_for_education, size: 20, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Text("Teacher"),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 5),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 5),
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
                ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        GestureDetector(
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
          ),
        ),
      ],
    );
  }
}