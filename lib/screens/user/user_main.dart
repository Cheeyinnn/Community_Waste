import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_page.dart';
import 'notification_page.dart';
import 'more_page.dart';
import 'create_report_screen.dart';

class UserMain extends StatefulWidget {
  const UserMain({super.key});

  @override
  State<UserMain> createState() => _UserMainState();
}

class _UserMainState extends State<UserMain> {
  int _index = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MapPage(),
    const NotificationPage(),
    const MorePage(),
  ];

  void changePage(int i) {
    setState(() {
      _index = i;
    });
  }

  void openReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateReportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: openReport,
        child: const Icon(Icons.add),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              navItem(Icons.home_outlined, "Home", 0),
              navItem(Icons.map_outlined, "Maps", 1),

              const SizedBox(width: 40),

              navItem(Icons.notifications_none, "Notification", 2),
              navItem(Icons.menu, "Others", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int i) {
    bool active = _index == i;

    return InkWell(
      onTap: () => changePage(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? Colors.green : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}