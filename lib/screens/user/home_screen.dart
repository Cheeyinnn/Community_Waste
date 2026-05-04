import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/waste_report.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'notification_page.dart';

class HomeScreen extends StatefulWidget {
  final Function(String? statusFilter) onNavigateToReports;
  final VoidCallback onCreateReport;

  const HomeScreen({
    super.key,
    required this.onNavigateToReports,
    required this.onCreateReport,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final AuthService authService = AuthService();
  final FirestoreService firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  Future<DateTime?> _getLastNotificationReadTime(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('last_notification_read_$userId');

    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _openNotificationPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    final String userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? 'User';

    final String userId = user?.uid ?? '';
    final String photoUrl = user?.photoURL ?? '';

    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('User not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFF8F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              right: -60,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.10),
                ),
              ),
            ),
            SingleChildScrollView(
              key: const PageStorageKey<String>('user_home_scroll'),
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(
                    userId: userId,
                    onLogout: () async {
                      await authService.logout();
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildHeroCard(
                    userName,
                    photoUrl: photoUrl,
                    onTap: widget.onCreateReport,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLiveStatCard(
                          stream: firestoreService.getUserReportCount(userId),
                          icon: Icons.assignment_outlined,
                          iconBg: const Color(0xFFEAF3FF),
                          iconColor: Colors.blue,
                          title: 'My Reports',
                          onTap: () {
                            widget.onNavigateToReports(null);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLiveStatCard(
                          stream: firestoreService.getUserReportCountByStatus(
                            userId,
                            'Pending',
                          ),
                          icon: Icons.pending_actions_outlined,
                          iconBg: const Color(0xFFFFF3E3),
                          iconColor: Colors.orange,
                          title: 'Pending',
                          onTap: () {
                            widget.onNavigateToReports('Pending');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLiveStatCard(
                          stream: firestoreService.getUserReportCountByStatus(
                            userId,
                            'Resolved',
                          ),
                          icon: Icons.check_circle_outline,
                          iconBg: const Color(0xFFE8F8EE),
                          iconColor: Colors.green,
                          title: 'Resolved',
                          onTap: () {
                            widget.onNavigateToReports('Resolved');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLiveStatCard(
                          stream: firestoreService.getUserReportCountByStatus(
                            userId,
                            'Assigned',
                          ),
                          icon: Icons.local_shipping_outlined,
                          iconBg: const Color(0xFFFFEBEB),
                          iconColor: Colors.deepPurple,
                          title: 'Assigned',
                          onTap: () {
                            widget.onNavigateToReports('Assigned');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _ContributionSection(
                    userId: userId,
                    firestoreService: firestoreService,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Latest Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<List<WasteReport>>(
                    stream: firestoreService.getRecentUserReports(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildEmptyCard(
                          text: 'Failed to load latest reports.',
                        );
                      }

                      final reports = snapshot.data ?? [];

                      if (reports.isEmpty) {
                        return _buildEmptyCard(
                          text: 'No reports submitted yet.',
                        );
                      }

                      return Column(
                        children: reports.map((report) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildReportTile(report),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required String userId,
    required VoidCallback onLogout,
  }) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icon/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.eco_rounded,
                color: Color(0xFF35C76F),
                size: 28,
              );
            },
          ),
        ),
        const Spacer(),
        StreamBuilder<List<WasteReport>>(
          stream: firestoreService.getUserReports(userId),
          builder: (context, snapshot) {
            final reports = snapshot.data ?? [];

            return FutureBuilder<DateTime?>(
              future: _getLastNotificationReadTime(userId),
              builder: (context, readSnapshot) {
                final lastRead = readSnapshot.data;

                final unreadCount = reports.where((report) {
                  if (report.status == 'Pending') return false;

                  final updatedAt = report.updatedAt.toDate();

                  if (lastRead == null) {
                    return true;
                  }

                  return updatedAt.isAfter(lastRead);
                }).length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _openNotificationPage,
                        icon: const Icon(Icons.notifications_none_rounded),
                        color: Colors.black87,
                        tooltip: 'Notifications',
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(width: 10),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            color: Colors.black87,
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    String userName, {
    required String photoUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF43B9FF),
            Color(0xFF35C76F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 34,
                        );
                      },
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello,',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Help keep your community clean by reporting waste issues and tracking cleanup progress.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Report waste now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatCard({
    required Stream<int> stream,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    VoidCallback? onTap,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;

        return _buildStatCard(
          icon: icon,
          iconBg: iconBg,
          iconColor: iconColor,
          title: title,
          value: value.toString(),
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTile(WasteReport report) {
    final Color statusColor = _getStatusColor(report.status);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: statusColor.withOpacity(0.12),
            child: Icon(
              Icons.description_outlined,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              report.status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard({required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
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
}

class _ContributionSection extends StatefulWidget {
  final String userId;
  final FirestoreService firestoreService;

  const _ContributionSection({
    required this.userId,
    required this.firestoreService,
  });

  @override
  State<_ContributionSection> createState() => _ContributionSectionState();
}

class _ContributionSectionState extends State<_ContributionSection>
    with AutomaticKeepAliveClientMixin {
  String _selectedContributionRange = 'Overall';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Contribution',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedContributionRange,
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
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedContributionRange = value;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<WasteReport>>(
          stream: widget.firestoreService.getUserReports(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildEmptyCard(
                text: 'Failed to load contribution data.',
              );
            }

            final reports = snapshot.data ?? [];
            final now = DateTime.now();
            final last7Days = now.subtract(const Duration(days: 7));

            final List<WasteReport> filteredReports =
                _selectedContributionRange == 'Last 7 Days'
                    ? reports.where((r) {
                        final created = r.createdAt.toDate();
                        return created.isAfter(last7Days);
                      }).toList()
                    : reports;

            final int submitted = filteredReports.length;
            final int resolved =
                filteredReports.where((r) => r.status == 'Resolved').length;

            final double rate =
                submitted == 0 ? 0.0 : (resolved / submitted).clamp(0.0, 1.0);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildCircularContribution(rate),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniContributionStat(
                                    title: _selectedContributionRange ==
                                            'Last 7 Days'
                                        ? 'Resolved (7d)'
                                        : 'Resolved',
                                    value: resolved.toString(),
                                    color: Colors.green,
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMiniContributionStat(
                                    title: _selectedContributionRange ==
                                            'Last 7 Days'
                                        ? 'Submitted (7d)'
                                        : 'Submitted',
                                    value: submitted.toString(),
                                    color: Colors.blue,
                                    icon: Icons.assignment_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF35C76F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedContributionRange == 'Last 7 Days'
                        ? '${(rate * 100).round()}% resolved in the last 7 days.'
                        : '${(rate * 100).round()}% of your reports have been successfully resolved.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircularContribution(double rate) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF35C76F),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(rate * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Completion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniContributionStat({
  required String title,
  required String value,
  required Color color,
  required IconData icon,
}) {
  return Container(
    height: 145,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 12),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.15,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildEmptyCard({required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
        ),
      ),
    );
  }
}