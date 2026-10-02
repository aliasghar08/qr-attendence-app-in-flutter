import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/academic_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_components.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _academicService = AcademicService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _designationController = TextEditingController();

  String _role = 'student'; // 'student' or 'teacher'
  String _department = AcademicService.departments.first;
  String? _course;
  String? _batch;
  String? _semester;

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _updateCourseList();
  }

  void _updateCourseList() {
    final courses = _academicService.getCoursesForDepartment(_department);
    setState(() {
      _course = courses.isNotEmpty ? courses.first : null;
      _updateBatchAndSemesters();
    });
  }

  void _updateBatchAndSemesters() {
    if (_course != null) {
      final batches = _academicService.generateBatches(_course!);
      final semesters = _academicService.generateSemesters(_course!);
      setState(() {
        _batch = batches.isNotEmpty ? batches.first : null;
        _semester = semesters.isNotEmpty ? semesters.first : null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rollNoController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signup(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      final userData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _role,
        'department': _department,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_role == 'student') {
        userData['rollNo'] = _rollNoController.text.trim();
        userData['course'] = _course ?? '';
        userData['batch'] = _batch ?? '';
        userData['semester'] = _semester ?? '';
      } else {
        userData['designation'] = _designationController.text.trim().isEmpty
            ? 'Faculty Member'
            : _designationController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Account created successfully! Please sign in.'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = _academicService.getCoursesForDepartment(_department);
    final batches = _course != null ? _academicService.generateBatches(_course!) : <String>[];
    final semesters = _course != null ? _academicService.generateSemesters(_course!) : <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon
                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/SmarRoll.jpeg',
                            width: 70,
                            height: 70,
                            cacheWidth: 210,
                            cacheHeight: 210,
                            filterQuality: FilterQuality.medium,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    // Role Segmented Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _role = 'student'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: _role == 'student' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _role == 'student'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      size: 18,
                                      color: _role == 'student'
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Student Account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _role == 'student'
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _role == 'student'
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _role = 'teacher'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: _role == 'teacher' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _role == 'teacher'
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.co_present_rounded,
                                      size: 18,
                                      color: _role == 'teacher'
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Faculty Account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _role == 'teacher'
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _role == 'teacher'
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
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
                    const SizedBox(height: 18),

                    // Main Details Card
                    PlannerCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal & Login Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Full Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'e.g. Dr. John Doe / Alex Smith',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 14),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'name@university.edu',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter your email';
                              if (!val.contains('@')) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Min 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Academic Details Card
                    PlannerCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _role == 'teacher' ? 'Faculty Assignment' : 'Academic Information',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Department Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _department,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                            isExpanded: true,
                            items: AcademicService.departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(dept, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (newDept) {
                              if (newDept != null) {
                                setState(() {
                                  _department = newDept;
                                  _updateCourseList();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          if (_role == 'student') ...[
                            // Degree Course
                            DropdownButtonFormField<String>(
                              initialValue: courses.contains(_course) ? _course : (courses.isNotEmpty ? courses.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Degree / Program',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              isExpanded: true,
                              items: courses.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (newCourse) {
                                if (newCourse != null) {
                                  setState(() {
                                    _course = newCourse;
                                    _updateBatchAndSemesters();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Roll Number
                            TextFormField(
                              controller: _rollNoController,
                              decoration: const InputDecoration(
                                labelText: 'Student Roll No / ID',
                                hintText: 'e.g. 21-CS-042',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter your roll number' : null,
                            ),
                            const SizedBox(height: 14),

                            // Batch and Semester in row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: batches.contains(_batch) ? _batch : (batches.isNotEmpty ? batches.first : null),
                                    decoration: const InputDecoration(
                                      labelText: 'Batch',
                                      prefixIcon: Icon(Icons.group_outlined),
                                    ),
                                    isExpanded: true,
                                    items: batches.map((b) {
                                      return DropdownMenuItem(
                                        value: b,
                                        child: Text(b, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (b) => setState(() => _batch = b),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: semesters.contains(_semester) ? _semester : (semesters.isNotEmpty ? semesters.first : null),
                                    decoration: const InputDecoration(
                                      labelText: 'Semester',
                                      prefixIcon: Icon(Icons.calendar_today_outlined),
                                    ),
                                    isExpanded: true,
                                    items: semesters.map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (s) => setState(() => _semester = s),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Designation for faculty
                            TextFormField(
                              controller: _designationController,
                              decoration: const InputDecoration(
                                labelText: 'Designation / Title',
                                hintText: 'e.g. Assistant Professor, Lecturer',
                                prefixIcon: Icon(Icons.work_outline_rounded),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    PlannerButton(
                      text: 'Create Account',
                      icon: Icons.person_add_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleSignup,
                    ),
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
}