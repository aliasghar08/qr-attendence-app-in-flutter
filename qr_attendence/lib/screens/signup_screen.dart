import 'package:flutter/material.dart';
import '../services/academic_service.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_components.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _academicService = AcademicService();
  final _authViewModel = AuthViewModel();

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

  bool _isPasswordVisible = false;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _updateCourseList();
    _animController.forward();
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
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rollNoController.dispose();
    _designationController.dispose();
    _authViewModel.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    final extraData = <String, dynamic>{
      'role': _role,
      'department': _department,
      if (_role == 'student') ...{
        'rollNo': _rollNoController.text.trim(),
        'course': _course ?? '',
        'batch': _batch ?? '',
        'semester': _semester ?? '',
      } else ...{
        'designation': _designationController.text.trim().isEmpty
            ? 'Faculty Member'
            : _designationController.text.trim(),
      },
    };

    final user = await _authViewModel.signUp(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _role,
      extraData: extraData,
    );

    if (!mounted) return;

    if (user != null) {
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
    } else if (_authViewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(_authViewModel.errorMessage!)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: ListenableBuilder(
          listenable: _authViewModel,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 760;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 36 : 20,
                      vertical: isTablet ? 28 : 12,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 1040 : 480,
                      ),
                      child: Form(
                        key: _formKey,
                        child: isTablet
                            ? _buildTabletSignupLayout()
                            : _buildMobileSignupLayout(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabletSignupLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Institutional Info & Requirement Checklist
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/SmarRoll.jpeg',
                        width: 76,
                        height: 76,
                        cacheWidth: 228,
                        cacheHeight: 228,
                        filterQuality: FilterQuality.medium,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Campus Portal Registration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Create verified faculty or student credentials',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                _buildInfoRequirementCard(
                  title: 'Student Identity Verification',
                  desc: 'Provide your accurate academic roll number and program. Attendance records are tied directly to your university registrar profile.',
                  icon: Icons.verified_user_rounded,
                ),
                const SizedBox(height: 16),
                _buildInfoRequirementCard(
                  title: 'Anti-Proxy Geofencing',
                  desc: 'Classroom location permissions are required when scanning dynamic attendance codes on campus.',
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 16),
                _buildInfoRequirementCard(
                  title: 'Privacy & FERPA Protection',
                  desc: 'Location telemetry is strictly used during active lecture scan windows and never stored for continuous tracking.',
                  icon: Icons.security_rounded,
                ),
              ],
            ),
          ),
        ),

        // Right Column: Registration Form Cards
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoleSegmentedControl(),
              const SizedBox(height: 18),
              _buildPersonalDetailsCard(),
              const SizedBox(height: 16),
              _buildAcademicDetailsCard(),
              const SizedBox(height: 24),
              PlannerButton(
                text: 'Create Account',
                icon: Icons.how_to_reg_rounded,
                isLoading: _authViewModel.isLoading,
                onPressed: _handleSignup,
              ),
              const SizedBox(height: 18),
              _buildSignInFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSignupLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Icon & Header
        StaggeredEntrance(
          controller: _animController,
          startInterval: 0.00,
          endInterval: 0.35,
          slideOffset: const Offset(0, 0.2),
          curve: Curves.elasticOut,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/SmarRoll.jpeg',
                      width: 76,
                      height: 76,
                      cacheWidth: 228,
                      cacheHeight: 228,
                      filterQuality: FilterQuality.medium,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Join Smart Roll for automated campus attendance',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Role Segmented Tabs
        StaggeredEntrance(
          controller: _animController,
          startInterval: 0.15,
          endInterval: 0.45,
          child: _buildRoleSegmentedControl(),
        ),
        const SizedBox(height: 18),

        // Personal Details Card
        StaggeredEntrance(
          controller: _animController,
          startInterval: 0.30,
          endInterval: 0.60,
          child: _buildPersonalDetailsCard(),
        ),
        const SizedBox(height: 16),

        // Academic Details Card
        StaggeredEntrance(
          controller: _animController,
          startInterval: 0.45,
          endInterval: 0.75,
          child: _buildAcademicDetailsCard(),
        ),
        const SizedBox(height: 24),

        // Signup Button
        StaggeredEntrance(
          controller: _animController,
          startInterval: 0.60,
          endInterval: 0.90,
          child: PlannerButton(
            text: 'Create Account',
            icon: Icons.how_to_reg_rounded,
            isLoading: _authViewModel.isLoading,
            onPressed: _handleSignup,
          ),
        ),
        const SizedBox(height: 18),

        _buildSignInFooter(),
      ],
    );
  }

  Widget _buildInfoRequirementCard({
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.elevationSubtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.elevationSubtle,
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
    );
  }

  Widget _buildPersonalDetailsCard() {
    return PlannerCard(
      padding: const EdgeInsets.all(20),
      shadows: AppColors.elevationMedium,
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
    );
  }

  Widget _buildAcademicDetailsCard() {
    final courses = _academicService.getCoursesForDepartment(_department);
    final batches = _course != null ? _academicService.generateBatches(_course!) : <String>[];
    final semesters = _course != null ? _academicService.generateSemesters(_course!) : <String>[];

    return PlannerCard(
      padding: const EdgeInsets.all(20),
      shadows: AppColors.elevationMedium,
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
            TextFormField(
              controller: _designationController,
              decoration: const InputDecoration(
                labelText: 'Academic Designation',
                hintText: 'e.g. Assistant Professor / Lecturer',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignInFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Sign In',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}