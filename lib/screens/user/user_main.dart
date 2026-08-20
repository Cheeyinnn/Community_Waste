import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'home_screen.dart';
import 'map_page.dart';
import 'create_report_screen.dart';
import 'collection_schedule_screen.dart';
import 'report_list_screen.dart';

class UserMain extends StatefulWidget {
  const UserMain({super.key});

  @override
  State<UserMain> createState() => _UserMainState();
}

class _UserMainState extends State<UserMain> {
  int _index = 0;

  String _reportFilter = 'All';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey =
      GlobalKey<CurvedNavigationBarState>();

  // ============================================================
  // OPEN REPORT PAGE
  // ============================================================

  void _openReports([String? statusFilter]) {
    setState(() {
      if (statusFilter != null) {
        _reportFilter = statusFilter;
      }

      // Reports is now the last tab.
      _index = 4;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(4);
    });
  }

  // ============================================================
  // UPDATE REPORT FILTER
  // ============================================================

  void _updateReportFilter(String filter) {
    setState(() {
      _reportFilter = filter;
    });
  }

  // ============================================================
  // RETURN TO HOME
  // ============================================================

  void _goHome() {
    if (!mounted) return;

    setState(() {
      _index = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(0);
    });
  }

  // ============================================================
  // CREATE REPORT
  // ============================================================

  void _openCreateReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateReportScreen()),
    ).then((_) {
      if (!mounted) return;

      // Keep the curved navigation bar on the current page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bottomNavigationKey.currentState?.setPage(_index);
      });
    });
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onItemTapped(int index) {
    // The middle position belongs to the floating + button.
    if (index == 2) {
      _openCreateReport();
      return;
    }

    setState(() {
      _index = index;
    });
  }

  // ============================================================
  // PHONE BACK BUTTON
  // ============================================================

  Future<bool> _onWillPop() async {
    // If the user is not on Home, pressing back returns to Home first.
    if (_index != 0) {
      _goHome();
      return false;
    }

    return true;
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Index 0 - Home
      HomeScreen(
        onNavigateToReports: _openReports,
        onCreateReport: _openCreateReport,
      ),

      // Index 1 - User Map
      const MapPage(showAllReports: false),

      // Index 2 - Space for Create Report button
      const SizedBox(),

      // Index 3 - Collection Schedule
      const CollectionScheduleScreen(),

      // Index 4 - My Reports
      ReportListScreen(
        initialStatusFilter: _reportFilter,
        onFilterChanged: _updateReportFilter,
        onBack: _goHome,
      ),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF7F9FC),

        // IndexedStack keeps each main page alive when switching tabs.
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),

        // ========================================================
        // CURVED BOTTOM NAVIGATION BAR
        // ========================================================
        bottomNavigationBar: CurvedNavigationBar(
          key: _bottomNavigationKey,

          index: _index,

          height: 65,

          backgroundColor: Colors.transparent,

          color: Colors.green,

          buttonBackgroundColor: Colors.green,

          animationCurve: Curves.easeInOut,

          animationDuration: const Duration(milliseconds: 300),

          onTap: _onItemTapped,

          items: const <Widget>[
            // Home
            Icon(Icons.home_outlined, size: 28, color: Colors.white),

            // Map
            Icon(Icons.map_outlined, size: 28, color: Colors.white),

            // Empty middle space for the floating + button
            SizedBox(width: 40, height: 40),

            // Collection Schedule
            Icon(Icons.calendar_month_outlined, size: 28, color: Colors.white),

            // My Reports
            Icon(Icons.assignment_outlined, size: 28, color: Colors.white),
          ],
        ),

        // ========================================================
        // CENTER + BUTTON
        // ========================================================
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SizedBox(
            width: 70,
            height: 70,
            child: FloatingActionButton(
              onPressed: _openCreateReport,

              backgroundColor: Colors.white,

              elevation: 10,

              shape: const CircleBorder(),

              child: const Icon(
                Icons.add_rounded,
                size: 35,
                color: Colors.green,
              ),
            ),
          ),
        ),

        // Keep the + button in the middle of the navigation bar.
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
