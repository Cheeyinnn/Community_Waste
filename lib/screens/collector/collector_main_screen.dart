import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import '../../screens/collector/collector_dashboard.dart';
import 'collector_task_screen.dart';
import 'collector_collection_screen.dart';
import '../shared/report_messages_fab.dart';

class CollectorMainScreen extends StatefulWidget {
  const CollectorMainScreen({super.key});

  @override
  State<CollectorMainScreen> createState() =>
      _CollectorMainScreenState();
}

class _CollectorMainScreenState
    extends State<CollectorMainScreen> {
  int _index = 0;

  String _taskFilter = 'All';

  final GlobalKey<CurvedNavigationBarState>
      _bottomNavigationKey =
      GlobalKey<CurvedNavigationBarState>();

  // ============================================================
  // NAVIGATION
  // ============================================================

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

      // Report Tasks is index 1.
      _index = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(1);
    });
  }

  void _navigateToCollectionRuns() {
    setState(() {
      _index = 2;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(2);
    });
  }

  // ============================================================
  // BACK BUTTON
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
      CollectorDashboardScreen(
        onNavigateToTasks: _navigateToTasks,
        onNavigateToCollectionRuns:
            _navigateToCollectionRuns,
      ),

      // 1 - Existing public waste report tasks
      CollectorTaskScreen(
        initialFilter: _taskFilter,
      ),

      // 2 - Municipal collection schedule activity
      const CollectorCollectionScreen(),
    ];

    final baseTheme = Theme.of(context);
    final collectorTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: const Color(0xFFFFB547),
        secondary: const Color(0xFFFFB547),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFFFFB547),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFFFFB547),
        selectionHandleColor: Color(0xFFFFB547),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFFFB547),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFB547),
          side: const BorderSide(color: Color(0xFFFFB547)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFB547),
          foregroundColor: Colors.white,
        ),
      ),
    );

    return Theme(
      data: collectorTheme,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          extendBody: true,
          backgroundColor: const Color(0xFFFFFAF4),

        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: pages,
          ),
        ),

        floatingActionButton: const Padding(
          padding: EdgeInsets.only(bottom: 72),
          child: ReportMessagesFab(currentRole: 'collector'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        bottomNavigationBar: CurvedNavigationBar(
          key: _bottomNavigationKey,
          index: _index,
          height: 65.0,
          backgroundColor: Colors.transparent,
          color: const Color(0xFFFFB547),
          buttonBackgroundColor: const Color(0xFFFFB547),
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
              Icons.assignment_outlined,
              size: 27,
              color: Colors.white,
            ),
            Icon(
              Icons.local_shipping_outlined,
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
