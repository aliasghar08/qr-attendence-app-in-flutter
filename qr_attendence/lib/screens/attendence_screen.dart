import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_components.dart';

class AttendenceScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole;

  const AttendenceScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<AttendenceScreen> createState() => _AttendenceScreenState();
}

class _AttendenceScreenState extends State<AttendenceScreen>
    with TickerProviderStateMixin {
  final _attendanceService = AttendanceService();
  late TabController _tabController;
  late AnimationController _animController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 75.0) return AppColors.successDark;
    if (percentage >= 50.0) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Attendance'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Subject Analytics', icon: Icon(Icons.pie_chart_rounded, size: 20)),
            Tab(text: 'Timeline Logs', icon: Icon(Icons.timeline_rounded, size: 20)),
          ],
        ),
      ),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: _attendanceService.streamStudentAttendance(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];
          final subjectStats = _attendanceService.calculateSubjectStats(records);
          final totalLectures = records.length;
          final presentCount = records.where((r) => r.status.toLowerCase() == 'present').length;
          final overallRate = totalLectures > 0 ? (presentCount / totalLectures) * 100 : 0.0;

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance records found yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scan a lecture QR code in class to begin tracking.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Analytics & Subject Progress
              SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Banner Card (Staggered 0.0 - 0.35)
                    StaggeredEntrance(
                      controller: _animController,
                      startInterval: 0.00,
                      endInterval: 0.35,
                      child: PlannerCard(
                        padding: const EdgeInsets.all(20),
                        gradient: AppColors.darkHeroGradient,
                        shadows: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 74,
                                  height: 74,
                                  child: CircularProgressIndicator(
                                    value: overallRate / 100,
                                    strokeWidth: 8,
                                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      overallRate >= 75 ? AppColors.success : AppColors.warning,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${overallRate.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Overall Attendance Rate',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$presentCount of $totalLectures sessions attended',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  StatusPill(
                                    label: overallRate >= 75 ? 'ELIGIBLE FOR EXAMS' : 'ATTENDANCE SHORTAGE',
                                    color: overallRate >= 75 ? AppColors.success : AppColors.error,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Header (Staggered 0.15 - 0.40)
                    StaggeredEntrance(
                      controller: _animController,
                      startInterval: 0.15,
                      endInterval: 0.40,
                      child: const SectionHeader(
                        title: 'Subject Breakdown',
                        subtitle: 'Attendance threshold required: 75%',
                        icon: Icons.auto_graph_rounded,
                      ),
                    ),

                    ...subjectStats.values.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stat = entry.value;
                      final percentage = stat.percentage;
                      final color = _getPercentageColor(percentage);
                      final start = (0.20 + (idx * 0.08)).clamp(0.0, 0.75);
                      final end = (0.45 + (idx * 0.08)).clamp(0.2, 0.95);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaggeredEntrance(
                          controller: _animController,
                          startInterval: start,
                          endInterval: end,
                          child: PlannerCard(
                            padding: const EdgeInsets.all(16),
                            shadows: AppColors.elevationSubtle,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.book_rounded, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stat.subject,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${stat.present} present • ${stat.absent} absent',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    minHeight: 8,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // TAB 2: Chronological Timeline
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: StaggeredEntrance(
                      controller: _animController,
                      startInterval: 0.00,
                      endInterval: 0.30,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Filter timeline by subject or date...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        var filtered = records;
                        if (_searchQuery.isNotEmpty) {
                          filtered = records.where((r) {
                            return r.subject.toLowerCase().contains(_searchQuery) ||
                                r.date.toLowerCase().contains(_searchQuery) ||
                                r.teacherName.toLowerCase().contains(_searchQuery);
                          }).toList();
                        }

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No matching logs found.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final start = (0.10 + (index * 0.05)).clamp(0.0, 0.70);
                            final end = (0.35 + (index * 0.05)).clamp(0.2, 0.95);

                            return StaggeredEntrance(
                              controller: _animController,
                              startInterval: start,
                              endInterval: end,
                              child: PlannerCard(
                                padding: const EdgeInsets.all(16),
                                shadows: AppColors.elevationSubtle,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: AppColors.successDark,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.subject,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (item.teacherName.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Instructor: ${item.teacherName}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.event_note_rounded,
                                                  size: 13, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${item.date} • ${item.timeSlot}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (item.distanceMeters != null)
                                      StatusPill(
                                        label: '${item.distanceMeters!.toStringAsFixed(0)}m',
                                        color: AppColors.secondaryDark,
                                        showDot: false,
                                        icon: Icons.near_me_rounded,
                                      )
                                    else
                                      const StatusPill(
                                        label: 'Verified',
                                        color: AppColors.successDark,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}