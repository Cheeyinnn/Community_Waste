import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';

enum ProgressFilter { today, week, month, all }

class CollectorDashboardScreen extends StatefulWidget {
  final Function(String filter) onNavigateToTasks;

  const CollectorDashboardScreen({super.key, required this.onNavigateToTasks});

  @override
  State<CollectorDashboardScreen> createState() =>
      _CollectorDashboardScreenState();
}

class _CollectorDashboardScreenState extends State<CollectorDashboardScreen> {
  ProgressFilter _selectedFilter = ProgressFilter.today;
  final ScrollController _scrollController = ScrollController();

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

  List<WasteReport> _getFilteredReports(List<WasteReport> reports) {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case ProgressFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return reports.where((r) {
          final created = r.createdAt.toDate();
          return !created.isBefore(start) && created.isBefore(end);
        }).toList();

      case ProgressFilter.week:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return reports.where((r) {
          final created = r.createdAt.toDate();
          return !created.isBefore(start) && created.isBefore(end);
        }).toList();

      case ProgressFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final end = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return reports.where((r) {
          final created = r.createdAt.toDate();
          return !created.isBefore(start) && created.isBefore(end);
        }).toList();

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
      backgroundColor: const Color(0xFFF7F9FC),
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
            final resolvedCount = reports
                .where((r) => r.status == 'Resolved')
                .length;

            final pendingTasks = totalTasks - resolvedCount;

            final filteredReports = _getFilteredReports(reports);
            final filteredTotal = filteredReports.length;
            final filteredResolved = filteredReports
                .where((r) => r.status == 'Resolved')
                .length;
            final filteredPending = filteredTotal - filteredResolved;

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
                      CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(
                          Icons.person,
                          color: Colors.orange.shade700,
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
                          pendingTasks == 0
                              ? 'You have no active task right now. Great work keeping the community clean!'
                              : 'You have $pendingTasks active task(s) to complete. Let’s keep the community clean!',
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
                          icon: Icons.hourglass_top_rounded,
                          title: '${_filterLabel(_selectedFilter)} Pending',
                          value: '$filteredPending tasks remaining',
                          color: Colors.orange,
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
