import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'admin_dashboard_screen.dart';
import 'admin_report_list_screen.dart';
import 'admin_collector_application_screen.dart';
import '../user/map_page.dart';
import '../../services/kampar_data.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;

  String _reportFilter = 'All';
  String _areaFilter = '';

  bool _isUpdatingLocationMetadata = false;

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey =
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
  // LOCATION METADATA
  // ============================================================
  //
  // Kept for development use.
  // The visible dashboard button is hidden temporarily for demos.
  //
  // ============================================================

  Future<void> _updateLocationMetadata() async {
    if (_isUpdatingLocationMetadata) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Location Metadata?'),
          content: const Text(
            'This will update collection-area aliases, landmarks, '
            'and street patterns in Firestore.\n\n'
            'It will NOT delete collection areas, schedules, users, or reports.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isUpdatingLocationMetadata = true;
    });

    try {
      await KamparData.refreshLocationMetadata();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kampar location metadata updated successfully.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update location metadata:\n$e',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocationMetadata = false;
        });
      }
    }
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
      AdminDashboardScreen(
        onNavigateToReports: _navigateToReports,
        onNavigateToReportsByArea: _navigateToReportsByArea,
        onNavigateToMap: _navigateToMap,
      ),
      AdminReportListScreen(
        initialFilter: _reportFilter,
        initialAreaFilter: _areaFilter,
      ),
      const MapPage(
        showAllReports: true,
        isAdminMode: true,
      ),
      const AdminCollectorApplicationScreen(),
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

        // Temporarily hidden for supervisor/demo presentation.
        floatingActionButton: null,

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
          ],
        ),
      ),
    );
  }
}
