import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../viewmodels/student_viewmodel.dart';
import '../widgets/custom_components.dart';
import '../widgets/delete_account_modal.dart';
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
    with TickerProviderStateMixin {
  late final StudentViewModel _viewModel;
  final _authService = AuthService();

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late AnimationController _animController;
  late AnimationController _entranceAnimController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _viewModel = StudentViewModel();
    _viewModel.fetchLocation();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entranceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _entranceAnimController.dispose();
    _scannerController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_viewModel.isProcessing) return;

    final result = await _viewModel.processBarcode(
      capture: capture,
      userId: widget.userId,
      userName: widget.userName,
      userData: widget.userData,
    );

    if (!mounted) return;

    if (result.isSuccess && result.attendanceDetails != null) {
      final details = result.attendanceDetails!;
      _showSuccessDialog(
        subject: details['subject'] ?? '',
        teacherName: details['teacherName'] ?? '',
        date: details['date'] ?? '',
        timeSlot: details['timeSlot'] ?? '',
      );
    } else if (!result.isSuccess &&
        result.errorMessage != null &&
        result.errorMessage != 'Already processing.') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.security_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(result.errorMessage!)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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

  Widget _buildProfileCard() {
    final rollNo = widget.userData['rollNo'] ?? 'N/A';
    final batch = widget.userData['batch'] ?? 'N/A';
    final semester = widget.userData['semester'] ?? '';

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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
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
    );
  }

  Widget _buildGeotagCard() {
    final location = _viewModel.currentLocation;
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
                  location != null ? 'GPS Ready for Attendance' : 'Locating Device...',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  location != null ? location.address : 'Acquiring high accuracy coordinates',
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
              onPressed: () => _viewModel.fetchLocation(force: true),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerCard({required double viewportHeight}) {
    final isTorchOn = _viewModel.isTorchOn;
    final isProcessing = _viewModel.isProcessing;

    return PlannerCard(
      padding: const EdgeInsets.all(16),
      shadows: AppColors.elevationMedium,
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
                      isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: isTorchOn ? AppColors.warning : AppColors.textSecondary,
                    ),
                    onPressed: () => _viewModel.toggleTorch(_scannerController),
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
              height: viewportHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcodeDetected,
                  ),

                  // Scanning Viewfinder Overlay
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),

                  // Animated Laser Line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      final topOffset = ((viewportHeight - 220) / 2) + (_scanLineAnimation.value * 220);
                      return Positioned(
                        top: topOffset.clamp(10.0, viewportHeight - 10.0),
                        child: Container(
                          width: 210,
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

                  if (isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Verifying Security & Logging Attendance...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
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
            'Tokens refresh every 20 seconds. Point camera at the live faculty screen.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
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
                  // Tablet dual-pane layout: Scanner on Left, Student Details & Telemetry on Right
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Pane: Scanner Viewport
                            Expanded(
                              flex: 6,
                              child: StaggeredEntrance(
                                controller: _entranceAnimController,
                                startInterval: 0.15,
                                endInterval: 0.60,
                                child: _buildScannerCard(viewportHeight: 400),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right Pane: Profile, Geofence Telemetry & Actions
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  StaggeredEntrance(
                                    controller: _entranceAnimController,
                                    startInterval: 0.00,
                                    endInterval: 0.35,
                                    child: _buildProfileCard(),
                                  ),
                                  const SizedBox(height: 16),
                                  StaggeredEntrance(
                                    controller: _entranceAnimController,
                                    startInterval: 0.10,
                                    endInterval: 0.40,
                                    child: _buildGeotagCard(),
                                  ),
                                  const SizedBox(height: 20),
                                  StaggeredEntrance(
                                    controller: _entranceAnimController,
                                    startInterval: 0.25,
                                    endInterval: 0.65,
                                    child: _buildActions(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Phone layout: Single column vertical stack
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StaggeredEntrance(
                            controller: _entranceAnimController,
                            startInterval: 0.00,
                            endInterval: 0.35,
                            child: _buildProfileCard(),
                          ),
                          const SizedBox(height: 16),
                          StaggeredEntrance(
                            controller: _entranceAnimController,
                            startInterval: 0.15,
                            endInterval: 0.45,
                            child: _buildGeotagCard(),
                          ),
                          const SizedBox(height: 16),
                          StaggeredEntrance(
                            controller: _entranceAnimController,
                            startInterval: 0.30,
                            endInterval: 0.65,
                            child: _buildScannerCard(viewportHeight: 300),
                          ),
                          const SizedBox(height: 16),
                          StaggeredEntrance(
                            controller: _entranceAnimController,
                            startInterval: 0.50,
                            endInterval: 0.85,
                            child: _buildActions(),
                          ),
                          const SizedBox(height: 20),
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