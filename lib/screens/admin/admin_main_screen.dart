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
  String _areaFilter = '';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  void _onItemTapped(int index) {
    setState(() {
      _index = index;

      // If admin manually opens Manage Reports tab, clear hotspot area filter.
      if (index == 1) {
        _areaFilter = '';
      }
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

  void _navigateToReports(String filter) {
    setState(() {
      _reportFilter = filter;
      _areaFilter = '';
      _index = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(1);
    });
  }

  void _navigateToReportsByArea(String area) {
    setState(() {
      _reportFilter = 'All';
      _areaFilter = area;
      _index = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(1);
    });
  }

  void _navigateToMap() {
    setState(() {
      _index = 2;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(2);
    });
  }

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      _goDashboard();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      AdminDashboardScreen(
        onNavigateToReports: _navigateToReports,
        onNavigateToReportsByArea: _navigateToReportsByArea,
        onNavigateToMap: _navigateToMap,
      ),
      AdminReportListScreen(
        initialFilter: _reportFilter,
        initialAreaFilter: _areaFilter,
      ),
      const MapPage(showAllReports: true),
      const ProfilePage(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFEFF6FF),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: pages,
          ),
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
            Icon(
              Icons.dashboard_outlined,
              size: 28,
              color: Colors.white,
            ),
            Icon(
              Icons.format_list_bulleted_rounded,
              size: 28,
              color: Colors.white,
            ),
            Icon(
              Icons.map_outlined,
              size: 28,
              color: Colors.white,
            ),
            Icon(
              Icons.person_outline_rounded,
              size: 28,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}