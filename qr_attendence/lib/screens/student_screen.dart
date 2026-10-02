import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/attendance_service.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_components.dart';
import 'attendence_screen.dart';
import 'login_screen.dart';

class StudentScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final Map<String, dynamic> userData;

  const StudentScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userData,
  });

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with SingleTickerProviderStateMixin {
  final _locationService = LocationService();
  final _attendanceService = AttendanceService();
  final _securityService = SecurityService();
  final _authService = AuthService();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  LocationData? _currentLocation;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _fetchLocation();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _fetchLocation({bool force = false}) async {
    final loc = await _locationService.getCurrentLocation(forceRefresh: force);
    if (mounted) {
      setState(() {
        _currentLocation = loc;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final Map<String, dynamic> data = jsonDecode(rawValue);
      final lectureId = data['lectureId'] as String?;
      final classId = data['classId'] as String?;
      final subject = data['subject'] as String?;
      final date = data['date'] as String?;
      final timeSlot = data['timeSlot'] as String? ?? '';
      final teacherId = data['teacherId'] as String? ?? '';
      final teacherName = data['teacherName'] as String? ?? '';
      final department = data['department'] as String? ?? '';

      if (lectureId == null || subject == null || date == null) {
        throw Exception('Invalid QR code format. Not a valid lecture token.');
      }

      // 1. Anti-Screenshot & Cryptographic Token Signature Validation
      final tokenValidation = _securityService.validateQrToken(payload: data);
      if (!tokenValidation.isValid) {
        throw Exception(tokenValidation.errorMessage ?? 'Cryptographic verification failed.');
      }

      // 2. Check duplicate attendance
      final alreadyAttended = await _attendanceService.hasAttendedToday(
        studentId: widget.userId,
        subject: subject,
        date: date,
      );

      if (alreadyAttended) {
        throw Exception('You have already marked attendance for $subject today ($date).');
      }

      // Teacher location from QR payload
      LocationData? teacherLoc;
      if (data['location'] != null) {
        teacherLoc = LocationData.fromMap(data['location']);
      }

      // Ensure fresh student location
      LocationData? studentLoc = _currentLocation;
      studentLoc ??= await _locationService.getCurrentLocation(forceRefresh: true);

      // 3. Strict Geofence & Anti-Spoofing Proximity Validation
      if (teacherLoc != null && studentLoc != null) {
        final locValidation = _securityService.validateLocationProximity(
          teacherLocation: teacherLoc,
          studentLocation: studentLoc,
        );

        if (!locValidation.isValid) {
          throw Exception(locValidation.errorMessage ?? 'Geofence boundary check failed.');
        }
      }

      // 4. Mark Attendance with Security Metadata & Cryptographic Audit Hash
      await _attendanceService.markAttendance(
        lectureId: lectureId,
        classId: classId ?? '',
        studentId: widget.userId,
        studentName: widget.userName,
        studentRollNo: widget.userData['rollNo'] ?? 'N/A',
        studentBatch: widget.userData['batch'] ?? 'N/A',
        studentCourse: widget.userData['course'] ?? 'N/A',
        subject: subject,
        date: date,
        timeSlot: timeSlot,
        teacherId: teacherId,
        teacherName: teacherName,
        department: department,
        teacherLocation: teacherLoc,
        studentLocation: studentLoc,
        tokenAgeSeconds: tokenValidation.tokenAgeSeconds,
      );

      if (!mounted) return;

      _showSuccessDialog(
        subject: subject,
        teacherName: teacherName,
        date: date,
        timeSlot: timeSlot,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.security_rounded, color: Colors.white),
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
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog({
    required String subject,
    required String teacherName,
    required String date,
    required String timeSlot,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.successDark,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Attendance Verified!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subject,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Faculty: $teacherName\n$date • $timeSlot',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const StatusPill(
                label: 'CRYPTOGRAPHIC AUDIT PASSED',
                color: AppColors.successDark,
              ),
              const SizedBox(height: 20),
              PlannerButton(
                text: 'Done',
                icon: Icons.done_all_rounded,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from the Student Portal?'),
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
    final rollNo = widget.userData['rollNo'] ?? 'N/A';
    final batch = widget.userData['batch'] ?? 'N/A';
    final semester = widget.userData['semester'] ?? '';

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
            const Text('Student Scanner'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Attendance',
            icon: const Icon(Icons.analytics_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendenceScreen(
                    userId: widget.userId,
                    userName: widget.userName,
                    userRole: 'student',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student Profile Card
              PlannerCard(
                padding: const EdgeInsets.all(18),
                gradient: AppColors.primaryGradient,
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
                        Icons.school_rounded,
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
                            'Roll No: $rollNo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  batch,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (semester.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    semester,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Geotag Validation Card
              PlannerCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentLocation != null ? AppColors.successLight : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _currentLocation != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
                        color: _currentLocation != null ? AppColors.successDark : AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentLocation != null ? 'GPS Ready for Attendance' : 'Locating Device...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _currentLocation != null ? _currentLocation!.address : 'Acquiring high accuracy coordinates',
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
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                      onPressed: () => _fetchLocation(force: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Scanner Viewport Card
              PlannerCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.center_focus_strong_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Live QR Scanner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Torch toggle
                            IconButton(
                              icon: Icon(
                                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: _isTorchOn ? AppColors.warning : AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _scannerController.toggleTorch();
                                setState(() => _isTorchOn = !_isTorchOn);
                              },
                            ),
                            // Switch camera
                            IconButton(
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: AppColors.textSecondary),
                              onPressed: () => _scannerController.switchCamera(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Camera Viewport
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _handleBarcodeDetected,
                            ),

                            // Scanning Viewfinder Overlay
                            Container(
                              width: 210,
                              height: 210,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),

                            // Animated Laser Line
                            AnimatedBuilder(
                              animation: _scanLineAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: 45 + (_scanLineAnimation.value * 210),
                                  child: Container(
                                    width: 200,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Colors.transparent, AppColors.secondaryLight, Colors.transparent],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.secondary.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (_isProcessing)
                              Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Verifying Security & Logging...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Live dynamic tokens expire every 20 seconds. Screenshots are rejected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // View Attendance History Button
              PlannerButton(
                text: 'View My Attendance Stats',
                icon: Icons.insights_rounded,
                isOutlined: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendenceScreen(
                        userId: widget.userId,
                        userName: widget.userName,
                        userRole: 'student',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}