import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/collection_schedule_service.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/profile_page.dart';

enum ProgressFilter { today, week, month, all }

class CollectorDashboardScreen extends StatefulWidget {
  final Function(String filter) onNavigateToTasks;
  final VoidCallback onNavigateToCollectionRuns;

  const CollectorDashboardScreen({
    super.key,
    required this.onNavigateToTasks,
    required this.onNavigateToCollectionRuns,
  });

  @override
  State<CollectorDashboardScreen> createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  ProgressFilter _selectedFilter = ProgressFilter.today;
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  final CollectionScheduleService _scheduleService =
      CollectionScheduleService();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _filterLabel(ProgressFilter filter) {
    switch (filter) {
      case ProgressFilter.today:
        return 'Today';
      case ProgressFilter.week:
        return 'Week';
      case ProgressFilter.month:
        return 'Month';
      case ProgressFilter.all:
        return 'All';
    }
  }

  Future<bool?> _confirmLogout() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Log Out?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to log out of your collector account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirmed = await _confirmLogout();

    if (confirmed != true) {
      return;
    }

    await _authService.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _openAccountMenu(User currentUser) async {
    final displayName = currentUser.displayName?.trim().isNotEmpty == true
        ? currentUser.displayName!.trim()
        : (currentUser.email?.split('@').first ?? 'Collector');

    final email = currentUser.email?.trim() ?? '';
    final photoUrl = currentUser.photoURL ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.orange.withOpacity(0.12),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              color: Colors.orange.shade700,
                              size: 30,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Collector',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildAccountMenuTile(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.orange,
                title: 'My Profile',
                subtitle: 'View and edit your account information',
                onTap: () {
                  Navigator.pop(sheetContext);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildAccountMenuTile(
                icon: Icons.logout_rounded,
                iconColor: Colors.red,
                title: 'Log Out',
                subtitle: 'Sign out of your collector account',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TODAY'S COLLECTION RUN SUMMARY
  // ============================================================

  Future<_CollectionRunSummary> _loadTodayCollectionRunSummary(
    String collectorId,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(collectorId)
          .get();

      final rawZones =
          userDoc.data()?['assignedCollectionZoneIds'];

      if (rawZones is! Iterable) {
        return const _CollectionRunSummary(
          active: 0,
          completed: 0,
        );
      }

      final assignedZoneIds = rawZones
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();

      if (assignedZoneIds.isEmpty) {
        return const _CollectionRunSummary(
          active: 0,
          completed: 0,
        );
      }

      final areas =
          await _scheduleService.getAvailableAreas();

      final scheduleIds = areas
          .where(
            (area) =>
                assignedZoneIds.contains(area.zoneId),
          )
          .map((area) => area.scheduleId)
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();

      final scheduleResults = await Future.wait(
        scheduleIds.map(
          (scheduleId) =>
              _scheduleService.getScheduleById(
            scheduleId,
          ),
        ),
      );

      final schedulesById = {
        for (final schedule in scheduleResults)
          if (schedule != null)
            schedule.scheduleId: schedule,
      };

      final now = DateTime.now();
      final todayWeekday = now.weekday;

      final todayAreas = areas.where((area) {
        if (!assignedZoneIds.contains(area.zoneId)) {
          return false;
        }

        final schedule =
            schedulesById[area.scheduleId];

        if (schedule == null) {
          return false;
        }

        return schedule.collectsOnDay(todayWeekday);
      }).toList();

      if (todayAreas.isEmpty) {
        return const _CollectionRunSummary(
          active: 0,
          completed: 0,
        );
      }

      final todayKey =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final eventSnapshot =
          await FirebaseFirestore.instance
              .collection('collection_events')
              .where(
                'collectionDate',
                isEqualTo: todayKey,
              )
              .get();

      final completedAreaIds = <String>{};

      for (final doc in eventSnapshot.docs) {
        final data = doc.data();

        final eventCollectorId =
            data['collectorId']?.toString().trim() ?? '';

        final status =
            data['status']?.toString().trim().toLowerCase() ?? '';

        final areaId =
            data['areaId']?.toString().trim() ?? '';

        if (eventCollectorId == collectorId &&
            status == 'collected' &&
            areaId.isNotEmpty) {
          completedAreaIds.add(areaId);
        }
      }

      final completed = todayAreas.where((area) {
        return completedAreaIds.contains(area.areaId);
      }).length;

      final active =
          (todayAreas.length - completed).clamp(
        0,
        todayAreas.length,
      );

      return _CollectionRunSummary(
        active: active,
        completed: completed,
      );
    } catch (_) {
      return const _CollectionRunSummary(
        active: 0,
        completed: 0,
      );
    }
  }

  Widget _buildTodayWorkSection({
    required int assignedReportCount,
    required int inProgressReportCount,
    required int completionSubmittedCount,
    required int resolvedReportCount,
    required String collectorId,
  }) {
    final activeReportCount =
        assignedReportCount + inProgressReportCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Work',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Check both Report Tasks and Collection Runs each day.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDailyWorkCard(
                title: 'Report Tasks',
                icon: Icons.assignment_outlined,
                color: Colors.deepPurple,
                mainValue: '$activeReportCount active',
                detail:
                    '$completionSubmittedCount waiting review • '
                    '$resolvedReportCount resolved',
                onTap: () =>
                    widget.onNavigateToTasks('All'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<_CollectionRunSummary>(
                future: _loadTodayCollectionRunSummary(
                  collectorId,
                ),
                builder: (context, snapshot) {
                  final summary = snapshot.data;

                  final mainValue = summary == null
                      ? 'Loading...'
                      : '${summary.active} active';

                  final detail = summary == null
                      ? 'Checking today\'s runs'
                      : '${summary.completed} completed today';

                  return _buildDailyWorkCard(
                    title: 'Collection Runs',
                    icon: Icons.local_shipping_outlined,
                    color: Colors.orange,
                    mainValue: mainValue,
                    detail: detail,
                    onTap:
                        widget.onNavigateToCollectionRuns,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyWorkCard({
    required String title,
    required IconData icon,
    required Color color,
    required String mainValue,
    required String detail,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 150,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                mainValue,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<WasteReport> _getFilteredReports(List<WasteReport> reports) {
    final now = DateTime.now();

    // Completion Progress should represent when the collector's task
    // was most recently worked on, not when the resident originally
    // created the report. Collector actions such as starting a task,
    // submitting proof, resubmitting proof and final resolution all
    // update the report's updatedAt timestamp.
    bool isWithinPeriod(
      WasteReport report,
      DateTime start,
      DateTime end,
    ) {
      final activityDate = report.updatedAt.toDate();

      return !activityDate.isBefore(start) &&
          activityDate.isBefore(end);
    }

    switch (_selectedFilter) {
      case ProgressFilter.today:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        );
        final end = start.add(
          const Duration(days: 1),
        );

        return reports
            .where(
              (report) =>
                  isWithinPeriod(report, start, end),
            )
            .toList();

      case ProgressFilter.week:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(
          Duration(days: now.weekday - 1),
        );

        final end = start.add(
          const Duration(days: 7),
        );

        return reports
            .where(
              (report) =>
                  isWithinPeriod(report, start, end),
            )
            .toList();

      case ProgressFilter.month:
        final start = DateTime(
          now.year,
          now.month,
          1,
        );

        final end = now.month == 12
            ? DateTime(
                now.year + 1,
                1,
                1,
              )
            : DateTime(
                now.year,
                now.month + 1,
                1,
              );

        return reports
            .where(
              (report) =>
                  isWithinPeriod(report, start, end),
            )
            .toList();

      case ProgressFilter.all:
        return reports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Collector not logged in')),
      );
    }

    final displayName = currentUser.displayName?.isNotEmpty == true
        ? currentUser.displayName!
        : (currentUser.email?.split('@').first ?? 'Collector');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<WasteReport>>(
          stream: firestoreService.getCollectorReports(currentUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final reports = snapshot.data ?? [];

            final totalTasks = reports.length;
            final assignedCount = reports
                .where((r) => r.status == 'Assigned')
                .length;
            final inProgressCount = reports
                .where((r) => r.status == 'In Progress')
                .length;
            final completionSubmittedCount = reports
                .where((r) => r.status == 'Completion Submitted')
                .length;
            final resolvedCount = reports
                .where((r) => r.status == 'Resolved')
                .length;

            final filteredReports = _getFilteredReports(reports);
            final filteredTotal = filteredReports.length;
            final filteredResolved = filteredReports
                .where((r) => r.status == 'Resolved')
                .length;
            final filteredWaitingReview = filteredReports
                .where((r) => r.status == 'Completion Submitted')
                .length;
            final filteredActive = filteredReports
                .where(
                  (r) =>
                      r.status == 'Assigned' ||
                      r.status == 'In Progress',
                )
                .length;

            final completionRate = filteredTotal == 0
                ? 0.0
                : filteredResolved / filteredTotal;

            return SingleChildScrollView(
              key: const PageStorageKey<String>('collector_dashboard_scroll'),
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Overview",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => _openAccountMenu(currentUser),
                          tooltip: 'Account',
                          icon: currentUser.photoURL?.isNotEmpty == true
                              ? ClipOval(
                                  child: Image.network(
                                    currentUser.photoURL!,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person_outline_rounded,
                                        color: Colors.orange.shade700,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.orange.shade700,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade400,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $displayName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check your Report Tasks and Collection Runs '
                          'for today\'s assigned work.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildTodayWorkSection(
                    assignedReportCount: assignedCount,
                    inProgressReportCount: inProgressCount,
                    completionSubmittedCount: completionSubmittedCount,
                    resolvedReportCount: resolvedCount,
                    collectorId: currentUser.uid,
                  ),

                  const SizedBox(height: 24),

                  GridView.count(
                    crossAxisCount: 2,
                    padding: EdgeInsets.zero,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildModernStatCard(
                        title: 'Total Tasks',
                        value: totalTasks.toString(),
                        icon: Icons.assignment_outlined,
                        color: Colors.blueGrey,
                        onTap: () => widget.onNavigateToTasks('All'),
                      ),
                      _buildModernStatCard(
                        title: 'Assigned',
                        value: assignedCount.toString(),
                        icon: Icons.pending_actions,
                        color: Colors.deepPurple,
                        onTap: () => widget.onNavigateToTasks('Assigned'),
                      ),
                      _buildModernStatCard(
                        title: 'In Progress',
                        value: inProgressCount.toString(),
                        icon: Icons.autorenew_rounded,
                        color: Colors.blue,
                        onTap: () => widget.onNavigateToTasks('In Progress'),
                      ),
                      _buildModernStatCard(
                        title: 'Waiting Review',
                        value: completionSubmittedCount.toString(),
                        icon: Icons.fact_check_outlined,
                        color: Colors.amber.shade800,
                        onTap: () =>
                            widget.onNavigateToTasks('Completion Submitted'),
                      ),
                      _buildModernStatCard(
                        title: 'Resolved',
                        value: resolvedCount.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        onTap: () => widget.onNavigateToTasks('Resolved'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Completion Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ProgressFilter.values.map((filter) {
                            final isSelected = _selectedFilter == filter;

                            return ChoiceChip(
                              label: Text(_filterLabel(filter)),
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              showCheckmark: false,
                              selectedColor: Colors.orange.shade500,
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide.none,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_filterLabel(_selectedFilter)} Progress',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${(completionRate * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.orange.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: completionRate,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange.shade500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade100),
                        const SizedBox(height: 8),
                        _buildQuickInfoTile(
                          icon: Icons.check_circle_rounded,
                          title: '${_filterLabel(_selectedFilter)} Completed',
                          value:
                              '$filteredResolved of $filteredTotal completed',
                          color: Colors.green,
                        ),
                        _buildQuickInfoTile(
                          icon: Icons.autorenew_rounded,
                          title: '${_filterLabel(_selectedFilter)} Active',
                          value: '$filteredActive active report tasks',
                          color: Colors.blue,
                        ),
                        _buildQuickInfoTile(
                          icon: Icons.fact_check_outlined,
                          title:
                              '${_filterLabel(_selectedFilter)} Waiting Review',
                          value:
                              '$filteredWaitingReview waiting for Admin review',
                          color: Colors.amber.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionRunSummary {
  final int active;
  final int completed;

  const _CollectionRunSummary({
    required this.active,
    required this.completed,
  });
}
