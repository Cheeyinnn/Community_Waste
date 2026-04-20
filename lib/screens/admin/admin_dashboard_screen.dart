import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'admin_report_detail_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final Function(String filter) onNavigateToReports;
  final VoidCallback onNavigateToMap;

  const AdminDashboardScreen({
    super.key,
    required this.onNavigateToReports,
    required this.onNavigateToMap,
  });

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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _autoPriorityFromCount(int count) {
    if (count >= 3) return 'High';
    if (count == 2) return 'Medium';
    return 'Low';
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentReportItem(
    BuildContext context,
    WasteReport report,
    List<WasteReport> allReports,
  ) {
    final statusColor = _getStatusColor(report.status);
    final sameAreaCount =
        allReports.where((r) => r.area.trim() == report.area.trim()).length;
    final autoPriority = _autoPriorityFromCount(sameAreaCount);
    final priorityColor = _getPriorityColor(autoPriority);

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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    autoPriority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
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
      backgroundColor: const Color(0xFFF7F9FC),
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
              ),
              const SizedBox(height: 24),
              _SubmissionTrendSection(
                reports: allReports,
              ),
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
                color: Colors.orange,
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigateToReports('All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (allReports.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No reports available'),
                  ),
                )
              else
                ...allReports.take(3).map(
                      (report) =>
                          _buildRecentReportItem(context, report, allReports),
                    ),
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

  const _DashboardSummarySection({
    required this.reports,
    required this.onNavigateToReports,
  });

  @override
  State<_DashboardSummarySection> createState() =>
      _DashboardSummarySectionState();
}

class _DashboardSummarySectionState extends State<_DashboardSummarySection>
    with AutomaticKeepAliveClientMixin {
  String _selectedRange = 'Overall';

  @override
  bool get wantKeepAlive => true;

  List<WasteReport> _filterReportsByRange(List<WasteReport> reports) {
    final now = DateTime.now();

    if (_selectedRange == 'Last 7 Days') {
      final last7Days = now.subtract(const Duration(days: 7));
      return reports
          .where((r) => r.createdAt.toDate().isAfter(last7Days))
          .toList();
    }

    if (_selectedRange == 'This Month') {
      return reports.where((r) {
        final date = r.createdAt.toDate();
        return date.year == now.year && date.month == now.month;
      }).toList();
    }

    return reports;
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

  List<MapEntry<String, int>> _getTopAreas(List<WasteReport> reports) {
    final areaCounts = _getAreaCounts(reports).entries.toList();
    areaCounts.sort((a, b) => b.value.compareTo(a.value));
    return areaCounts.take(5).toList();
  }

  String _autoPriorityFromCount(int count) {
    if (count >= 3) return 'High';
    if (count == 2) return 'Medium';
    return 'Low';
  }

  int _countAutoHighPriorityAreas(List<WasteReport> reports) {
    final areaCounts = _getAreaCounts(reports);
    return areaCounts.values.where((count) => count >= 3).length;
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
        return Colors.grey;
    }
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

  Widget _buildPriorityInsightCard(int highPriorityAreas) {
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
            child: const Icon(
              Icons.priority_high_rounded,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              highPriorityAreas == 0
                  ? 'No hotspot area is marked as high priority right now'
                  : '$highPriorityAreas hotspot area(s) are automatically marked as high priority',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAreasCard(List<MapEntry<String, int>> topAreas) {
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
            'Top Areas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (topAreas.isEmpty)
            Text(
              'No area data available',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...topAreas.map((entry) {
              final priority = _autoPriorityFromCount(entry.value);
              final priorityColor = _getPriorityColor(priority);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                        horizontal: 10,
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
                  ],
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

    final reports = _filterReportsByRange(widget.reports);
    final total = reports.length;
    final pending = reports.where((r) => r.status == 'Pending').length;
    final inProgress = reports.where((r) => r.status == 'In Progress').length;
    final resolved = reports.where((r) => r.status == 'Resolved').length;
    final autoHighPriorityAreas = _countAutoHighPriorityAreas(reports);
    final topAreas = _getTopAreas(reports);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRange,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(
                    value: 'Overall',
                    child: Text('Overall'),
                  ),
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
        ),
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
        _buildPriorityInsightCard(autoHighPriorityAreas),
        const SizedBox(height: 20),
        _buildTopAreasCard(topAreas),
      ],
    );
  }
}

class _SubmissionTrendSection extends StatefulWidget {
  final List<WasteReport> reports;

  const _SubmissionTrendSection({
    required this.reports,
  });

  @override
  State<_SubmissionTrendSection> createState() => _SubmissionTrendSectionState();
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
      return reports
          .where((r) => r.createdAt.toDate().isAfter(last7Days))
          .toList();
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

    final Map<int, int> dayCounts = {
      0: 0,
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
    };

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
    final maxY = (chartData.values.isEmpty
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
                    DropdownMenuItem(
                      value: 'Overall',
                      child: Text('Overall'),
                    ),
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
                            'Sat'
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
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