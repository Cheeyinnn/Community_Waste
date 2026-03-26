import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';

class CollectorDashboardScreen extends StatelessWidget {
  const CollectorDashboardScreen({super.key});

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(value),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collector Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getCollectorReports(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          final totalTasks = reports.length;
          final assignedCount =
              reports.where((r) => r.status == 'Assigned').length;
          final inProgressCount =
              reports.where((r) => r.status == 'In Progress').length;
          final resolvedCount =
              reports.where((r) => r.status == 'Resolved').length;

          final completionRate = totalTasks == 0
              ? 0.0
              : resolvedCount / totalTasks;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade700,
                        Colors.teal.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentUser.email ?? 'Collector',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Track your assigned reports and monitor progress here.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSummaryCard(
                      title: 'Total Tasks',
                      value: totalTasks.toString(),
                      icon: Icons.assignment,
                      color: Colors.blue,
                    ),
                    _buildSummaryCard(
                      title: 'Assigned',
                      value: assignedCount.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.deepPurple,
                    ),
                    _buildSummaryCard(
                      title: 'In Progress',
                      value: inProgressCount.toString(),
                      icon: Icons.autorenew,
                      color: Colors.orange,
                    ),
                    _buildSummaryCard(
                      title: 'Resolved',
                      value: resolvedCount.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Completion Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(completionRate * 100).toStringAsFixed(0)}% completed',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: completionRate,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(12),
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickInfoTile(
                        icon: Icons.assignment_turned_in,
                        title: 'Resolved Tasks',
                        value: '$resolvedCount of $totalTasks completed',
                        color: Colors.green,
                      ),
                      _buildQuickInfoTile(
                        icon: Icons.timelapse,
                        title: 'Pending Work',
                        value:
                            '${totalTasks - resolvedCount} tasks still need action',
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
    );
  }
}