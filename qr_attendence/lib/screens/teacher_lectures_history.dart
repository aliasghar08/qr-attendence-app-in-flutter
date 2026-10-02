import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_components.dart';

class TeacherLecturesHistory extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherLecturesHistory({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherLecturesHistory> createState() => _TeacherLecturesHistoryState();
}

class _TeacherLecturesHistoryState extends State<TeacherLecturesHistory>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showStudentAttendanceSheet(BuildContext context, String lectureId, String subject, String date, String timeSlot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '$date • $timeSlot',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .where('lectureId', isEqualTo: lectureId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No student records logged for this session.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final studentName = data['studentName'] ?? 'Unknown Student';
                        final rollNo = data['studentRollNo'] ?? 'N/A';
                        final distance = data['distanceMeters'] as num?;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primarySurface,
                                child: Text(
                                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Roll No: $rollNo',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (distance != null)
                                    StatusPill(
                                      label: '${distance.toStringAsFixed(1)}m away',
                                      color: distance <= 80 ? AppColors.successDark : AppColors.warning,
                                      icon: Icons.place_rounded,
                                    )
                                  else
                                    const StatusPill(
                                      label: 'Present',
                                      color: AppColors.successDark,
                                    ),
                                  const SizedBox(height: 4),
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline_rounded, size: 11, color: AppColors.successDark),
                                      SizedBox(width: 2),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.successDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lecture Logs & History'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lectures')
              .where('teacherId', isEqualTo: widget.teacherId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var docs = snapshot.data?.docs ?? [];

            // Sort by createdAt descending
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTs = aData['createdAt'] as Timestamp?;
              final bTs = bData['createdAt'] as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

            // Filter search query
            if (_searchQuery.isNotEmpty) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final sub = (data['subject'] ?? '').toString().toLowerCase();
                final date = (data['date'] ?? '').toString().toLowerCase();
                final batch = (data['batch'] ?? '').toString().toLowerCase();
                final q = _searchQuery.toLowerCase();
                return sub.contains(q) || date.contains(q) || batch.contains(q);
              }).toList();
            }

            return Column(
              children: [
                // Metrics Summary Banner (Staggered 0.0 - 0.35)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: StaggeredEntrance(
                    controller: _animController,
                    startInterval: 0.00,
                    endInterval: 0.35,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatMetricCard(
                            title: 'Total Sessions',
                            value: '${snapshot.data?.docs.length ?? 0}',
                            icon: Icons.class_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatMetricCard(
                            title: 'Faculty',
                            value: widget.teacherName.split(' ').first,
                            icon: Icons.verified_user_rounded,
                            color: AppColors.secondaryDark,
                            subtitle: 'Verified',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar (Staggered 0.15 - 0.40)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: StaggeredEntrance(
                    controller: _animController,
                    startInterval: 0.15,
                    endInterval: 0.40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search by subject, batch, or date...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Lecture Cards List
                Expanded(
                  child: docs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No lectures recorded yet.'
                                    : 'No matching lectures found.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final lectureId = data['lectureId'] ?? docs[index].id;
                            final subject = data['subject'] ?? 'Untitled Subject';
                            final date = data['date'] ?? '';
                            final timeSlot = data['timeSlot'] ?? '';
                            final batch = data['batch'] ?? '';
                            final semester = data['semester'] ?? '';
                            final status = data['status'] ?? 'completed';
                            final start = (0.20 + (index * 0.05)).clamp(0.0, 0.70);
                            final end = (0.45 + (index * 0.05)).clamp(0.2, 0.95);

                            return StaggeredEntrance(
                              controller: _animController,
                              startInterval: start,
                              endInterval: end,
                              child: PlannerCard(
                                onTap: () => _showStudentAttendanceSheet(
                                  context,
                                  lectureId,
                                  subject,
                                  date,
                                  timeSlot,
                                ),
                                padding: const EdgeInsets.all(16),
                                shadows: AppColors.elevationSubtle,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySurface,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.menu_book_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subject,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$batch • $semester',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        StatusPill(
                                          label: status == 'active' ? 'ACTIVE' : 'SAVED',
                                          color: status == 'active'
                                              ? AppColors.successDark
                                              : AppColors.secondaryDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule_rounded,
                                            size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '$date  |  $timeSlot',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('attendance')
                                              .where('lectureId', isEqualTo: lectureId)
                                              .snapshots(),
                                          builder: (context, attSnap) {
                                            final count = attSnap.data?.docs.length ?? 0;
                                            return Row(
                                              children: [
                                                const Icon(Icons.people_outline_rounded,
                                                    size: 15, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$count Students',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}