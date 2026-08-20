import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'report_list_screen.dart';
import '../auth/profile_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      backgroundColor: const Color(
        0xFFF7F9FC,
      ), // Matches your cool background theme
      appBar: AppBar(
        title: const Text(
          "Menu",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        // Extra bottom padding ensures the last item isn't hidden by the floating curved nav bar
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        physics: const ClampingScrollPhysics(),
        children: [
          /// --- ACCOUNT GROUP ---
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 10),
            child: Text(
              "Account",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _buildMenuGroup(
            children: [
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.blue.shade700,
                iconBgColor: Colors.blue.shade50,
                title: "Profile",
                subtitle: "View your account information",
                onTap: () {
                  // Navigates to the new Profile Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.list_alt_rounded,
                iconColor: Colors.green.shade700,
                iconBgColor: Colors.green.shade50,
                title: "My Reports",
                subtitle: "View all your submitted reports",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportListScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          /// --- RESOURCES GROUP ---
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 10),
            child: Text(
              "Resources",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _buildMenuGroup(
            children: [
              _buildMenuItem(
                icon: Icons.tips_and_updates_outlined,
                iconColor: Colors.orange.shade700,
                iconBgColor: Colors.orange.shade50,
                title: "Waste Management Tips",
                subtitle: "Learn how to manage waste properly",
                onTap: () {
                  _showTipsDialog(context);
                },
              ),
              _buildDivider(),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.purple.shade700,
                iconBgColor: Colors.purple.shade50,
                title: "About App",
                subtitle: "Learn more about this application",
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "Community Waste App",
                    applicationVersion: "1.0.0",
                    applicationIcon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: Colors.green.shade600,
                        size: 40,
                      ),
                    ),
                    applicationLegalese:
                        "Developed for community waste reporting.",
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 36),

          /// --- LOGOUT BUTTON ---
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text(
                "Log Out",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade100, // Splash color
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.red.shade100, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to wrap menu items in a clean white card
  Widget _buildMenuGroup({required List<Widget> children}) {
    return Container(
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
      // ClipRRect ensures that the InkWell ripple effect doesn't spill out of the rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }

  /// Helper widget for a subtle divider between items
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 70,
        right: 20,
      ), // Aligns perfectly with text
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }

  /// Helper widget for individual menu list items
  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modernized Waste Tips Dialog
  void _showTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: Colors.orange.shade500),
            const SizedBox(width: 10),
            const Text(
              "Waste Tips",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTipRow(Icons.recycling_rounded, "Separate recyclable waste"),
            const SizedBox(height: 12),
            _buildTipRow(
              Icons.delete_sweep_rounded,
              "Dispose bulky waste correctly",
            ),
            const SizedBox(height: 12),
            _buildTipRow(
              Icons.do_not_disturb_alt_rounded,
              "Avoid illegal dumping",
            ),
            const SizedBox(height: 12),
            _buildTipRow(Icons.eco_rounded, "Help keep your community clean"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Got it!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper for the Tips Dialog list
  Widget _buildTipRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
