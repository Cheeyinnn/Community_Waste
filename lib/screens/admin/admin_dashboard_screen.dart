import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/perak_collection_data.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/profile_page.dart';
import 'admin_report_detail_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final Function(String filter) onNavigateToReports;
  final Function(String area) onNavigateToReportsByArea;
  final VoidCallback onNavigateToMap;

  const AdminDashboardScreen({
    super.key,
    required this.onNavigateToReports,
    required this.onNavigateToReportsByArea,
    required this.onNavigateToMap,
  });

  Future<bool?> _confirmLogout(BuildContext context) {
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
            'Are you sure you want to log out of your admin account?',
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

  Future<void> _logout(BuildContext context) async {
    final confirmed = await _confirmLogout(context);

    if (confirmed != true) {
      return;
    }

    await AuthService().logout();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _syncCollectionData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Sync Collection Areas?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'This will create or update the built-in Kampar and Ipoh '
            'collection-zone data. Existing reports, users and collector '
            'assignments will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Sync'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing Kampar and Ipoh collection areas...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await PerakCollectionData.sync();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collection areas synced successfully. Kampar and Ipoh are ready.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sync collection areas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAccountMenu(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final displayName = currentUser.displayName?.trim().isNotEmpty == true
        ? currentUser.displayName!.trim()
        : (currentUser.email?.split('@').first ?? 'Administrator');

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
                      backgroundColor: Colors.blue.withOpacity(0.12),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.blue,
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
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Administrator',
                              style: TextStyle(
                                color: Colors.blue,
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
                iconColor: Colors.blue,
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
                icon: Icons.sync_rounded,
                iconColor: Colors.blue,
                title: 'Sync Collection Areas',
                subtitle: 'Update built-in Kampar and Ipoh zone data',
                onTap: () {
                  Navigator.pop(sheetContext);

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      _syncCollectionData(context);
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              _buildAccountMenuTile(
                icon: Icons.logout_rounded,
                iconColor: Colors.red,
                title: 'Log Out',
                subtitle: 'Sign out of your admin account',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout(context);
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentReportItem(BuildContext context, WasteReport report) {
    final statusColor = _getStatusColor(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: report.imageUrl.isNotEmpty
              ? Image.network(
                  report.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image_outlined),
                    );
                  },
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.image_outlined),
                ),
        ),
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          _timeAgo(report.createdAt.toDate()),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminReportDetailScreen(report: report),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _openAccountMenu(context),
                tooltip: 'Account',
                icon: Builder(
                  builder: (context) {
                    final currentUser =
                        FirebaseAuth.instance.currentUser;
                    final photoUrl = currentUser?.photoURL ?? '';

                    if (photoUrl.isNotEmpty) {
                      return ClipOval(
                        child: Image.network(
                          photoUrl,
                          width: 27,
                          height: 27,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.blue,
                            );
                          },
                        ),
                      );
                    }

                    return const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.blue,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
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

          final allReports = snapshot.data ?? [];
          final recentReports = allReports.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView(
            key: const PageStorageKey('admin_dashboard_scroll'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Monitor community activity and analytics',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 18),
              _DashboardSummarySection(
                reports: allReports,
                onNavigateToReports: onNavigateToReports,
                onNavigateToReportsByArea: onNavigateToReportsByArea,
              ),
              const SizedBox(height: 24),
              _SubmissionTrendSection(reports: allReports),
              const SizedBox(height: 32),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionTile(
                icon: Icons.list_alt_rounded,
                color: Colors.blue,
                title: 'Manage Reports',
                subtitle: 'View, edit, assign, and monitor reports',
                onTap: () => onNavigateToReports('All'),
              ),
              _buildActionTile(
                icon: Icons.map_outlined,
                color: Colors.blue,
                title: 'Waste Map',
                subtitle: 'Real-time locations of waste reports',
                onTap: onNavigateToMap,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Reports',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => onNavigateToReports('All'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (recentReports.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No reports available'),
                  ),
                )
              else
                ...recentReports
                    .take(3)
                    .map((report) => _buildRecentReportItem(context, report)),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardSummarySection extends StatefulWidget {
  final List<WasteReport> reports;
  final Function(String filter) onNavigateToReports;
  final Function(String area) onNavigateToReportsByArea;

  const _DashboardSummarySection({
    required this.reports,
    required this.onNavigateToReports,
    required this.onNavigateToReportsByArea,
  });

  @override
  State<_DashboardSummarySection> createState() =>
      _DashboardSummarySectionState();
}

class _DashboardSummarySectionState extends State<_DashboardSummarySection>
    with AutomaticKeepAliveClientMixin {
  String _selectedRange = 'Overall';
  String _selectedHotspotPriority = 'All';

  final List<String> _hotspotPriorityFilters = ['All', 'High', 'Medium', 'Low'];

  @override
  bool get wantKeepAlive => true;

  List<WasteReport> _filterReportsByRange(List<WasteReport> reports) {
    final now = DateTime.now();

    if (_selectedRange == 'Last 7 Days') {
      final last7Days = now.subtract(const Duration(days: 7));

      return reports.where((r) {
        final createdAt = r.createdAt.toDate();
        return createdAt.isAfter(last7Days);
      }).toList();
    }

    if (_selectedRange == 'This Month') {
      return reports.where((r) {
        final date = r.createdAt.toDate();
        return date.year == now.year && date.month == now.month;
      }).toList();
    }

    return reports;
  }

  // ============================================================
  // HOTSPOT WINDOW
  // ============================================================
  // Hotspot detection always uses a rolling 7-day window.
  // It is intentionally independent from the dashboard Overview Filter.
  // This keeps hotspot priority consistent with the report-frequency logic.
  List<WasteReport> _getWeeklyHotspotReports(List<WasteReport> reports) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    return reports.where((report) {
      final createdAt = report.createdAt.toDate();
      return !createdAt.isBefore(cutoff);
    }).toList();
  }

  Map<String, int> _getAreaCounts(List<WasteReport> reports) {
    final Map<String, int> areaCounts = {};

    for (final report in reports) {
      final area = report.area.trim();

      if (area.isEmpty) continue;

      areaCounts[area] = (areaCounts[area] ?? 0) + 1;
    }

    return areaCounts;
  }

  String _autoPriorityFromCount(int count) {
    if (count >= 3) return 'High';
    if (count == 2) return 'Medium';
    return 'Low';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'High':
        return Icons.priority_high_rounded;
      case 'Medium':
        return Icons.warning_amber_rounded;
      case 'Low':
        return Icons.eco_rounded;
      default:
        return Icons.location_on_outlined;
    }
  }

  int _countHotspotAreasByPriority(List<WasteReport> reports, String priority) {
    final areaCounts = _getAreaCounts(reports);

    if (priority == 'All') {
      return areaCounts.length;
    }

    return areaCounts.values.where((count) {
      return _autoPriorityFromCount(count) == priority;
    }).length;
  }

  List<MapEntry<String, int>> _getFilteredHotspotAreas(
    List<WasteReport> reports,
  ) {
    final areaCounts = _getAreaCounts(reports).entries.toList();

    areaCounts.sort((a, b) => b.value.compareTo(a.value));

    if (_selectedHotspotPriority == 'All') {
      return areaCounts.take(5).toList();
    }

    return areaCounts
        .where((entry) {
          final priority = _autoPriorityFromCount(entry.value);
          return priority == _selectedHotspotPriority;
        })
        .take(5)
        .toList();
  }

  Widget _buildOverviewFilterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              color: Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Filter dashboard data by time range',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRange,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.blue,
                ),
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w700,
                ),
                dropdownColor: Colors.white,
                focusColor: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: 'Overall', child: Text('Overall')),
                  DropdownMenuItem(
                    value: 'Last 7 Days',
                    child: Text('Last 7 Days'),
                  ),
                  DropdownMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRange = value;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotspotSummaryCard(List<WasteReport> reports) {
    final highCount = _countHotspotAreasByPriority(reports, 'High');
    final mediumCount = _countHotspotAreasByPriority(reports, 'Medium');
    final lowCount = _countHotspotAreasByPriority(reports, 'Low');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.red),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Hotspot Summary (Last 7 Days): $highCount High, $mediumCount Medium, $lowCount Low area(s)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotPriorityFilter() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _hotspotPriorityFilters.length,
        itemBuilder: (context, index) {
          final filter = _hotspotPriorityFilters[index];
          final isSelected = _selectedHotspotPriority == filter;
          final color = filter == 'All'
              ? Colors.blueGrey
              : _getPriorityColor(filter);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedHotspotPriority = filter;
                });
              },
              selectedColor: color,
              backgroundColor: Colors.grey.shade50,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : color.withOpacity(0.4),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHotspotAreasCard(List<MapEntry<String, int>> hotspotAreas) {
    return Container(
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
          const Text(
            'Hotspot Areas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap an area to view matching reports. Hotspot priority is calculated from reports submitted in the last 7 days.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _buildHotspotPriorityFilter(),
          const SizedBox(height: 16),
          if (hotspotAreas.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _selectedHotspotPriority == 'All'
                    ? 'No hotspot area data available.'
                    : 'No $_selectedHotspotPriority hotspot areas found.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...hotspotAreas.map((entry) {
              final priority = _autoPriorityFromCount(entry.value);
              final priorityColor = _getPriorityColor(priority);
              final priorityIcon = _getPriorityIcon(priority);

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  widget.onNavigateToReportsByArea(entry.key);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: priorityColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          priorityIcon,
                          color: priorityColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.value} report(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          priority,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: priorityColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Overview cards follow the selected Overview Filter.
    final reports = _filterReportsByRange(widget.reports);

    // Hotspot data always follows a rolling 7-day window, regardless of
    // whether the Overview Filter is set to Overall, Last 7 Days, or Month.
    final weeklyHotspotReports = _getWeeklyHotspotReports(widget.reports);

    final total = reports.length;
    final pending = reports.where((r) => r.status == 'Pending').length;
    final inProgress = reports.where((r) => r.status == 'In Progress').length;
    final resolved = reports.where((r) => r.status == 'Resolved').length;

    final hotspotAreas = _getFilteredHotspotAreas(weeklyHotspotReports);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOverviewFilterCard(),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.35,
          children: [
            _buildStatCard(
              title: 'Total',
              value: total,
              icon: Icons.assessment_rounded,
              color: Colors.blue,
              onTap: () => widget.onNavigateToReports('All'),
            ),
            _buildStatCard(
              title: 'Pending',
              value: pending,
              icon: Icons.hourglass_empty_rounded,
              color: Colors.orange,
              onTap: () => widget.onNavigateToReports('Pending'),
            ),
            _buildStatCard(
              title: 'In Progress',
              value: inProgress,
              icon: Icons.autorenew_rounded,
              color: Colors.blue,
              onTap: () => widget.onNavigateToReports('In Progress'),
            ),
            _buildStatCard(
              title: 'Resolved',
              value: resolved,
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              onTap: () => widget.onNavigateToReports('Resolved'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildHotspotSummaryCard(weeklyHotspotReports),
        const SizedBox(height: 20),
        _buildHotspotAreasCard(hotspotAreas),
      ],
    );
  }
}

class _SubmissionTrendSection extends StatefulWidget {
  final List<WasteReport> reports;

  const _SubmissionTrendSection({required this.reports});

  @override
  State<_SubmissionTrendSection> createState() =>
      _SubmissionTrendSectionState();
}

class _SubmissionTrendSectionState extends State<_SubmissionTrendSection>
    with AutomaticKeepAliveClientMixin {
  String _selectedChartRange = 'Last 7 Days';

  @override
  bool get wantKeepAlive => true;

  List<WasteReport> _filterReportsByRange(List<WasteReport> reports) {
    final now = DateTime.now();

    if (_selectedChartRange == 'Last 7 Days') {
      final last7Days = now.subtract(const Duration(days: 7));
      return reports.where((r) {
        final createdAt = r.createdAt.toDate();
        return createdAt.isAfter(last7Days);
      }).toList();
    }

    if (_selectedChartRange == 'This Month') {
      return reports.where((r) {
        final date = r.createdAt.toDate();
        return date.year == now.year && date.month == now.month;
      }).toList();
    }

    return reports;
  }

  Map<int, int> _getChartData(List<WasteReport> reports) {
    if (_selectedChartRange == 'This Month') {
      final Map<int, int> weekCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var report in reports) {
        final date = report.createdAt.toDate();
        final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
        weekCounts[weekOfMonth] = (weekCounts[weekOfMonth] ?? 0) + 1;
      }

      return weekCounts;
    }

    final Map<int, int> dayCounts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    final now = DateTime.now();

    for (var report in reports) {
      final reportDate = report.createdAt.toDate();

      if (_selectedChartRange == 'Last 7 Days') {
        if (now.difference(reportDate).inDays < 7) {
          final day = reportDate.weekday % 7;
          dayCounts[day] = (dayCounts[day] ?? 0) + 1;
        }
      } else {
        final day = reportDate.weekday % 7;
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
    }

    return dayCounts;
  }

  Widget _buildTrendChart(List<WasteReport> reports) {
    final filteredReports = _filterReportsByRange(reports);
    final chartData = _getChartData(filteredReports);
    final maxY =
        (chartData.values.isEmpty
            ? 0
            : chartData.values.reduce((a, b) => a > b ? a : b)) +
        1;

    return Container(
      height: 285,
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
          Text(
            _selectedChartRange == 'This Month'
                ? 'Monthly Submission Trend'
                : _selectedChartRange == 'Overall'
                ? 'Overall Submission Trend'
                : 'Weekly Submission Trend',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedChartRange,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 'Overall', child: Text('Overall')),
                    DropdownMenuItem(
                      value: 'Last 7 Days',
                      child: Text('Last 7 Days'),
                    ),
                    DropdownMenuItem(
                      value: 'This Month',
                      child: Text('This Month'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedChartRange = value;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (_selectedChartRange == 'This Month') {
                          const weeks = ['W1', 'W2', 'W3', 'W4', 'W5'];
                          final index = value.toInt() - 1;

                          if (index >= 0 && index < weeks.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                weeks[index],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        } else {
                          const days = [
                            'Sun',
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                          ];

                          final index = value.toInt();

                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[index],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: chartData.entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        color: Colors.blue.shade400,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY.toDouble(),
                          color: Colors.grey.shade50,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return _buildTrendChart(widget.reports);
  }
}
