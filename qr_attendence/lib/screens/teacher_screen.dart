import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/academic_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../viewmodels/teacher_viewmodel.dart';
import '../widgets/clock_time_picker.dart';
import '../widgets/custom_components.dart';
import '../widgets/delete_account_modal.dart';
import '../widgets/qr_timer_widget.dart';
import 'login_screen.dart';
import 'teacher_lectures_history.dart';

class TeacherScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final Map<String, dynamic> userData;

  const TeacherScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userData,
  });

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with SingleTickerProviderStateMixin {
  late final TeacherViewModel _viewModel;
  final _authService = AuthService();
  late AnimationController _animController;

  final TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  final int _selectedDurationMinutes = 60;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _viewModel = TeacherViewModel();
    _viewModel.init(widget.userData['department']);
  }

  @override
  void dispose() {
    _animController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    final success = await _viewModel.startLectureSession(
      teacherId: widget.userId,
      teacherName: widget.userName,
      teacherEmail: widget.userEmail,
    );

    if (!mounted) return;

    if (!success && _viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_viewModel.errorMessage!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleEndSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Lecture Session?'),
        content: Text(
          'Total attendance logged: ${_viewModel.attendeeCount} students.\nAre you sure you want to finish this lecture?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final attendeeSnapshotCount = _viewModel.attendeeCount;
      final success = await _viewModel.endLectureSession();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lecture ended successfully. Recorded $attendeeSnapshotCount attendees.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else if (_viewModel.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_viewModel.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from Faculty Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildFacultyHeaderCard() {
    return PlannerCard(
      padding: const EdgeInsets.all(18),
      gradient: AppColors.primaryGradient,
      shadows: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.32),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.co_present_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.userData['designation'] ?? 'Faculty Member',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _viewModel.department,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (_viewModel.isSessionActive)
            const StatusPill(
              label: 'LIVE',
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    final location = _viewModel.teacherLocation;
    final isFetching = _viewModel.isFetchingLocation;

    return PlannerCard(
      padding: const EdgeInsets.all(14),
      shadows: AppColors.elevationSubtle,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: location != null ? AppColors.successLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              location != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
              color: location != null ? AppColors.successDark : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location != null ? 'Classroom Geofence Active' : 'Acquiring Classroom Location...',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  location != null ? location.address : 'Students must be within 100m to mark',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isFetching)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
              onPressed: _viewModel.acquireTeacherLocation,
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicQrCard() {
    final lectureId = _viewModel.currentLectureId!;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return PlannerCard(
      padding: const EdgeInsets.all(20),
      shadows: AppColors.elevationHigh,
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Dynamic Attendance QR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              StatusPill(
                label: 'AUTO-ROTATING',
                color: AppColors.secondaryDark,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Dynamic QR Code with smooth countdown
          DynamicLectureQRWidget(
            lectureId: lectureId,
            classId: '${_viewModel.course}-${_viewModel.batch}-${_viewModel.semester}',
            subject: _viewModel.subject!,
            date: dateStr,
            timeSlot: _viewModel.formattedTimeSlot,
            teacherId: widget.userId,
            teacherName: widget.userName,
            department: _viewModel.department,
            locationData: _viewModel.teacherLocation,
            refreshIntervalSeconds: 20,
          ),
          const SizedBox(height: 18),

          // Live Attendee Counter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('lectureId', isEqualTo: lectureId)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? _viewModel.attendeeCount;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                  boxShadow: AppColors.elevationSubtle,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_alt_rounded, color: AppColors.primaryDark),
                        SizedBox(width: 8),
                        Text(
                          'Students Present',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // End Lecture Button
          PlannerButton(
            text: 'Finish Lecture Session',
            icon: Icons.stop_circle_rounded,
            isSecondary: true,
            isLoading: _viewModel.isLoading,
            onPressed: _handleEndSession,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionSummaryCard() {
    return PlannerCard(
      padding: const EdgeInsets.all(18),
      shadows: AppColors.elevationSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Active Lecture Details',
            subtitle: 'Session is currently open for students',
            icon: Icons.broadcast_on_personal_rounded,
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Subject', _viewModel.subject ?? 'N/A'),
          const Divider(height: 16),
          _buildInfoRow('Program', _viewModel.course ?? 'N/A'),
          const Divider(height: 16),
          _buildInfoRow('Batch & Semester', '${_viewModel.batch ?? ''} • ${_viewModel.semester ?? ''}'),
          const Divider(height: 16),
          _buildInfoRow('Time Slot', _viewModel.formattedTimeSlot),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupFormCard() {
    final academic = _viewModel.academicService;
    final courses = academic.getCoursesForDepartment(_viewModel.department);
    final batches = _viewModel.course != null ? academic.generateBatches(_viewModel.course!) : <String>[];
    final semesters = _viewModel.course != null ? academic.generateSemesters(_viewModel.course!) : <String>[];
    final subjects = _viewModel.course != null
        ? academic.getSubjects(department: _viewModel.department, selectedCourse: _viewModel.course!)
        : <String>[];

    final isSessionActive = _viewModel.isSessionActive;

    return PlannerCard(
      padding: const EdgeInsets.all(20),
      shadows: AppColors.elevationMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Lecture Setup & Configuration',
            subtitle: 'Select program, timing, and subject',
            icon: Icons.tune_rounded,
          ),

          // Department Dropdown
          DropdownButtonFormField<String>(
            initialValue: _viewModel.department,
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
            onChanged: isSessionActive ? null : (newDept) {
              if (newDept != null) _viewModel.setDepartment(newDept);
            },
          ),
          const SizedBox(height: 14),

          // Course / Program Dropdown
          DropdownButtonFormField<String>(
            initialValue: courses.contains(_viewModel.course) ? _viewModel.course : (courses.isNotEmpty ? courses.first : null),
            decoration: const InputDecoration(
              labelText: 'Program / Course',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            isExpanded: true,
            items: courses.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Text(c, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: isSessionActive ? null : (newCourse) {
              if (newCourse != null) _viewModel.setCourse(newCourse);
            },
          ),
          const SizedBox(height: 14),

          // Batch and Semester in row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: batches.contains(_viewModel.batch) ? _viewModel.batch : (batches.isNotEmpty ? batches.first : null),
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
                  onChanged: isSessionActive ? null : (b) {
                    if (b != null) _viewModel.setBatch(b);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: semesters.contains(_viewModel.semester) ? _viewModel.semester : (semesters.isNotEmpty ? semesters.first : null),
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
                  onChanged: isSessionActive ? null : (s) {
                    if (s != null) _viewModel.setSemester(s);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subject Dropdown
          DropdownButtonFormField<String>(
            initialValue: subjects.contains(_viewModel.subject) ? _viewModel.subject : (subjects.isNotEmpty ? subjects.first : null),
            decoration: const InputDecoration(
              labelText: 'Subject / Course Unit',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
            isExpanded: true,
            items: subjects.map((sub) {
              return DropdownMenuItem(
                value: sub,
                child: Text(sub, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: isSessionActive ? null : (sub) {
              if (sub != null) _viewModel.setSubject(sub);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockCard() {
    return ClockTimePickerCard(
      initialStartTime: _selectedStartTime,
      initialDurationMinutes: _selectedDurationMinutes,
      onTimeSlotChanged: (slot) => _viewModel.setFormattedTimeSlot(slot),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (!_viewModel.isSessionActive)
          PlannerButton(
            text: 'Launch Lecture & Generate QR',
            icon: Icons.play_arrow_rounded,
            isLoading: _viewModel.isLoading,
            onPressed: _handleStartSession,
          ),
        const SizedBox(height: 12),

        // Account Deletion & Privacy Policy Option
        Center(
          child: TextButton.icon(
            onPressed: () => DeleteAccountModal.show(context),
            icon: const Icon(
              Icons.shield_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
            label: const Text(
              'Account Settings & Data Deletion',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/SmarRoll.jpeg',
                width: 28,
                height: 28,
                cacheWidth: 84,
                cacheHeight: 84,
                filterQuality: FilterQuality.medium,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Faculty Portal'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Lecture History',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherLecturesHistory(
                    teacherId: widget.userId,
                    teacherName: widget.userName,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Account & Settings',
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            onSelected: (value) {
              if (value == 'privacy') {
                showAppPrivacyPolicy(context);
              } else if (value == 'logout') {
                _handleLogout();
              } else if (value == 'delete_account') {
                DeleteAccountModal.show(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      'Privacy Policy',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: AppColors.textSecondary),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 760;

                if (isTablet) {
                  // Tablet dual-pane layout
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _viewModel.isSessionActive && _viewModel.currentLectureId != null
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Pane: Session summary & Faculty controls
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.00,
                                          endInterval: 0.35,
                                          child: _buildFacultyHeaderCard(),
                                        ),
                                        const SizedBox(height: 16),
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.10,
                                          endInterval: 0.40,
                                          child: _buildGpsCard(),
                                        ),
                                        const SizedBox(height: 16),
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.20,
                                          endInterval: 0.50,
                                          child: _buildActiveSessionSummaryCard(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Pane: Dynamic QR and live attendance
                                  Expanded(
                                    flex: 6,
                                    child: StaggeredEntrance(
                                      controller: _animController,
                                      startInterval: 0.15,
                                      endInterval: 0.55,
                                      child: _buildDynamicQrCard(),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Pane: Faculty Header, GPS & Clock Picker, Launch Button
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.00,
                                          endInterval: 0.35,
                                          child: _buildFacultyHeaderCard(),
                                        ),
                                        const SizedBox(height: 16),
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.10,
                                          endInterval: 0.40,
                                          child: _buildGpsCard(),
                                        ),
                                        const SizedBox(height: 16),
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.20,
                                          endInterval: 0.50,
                                          child: _buildClockCard(),
                                        ),
                                        const SizedBox(height: 16),
                                        StaggeredEntrance(
                                          controller: _animController,
                                          startInterval: 0.30,
                                          endInterval: 0.60,
                                          child: _buildActions(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Right Pane: Setup Form Card
                                  Expanded(
                                    flex: 6,
                                    child: StaggeredEntrance(
                                      controller: _animController,
                                      startInterval: 0.15,
                                      endInterval: 0.55,
                                      child: _buildSetupFormCard(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }

                // Phone layout: Single-column vertical stack
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StaggeredEntrance(
                            controller: _animController,
                            startInterval: 0.00,
                            endInterval: 0.35,
                            child: _buildFacultyHeaderCard(),
                          ),
                          const SizedBox(height: 16),
                          StaggeredEntrance(
                            controller: _animController,
                            startInterval: 0.15,
                            endInterval: 0.45,
                            child: _buildGpsCard(),
                          ),
                          const SizedBox(height: 16),

                          // Dynamic QR when active
                          if (_viewModel.isSessionActive && _viewModel.currentLectureId != null) ...[
                            StaggeredEntrance(
                              controller: _animController,
                              startInterval: 0.25,
                              endInterval: 0.55,
                              child: _buildDynamicQrCard(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Setup Form
                          StaggeredEntrance(
                            controller: _animController,
                            startInterval: 0.30,
                            endInterval: 0.60,
                            child: _buildSetupFormCard(),
                          ),
                          const SizedBox(height: 16),

                          // Clock Picker
                          StaggeredEntrance(
                            controller: _animController,
                            startInterval: 0.45,
                            endInterval: 0.75,
                            child: _buildClockCard(),
                          ),
                          const SizedBox(height: 20),

                          // Actions
                          StaggeredEntrance(
                            controller: _animController,
                            startInterval: 0.60,
                            endInterval: 0.88,
                            child: _buildActions(),
                          ),
                          const SizedBox(height: 24),
                        ],
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
}
