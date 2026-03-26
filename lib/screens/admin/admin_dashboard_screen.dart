import 'package:flutter/material.dart';
import '../../models/waste_report.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'admin_report_list_screen.dart';
import 'admin_report_detail_screen.dart';
import '../user/map_page.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final reports = snapshot.data ?? [];

          final total = reports.length;
          final pending = reports.where((r) => r.status == 'Pending').length;
          final assigned = reports.where((r) => r.status == 'Assigned').length;
          final inProgress =
              reports.where((r) => r.status == 'In Progress').length;
          final resolved = reports.where((r) => r.status == 'Resolved').length;
          final rejected = reports.where((r) => r.status == 'Rejected').length;

          final recentReports = reports.take(5).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage waste reports and assignments',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _card('Total', total, Icons.assignment, Colors.blue),
                    _card('Pending', pending, Icons.hourglass_top, Colors.amber),
                    _card('Assigned', assigned, Icons.person, Colors.deepPurple),
                    _card('In Progress', inProgress, Icons.sync, Colors.orange),
                    _card('Resolved', resolved, Icons.check, Colors.green),
                    _card('Rejected', rejected, Icons.close, Colors.red),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _actionTile(
                  context,
                  icon: Icons.assignment,
                  color: Colors.orange,
                  title: 'Manage Reports',
                  subtitle: 'View and assign reports',
                  page: const AdminReportListScreen(),
                ),

                _actionTile(
                  context,
                  icon: Icons.map,
                  color: Colors.green,
                  title: 'View Waste Map',
                  subtitle: 'See report locations on map',
                  page: const MapPage(),
                ),

                if (pending > 0)
                  _actionTile(
                    context,
                    icon: Icons.warning,
                    color: Colors.red,
                    title: 'Pending Reports ($pending)',
                    subtitle: 'Requires immediate attention',
                    page: const AdminReportListScreen(),
                  ),

                const SizedBox(height: 28),

                const Text(
                  'Recent Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (recentReports.isEmpty)
                  const Center(
                    child: Text('No recent reports'),
                  )
                else
                  ...recentReports.map((report) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.report, color: Colors.green),
                        ),
                        title: Text(
                          report.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(report.location),
                        trailing: Text(
                          report.status,
                          style: TextStyle(
                            color: _statusColor(report.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminReportDetailScreen(report: report),
                            ),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String title, int value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}