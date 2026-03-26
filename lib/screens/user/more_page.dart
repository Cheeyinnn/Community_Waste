import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'report_list_screen.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("More"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// Profile
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Profile"),
            subtitle: const Text("View your account information"),
            onTap: () {
              // future profile page
            },
          ),

          const Divider(),

          /// My Reports
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text("My Reports"),
            subtitle: const Text("View all your submitted reports"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportListScreen(),
                ),
              );
            },
          ),

          const Divider(),

          /// Waste Tips
          ListTile(
            leading: const Icon(Icons.tips_and_updates_outlined),
            title: const Text("Waste Management Tips"),
            subtitle: const Text("Learn how to manage waste properly"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Waste Management Tips"),
                  content: const Text(
                    "• Separate recyclable waste\n"
                    "• Dispose bulky waste correctly\n"
                    "• Avoid illegal dumping\n"
                    "• Help keep your community clean",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    )
                  ],
                ),
              );
            },
          ),

          const Divider(),

          /// About App
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About App"),
            subtitle: const Text("Learn more about this application"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Community Waste App",
                applicationVersion: "1.0",
                applicationLegalese: "Developed for community waste reporting.",
              );
            },
          ),

          const Divider(),

          /// Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await authService.logout();
            },
          ),
        ],
      ),
    );
  }
}