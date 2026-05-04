import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'home_screen.dart';
import 'map_page.dart';
import 'more_page.dart';
import 'create_report_screen.dart';
import 'report_list_screen.dart';

class UserMain extends StatefulWidget {
  const UserMain({super.key});

  @override
  State<UserMain> createState() => _UserMainState();
}

class _UserMainState extends State<UserMain> {
  int _index = 0;
  String _reportFilter = 'All';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  void _openReports([String? statusFilter]) {
    setState(() {
      if (statusFilter != null) {
        _reportFilter = statusFilter;
      }
      _index = 3;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(3);
    });
  }

  void _updateReportFilter(String filter) {
    setState(() {
      _reportFilter = filter;
    });
  }

  void _goHome() {
    if (!mounted) return;

    setState(() {
      _index = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(0);
    });
  }

  void _openCreateReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateReportScreen(),
      ),
    ).then((_) {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bottomNavigationKey.currentState?.setPage(_index);
      });
    });
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _openCreateReport();
      return;
    }

    setState(() {
      _index = index;
    });
  }

  Future<bool> _onWillPop() async {
    if (_index != 0) {
      _goHome();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(
        onNavigateToReports: _openReports,
        onCreateReport: _openCreateReport,
      ),

      // USER MAP: only show current user's own reports
      const MapPage(showAllReports: false),

      const SizedBox(),

      ReportListScreen(
        initialStatusFilter: _reportFilter,
        onFilterChanged: _updateReportFilter,
        onBack: _goHome,
      ),

      const MorePage(),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFF7F9FC),
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
          color: Colors.green,
          buttonBackgroundColor: Colors.green,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: _onItemTapped,
          items: const <Widget>[
            Icon(Icons.home_outlined, size: 28, color: Colors.white),
            Icon(Icons.map_outlined, size: 28, color: Colors.white),
            SizedBox(width: 40),
            Icon(Icons.assignment_outlined, size: 28, color: Colors.white),
            Icon(Icons.menu, size: 28, color: Colors.white),
          ],
        ),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}