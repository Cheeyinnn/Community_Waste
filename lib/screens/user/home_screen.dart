import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'report_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;
    final String userName = user?.email?.split('@').first ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Waste App'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await authService.logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Text(
              'Hello, $userName',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Help keep your community clean by reporting waste issues and tracking cleanup progress.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community Waste Dashboard',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View your waste reporting activity and stay updated with community cleanup efforts.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.assignment_outlined,
                    iconColor: Colors.blue,
                    title: 'My Reports',
                    value: '12',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pending_actions_outlined,
                    iconColor: Colors.orange,
                    title: 'Pending',
                    value: '4',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    title: 'Resolved',
                    value: '6',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.red,
                    title: 'Nearby Cases',
                    value: '8',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.list_alt,
                    color: Colors.blue,
                  ),
                ),
                title: const Text(
                  'My Reports',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('View your submitted reports and status'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportListScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_outlined,
                    color: Colors.orange,
                  ),
                ),
                title: const Text(
                  'Waste Management Tips',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Learn how to keep your area cleaner'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () {
                  _showTipsDialog(context);
                },
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _buildActivityTile(
              icon: Icons.report_gmailerrorred,
              color: Colors.orange,
              title: 'Report submitted successfully',
              subtitle: 'Your latest waste report is under review.',
            ),

            const SizedBox(height: 10),

            _buildActivityTile(
              icon: Icons.local_shipping_outlined,
              color: Colors.deepPurple,
              title: 'Collector assigned',
              subtitle: 'A collector has been assigned to one of your reports.',
            ),

            const SizedBox(height: 10),

            _buildActivityTile(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              title: 'Issue resolved',
              subtitle: 'One reported location has been marked as resolved.',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActivityTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waste Management Tips'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Separate recyclable and non-recyclable waste.'),
            SizedBox(height: 8),
            Text('• Dispose of bulky waste at the proper location.'),
            SizedBox(height: 8),
            Text('• Report illegal dumping as soon as possible.'),
            SizedBox(height: 8),
            Text('• Help keep public areas clean and safe.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}