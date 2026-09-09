import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'admin_dashboard_screen.dart';
import 'admin_report_list_screen.dart';
import 'admin_collector_application_screen.dart';
import 'admin_user_management_screen.dart';
import '../user/map_page.dart';
import '../shared/report_messages_fab.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() =>
      _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;

  String _reportFilter = 'All';
  String _areaFilter = '';

  final GlobalKey<CurvedNavigationBarState>
      _bottomNavigationKey =
      GlobalKey<CurvedNavigationBarState>();

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onItemTapped(int index) {
    setState(() {
      _index = index;

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

  // ============================================================
  // PHONE BACK BUTTON
  // ============================================================

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      _goDashboard();
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
      // 0 - Dashboard
      AdminDashboardScreen(
        onNavigateToReports: _navigateToReports,
        onNavigateToReportsByArea:
            _navigateToReportsByArea,
        onNavigateToMap: _navigateToMap,
      ),

      // 1 - Public waste reports
      AdminReportListScreen(
        initialFilter: _reportFilter,
        initialAreaFilter: _areaFilter,
      ),

      // 2 - Report map
      const MapPage(
        showAllReports: true,
      ),

      // 3 - Collector applications
      const AdminCollectorApplicationScreen(),

      // 4 - User / Collector account management
      const AdminUserManagementScreen(),
    ];

    final baseTheme = Theme.of(context);
    final adminTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.blue,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.blue,
        selectionHandleColor: Colors.blue,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );

    return Theme(
      data: adminTheme,
      child: WillPopScope(
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

          floatingActionButton: const Padding(
            padding: EdgeInsets.only(bottom: 72),
            child: ReportMessagesFab(currentRole: 'admin'),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

          bottomNavigationBar: CurvedNavigationBar(
          key: _bottomNavigationKey,
          index: _index,
          height: 65.0,
          backgroundColor: Colors.transparent,
          color: Colors.blue,
          buttonBackgroundColor: Colors.blue,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(
            milliseconds: 300,
          ),
          onTap: _onItemTapped,
          items: const <Widget>[
            Icon(
              Icons.dashboard_outlined,
              size: 27,
              color: Colors.white,
            ),
            Icon(
              Icons.format_list_bulleted_rounded,
              size: 27,
              color: Colors.white,
            ),
            Icon(
              Icons.map_outlined,
              size: 27,
              color: Colors.white,
            ),
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 27,
              color: Colors.white,
            ),
            Icon(
              Icons.manage_accounts_outlined,
              size: 27,
              color: Colors.white,
            ),
          ],
          ),
        ),
      ),
    );
  }
}
