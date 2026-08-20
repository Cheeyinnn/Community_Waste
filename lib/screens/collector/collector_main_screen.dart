import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import '../../screens/collector/collector_dashboard.dart';
import 'collector_task_screen.dart';
import '../auth/profile_page.dart';

class CollectorMainScreen extends StatefulWidget {
  const CollectorMainScreen({super.key});

  @override
  State<CollectorMainScreen> createState() => _CollectorMainScreenState();
}

class _CollectorMainScreenState extends State<CollectorMainScreen> {
  int _index = 0;
  String _taskFilter = 'All';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  void _onItemTapped(int index) {
    setState(() {
      _index = index;
    });
  }

  void _goDashboard() {
    if (!mounted) return;

    setState(() {
      _index = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(0);
    });
  }

  void _navigateToTasks(String filter) {
    setState(() {
      _taskFilter = filter;
      _index = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(1);
    });
  }

  Future<bool> _onWillPop() async {
    // If collector is not on Dashboard, phone back gesture returns to Dashboard first.
    if (_index != 0) {
      _goDashboard();
      return false;
    }

    // If collector is already on Dashboard, phone back gesture closes the app.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      CollectorDashboardScreen(onNavigateToTasks: _navigateToTasks),
      CollectorTaskScreen(initialFilter: _taskFilter),
      const ProfilePage(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: CurvedNavigationBar(
          key: _bottomNavigationKey,
          index: _index,
          height: 65.0,
          backgroundColor: Colors.transparent,
          color: Colors.orange,
          buttonBackgroundColor: Colors.orange,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: _onItemTapped,
          items: const <Widget>[
            Icon(Icons.dashboard_outlined, size: 28, color: Colors.white),
            Icon(Icons.assignment_outlined, size: 28, color: Colors.white),
            Icon(Icons.person_outline_rounded, size: 28, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
