import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'admin_dashboard_screen.dart';
import 'admin_report_list_screen.dart';
import '../user/map_page.dart';
import '../auth/profile_page.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;
  String _reportFilter = 'All';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
    });
  }

  void _navigateToReports(String filter) {
    setState(() {
      _reportFilter = filter;
      _index = 1;
    });
  }

  void _navigateToMap() {
    setState(() {
      _index = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      AdminDashboardScreen(
        onNavigateToReports: _navigateToReports,
        onNavigateToMap: _navigateToMap,
      ),
      AdminReportListScreen(
        initialFilter: _reportFilter,
      ),
      const MapPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        bottom: false,
        child: pages[_index],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _index,
        height: 65.0,
        backgroundColor: Colors.transparent,
        color: Colors.blue,
        buttonBackgroundColor: Colors.blue,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: _onItemTapped,
        items: const <Widget>[
          Icon(Icons.dashboard_outlined, size: 28, color: Colors.white),
          Icon(Icons.format_list_bulleted_rounded, size: 28, color: Colors.white),
          Icon(Icons.map_outlined, size: 28, color: Colors.white),
          Icon(Icons.person_outline_rounded, size: 28, color: Colors.white),
        ],
      ),
    );
  }
}