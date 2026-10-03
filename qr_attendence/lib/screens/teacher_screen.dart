import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/academic_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
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
  final _academicService = AcademicService();
  final _locationService = LocationService();
  final _authService = AuthService();

  late AnimationController _animController;

  // Lecture Configuration
  String _department = AcademicService.departments.first;
  String? _course;
  String? _batch;
  String? _semester;
  String? _subject;
  final TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  final int _selectedDurationMinutes = 60;
  String _formattedTimeSlot = '09:00 AM - 10:00 AM (60 mins)';

  // Active Session State
  bool _isSessionActive = false;
  String? _currentLectureId;
  int _attendeeCount = 0;
  LocationData? _teacherLocation;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _department = widget.userData['department'] ?? AcademicService.departments.first;
    _initAcademicOptions();
    _acquireTeacherLocation();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _initAcademicOptions() {
    final courses = _academicService.getCoursesForDepartment(_department);
    if (courses.isNotEmpty) {
      _course = courses.first;
      _updateBatchesAndSubjects();
    }
  }

  void _updateBatchesAndSubjects() {
    if (_course != null) {
      final batches = _academicService.generateBatches(_course!);
      final semesters = _academicService.generateSemesters(_course!);
      final subjects = _academicService.getSubjects(
        department: _department,
        selectedCourse: _course!,
      );

      setState(() {
        _batch = batches.isNotEmpty ? batches.first : null;
        _semester = semesters.isNotEmpty ? semesters.first : null;
        _subject = subjects.isNotEmpty ? subjects.first : null;
      });
    }
  }

  Future<void> _acquireTeacherLocation() async {
    setState(() => _isFetchingLocation = true);
    final loc = await _locationService.getCurrentLocation(forceRefresh: true);
    if (mounted) {
      setState(() {
        _teacherLocation = loc;
        _isFetchingLocation = false;
      });
    }
  }

  void _onTimeSlotChanged(String formatted) {
    setState(() {
      _formattedTimeSlot = formatted;
    });
  }

  Future<void> _startLectureSession() async {
    if (_subject == null || _course == null || _batch == null || _semester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please configure all lecture parameters first.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Refresh location
    if (_teacherLocation == null) {
      await _acquireTeacherLocation();
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lectureId = 'LEC_${widget.userId.substring(0, 4)}_${now.millisecondsSinceEpoch}';

    final lectureDoc = {
      'lectureId': lectureId,
      'classId': '$_course-$_batch-$_semester',
      'teacherId': widget.userId,
      'teacherName': widget.userName,
      'teacherEmail': widget.userEmail,
      'department': _department,
      'course': _course,
      'batch': _batch,
      'semester': _semester,
      'subject': _subject,
      'timeSlot': _formattedTimeSlot,
      'date': dateStr,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
      if (_teacherLocation != null) 'location': _teacherLocation!.toMap(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('lectures')
          .doc(lectureId)
          .set(lectureDoc);

      setState(() {
        _isSessionActive = true;
        _currentLectureId = lectureId;
        _attendeeCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start session: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _endLectureSession() async {
    if (_currentLectureId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Lecture Session?'),
        content: Text(
          'Total attendance logged: $_attendeeCount students.\nAre you sure you want to finish this lecture?',
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
      try {
        await FirebaseFirestore.instance
            .collection('lectures')
            .doc(_currentLectureId)
            .update({
          'status': 'completed',
          'endedAt': FieldValue.serverTimestamp(),
          'totalAttendance': _attendeeCount,
        });

        setState(() {
          _isSessionActive = false;
          _currentLectureId = null;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lecture ended successfully. Recorded $_attendeeCount attendees.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end lecture: $e'),
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

  @override
  Widget build(BuildContext context) {
    final courses = _academicService.getCoursesForDepartment(_department);
    final batches = _course != null ? _academicService.generateBatches(_course!) : <String>[];
    final semesters = _course != null ? _academicService.generateSemesters(_course!) : <String>[];
    final subjects = _course != null
        ? _academicService.getSubjects(department: _department, selectedCourse: _course!)
        : <String>[];

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Faculty Header Card (Staggered 0.0 - 0.35)
              StaggeredEntrance(
                controller: _animController,
                startInterval: 0.00,
                endInterval: 0.35,
                child: PlannerCard(
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
                              _department,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSessionActive)
                        const StatusPill(
                          label: 'LIVE',
                          color: AppColors.success,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GPS Geofence Status Card (Staggered 0.15 - 0.45)
              StaggeredEntrance(
                controller: _animController,
                startInterval: 0.15,
                endInterval: 0.45,
                child: PlannerCard(
                  padding: const EdgeInsets.all(14),
                  shadows: AppColors.elevationSubtle,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _teacherLocation != null ? AppColors.successLight : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _teacherLocation != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
                          color: _teacherLocation != null ? AppColors.successDark : AppColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _teacherLocation != null ? 'Classroom Geofence Active' : 'Acquiring Classroom Location...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _teacherLocation != null ? _teacherLocation!.address : 'Students must be within 100m to mark',
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
                      if (_isFetchingLocation)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                          onPressed: _acquireTeacherLocation,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic QR & Live Attendance Monitor (when active)
              if (_isSessionActive && _currentLectureId != null) ...[
                StaggeredEntrance(
                  controller: _animController,
                  startInterval: 0.25,
                  endInterval: 0.55,
                  child: PlannerCard(
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

                        // QR Code with smooth countdown
                        DynamicLectureQRWidget(
                          lectureId: _currentLectureId!,
                          classId: '$_course-$_batch-$_semester',
                          subject: _subject!,
                          date: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                          timeSlot: _formattedTimeSlot,
                          teacherId: widget.userId,
                          teacherName: widget.userName,
                          department: _department,
                          locationData: _teacherLocation,
                          refreshIntervalSeconds: 20,
                        ),
                        const SizedBox(height: 18),

                        // Live Attendee Counter
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('attendance')
                              .where('lectureId', isEqualTo: _currentLectureId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            _attendeeCount = count;

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
                          onPressed: _endLectureSession,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lecture Configuration Form (Only editable when no session is running) (Staggered 0.30 - 0.60)
              StaggeredEntrance(
                controller: _animController,
                startInterval: 0.30,
                endInterval: 0.60,
                child: PlannerCard(
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
                        onChanged: _isSessionActive
                            ? null
                            : (newDept) {
                                if (newDept != null) {
                                  setState(() {
                                    _department = newDept;
                                    _initAcademicOptions();
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 14),

                      // Course / Program Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: courses.contains(_course) ? _course : (courses.isNotEmpty ? courses.first : null),
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
                        onChanged: _isSessionActive
                            ? null
                            : (newCourse) {
                                if (newCourse != null) {
                                  setState(() {
                                    _course = newCourse;
                                    _updateBatchesAndSubjects();
                                  });
                                }
                              },
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
                              onChanged: _isSessionActive ? null : (b) => setState(() => _batch = b),
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
                              onChanged: _isSessionActive ? null : (s) => setState(() => _semester = s),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Subject Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: subjects.contains(_subject) ? _subject : (subjects.isNotEmpty ? subjects.first : null),
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
                        onChanged: _isSessionActive ? null : (sub) => setState(() => _subject = sub),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Clock Time Picker Card (Staggered 0.45 - 0.75)
              StaggeredEntrance(
                controller: _animController,
                startInterval: 0.45,
                endInterval: 0.75,
                child: ClockTimePickerCard(
                  initialStartTime: _selectedStartTime,
                  initialDurationMinutes: _selectedDurationMinutes,
                  onTimeSlotChanged: _onTimeSlotChanged,
                ),
              ),
              const SizedBox(height: 20),

              // Start Lecture Button & Actions (Staggered 0.60 - 0.88)
              StaggeredEntrance(
                controller: _animController,
                startInterval: 0.60,
                endInterval: 0.88,
                child: Column(
                  children: [
                    if (!_isSessionActive)
                      PlannerButton(
                        text: 'Launch Lecture & Generate QR',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _startLectureSession,
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
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}
