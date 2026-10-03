import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../viewmodels/history_viewmodel.dart';
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
  late final HistoryViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _viewModel = HistoryViewModel();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showStudentAttendanceSheet(
    BuildContext context,
    String lectureId,
    String subject,
    String date,
    String timeSlot,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
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
                                    radius: 20,
                                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                    child: Text(
                                      studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: const TextStyle(
                                            fontSize: 14,
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
                                        Text(
                                          '${distance.round()}m away',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryDark,
                                          ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildLectureCard({
    required Map<String, dynamic> data,
    required String docId,
    required int index,
  }) {
    final lectureId = data['lectureId'] ?? docId;
    final subject = data['subject'] ?? 'Untitled Subject';
    final date = data['date'] ?? '';
    final timeSlot = data['timeSlot'] ?? '';
    final batch = data['batch'] ?? '';
    final semester = data['semester'] ?? '';
    final status = data['status'] ?? 'completed';
    final start = (0.20 + (index * 0.04)).clamp(0.0, 0.70);
    final end = (0.45 + (index * 0.04)).clamp(0.2, 0.95);

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
            Column(
              children: [
                const SizedBox(height: 10),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ],
        ),
      ),
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
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            return StreamBuilder<QuerySnapshot>(
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

                // Filter search query using HistoryViewModel
                if (_viewModel.searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _viewModel.matchesFilter(data);
                  }).toList();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 760;

                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isTablet ? 1100 : 680),
                        child: Column(
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
                                  onChanged: (val) => _viewModel.setSearchQuery(val),
                                  decoration: InputDecoration(
                                    hintText: 'Search by subject, batch, or date...',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    suffixIcon: _viewModel.searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded),
                                            onPressed: () {
                                              _searchController.clear();
                                              _viewModel.clearSearch();
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),

                            // Lecture Cards List or Grid
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
                                            _viewModel.searchQuery.isEmpty
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
                                  : isTablet
                                      ? GridView.builder(
                                          padding: const EdgeInsets.all(18),
                                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 520,
                                            mainAxisExtent: 155,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 14,
                                          ),
                                          itemCount: docs.length,
                                          itemBuilder: (context, index) {
                                            final data = docs[index].data() as Map<String, dynamic>;
                                            return _buildLectureCard(
                                              data: data,
                                              docId: docs[index].id,
                                              index: index,
                                            );
                                          },
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.all(18),
                                          itemCount: docs.length,
                                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                                          itemBuilder: (context, index) {
                                            final data = docs[index].data() as Map<String, dynamic>;
                                            return _buildLectureCard(
                                              data: data,
                                              docId: docs[index].id,
                                              index: index,
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}