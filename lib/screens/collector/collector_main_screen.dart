import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../shared/report_messages_fab.dart';
import '../user/user_main.dart';
import 'collector_collection_screen.dart';
import 'collector_dashboard.dart';
import 'collector_task_screen.dart';

class CollectorMainScreen extends StatefulWidget {
  const CollectorMainScreen({super.key});

  @override
  State<CollectorMainScreen> createState() =>
      _CollectorMainScreenState();
}

class _CollectorMainScreenState extends State<CollectorMainScreen> {
  int _index = 0;
  String _taskFilter = 'All';

  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey =
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
    if (!mounted) return;

    setState(() {
      _taskFilter = filter;
      _index = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomNavigationKey.currentState?.setPage(1);
    });
  }

  void _navigateToCollectionRuns() {
    if (!mounted) return;

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
  // COLLECTOR APP
  // ============================================================

  Widget _buildCollectorApp(BuildContext context) {
    final List<Widget> pages = [
      CollectorDashboardScreen(
        onNavigateToTasks: _navigateToTasks,
        onNavigateToCollectionRuns: _navigateToCollectionRuns,
      ),
      CollectorTaskScreen(
        initialFilter: _taskFilter,
      ),
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: CurvedNavigationBar(
            key: _bottomNavigationKey,
            index: _index,
            height: 65.0,
            backgroundColor: Colors.transparent,
            color: const Color(0xFFFFB547),
            buttonBackgroundColor: const Color(0xFFFFB547),
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

  // ============================================================
  // REAL-TIME COLLECTOR ACCESS GATE
  //
  // Admin suspend/demote changes Firestore immediately. The Collector app
  // must react immediately too, instead of waiting for the next app restart.
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final currentUser = authSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !authSnapshot.hasData
            ? FirebaseAuth.instance.currentUser
            : authSnapshot.data;

        if (currentUser == null) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (FirebaseAuth.instance.currentUser == null) {
              return const LoginScreen();
            }

            if (userSnapshot.connectionState == ConnectionState.waiting &&
                !userSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFFFFFAF4),
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB547),
                  ),
                ),
              );
            }

            if (userSnapshot.hasError || !userSnapshot.hasData) {
              return const _CollectorAccessChangedScreen(
                title: 'Unable to Verify Collector Access',
                message:
                    'Collector access could not be verified. Return to Login and try again.',
                icon: Icons.error_outline_rounded,
                accentColor: Colors.red,
              );
            }

            final data =
                userSnapshot.data?.data() ?? <String, dynamic>{};

            final role =
                data['role']?.toString().trim().toLowerCase() ?? 'user';
            final applicationStatus = data['collectorApplicationStatus']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

            final suspendedAt =
                data['collectorSuspendedAt'] is Timestamp
                    ? data['collectorSuspendedAt'] as Timestamp
                    : null;

            final reactivatedAt =
                data['collectorReactivatedAt'] is Timestamp
                    ? data['collectorReactivatedAt'] as Timestamp
                    : null;

            final acknowledgedAt =
                data['collectorApprovalAcknowledgedAt'] is Timestamp
                    ? data['collectorApprovalAcknowledgedAt'] as Timestamp
                    : null;

            final reactivationNoticePending =
                role == 'collector' &&
                applicationStatus == 'approved' &&
                reactivatedAt != null &&
                (acknowledgedAt == null ||
                    acknowledgedAt
                        .toDate()
                        .isBefore(reactivatedAt.toDate()));

            if (reactivationNoticePending) {
              return _CollectorReactivatedScreen(
                userId: currentUser.uid,
              );
            }

            final bool hasActiveCollectorAccess = role == 'collector' &&
                (applicationStatus == 'approved' ||
                    applicationStatus.isEmpty);

            if (hasActiveCollectorAccess) {
              return _buildCollectorApp(context);
            }

            if (applicationStatus == 'suspended') {
              final reason =
                  data['collectorSuspensionReason']?.toString().trim() ?? '';

              final suspensionNoticePending =
                  suspendedAt != null &&
                  (acknowledgedAt == null ||
                      acknowledgedAt.toDate().isBefore(suspendedAt.toDate()));

              if (suspensionNoticePending) {
                return _CollectorSuspendedNoticeScreen(
                  userId: currentUser.uid,
                  reason: reason,
                );
              }

              // The Collector has acknowledged the suspension. Keep the same
              // Firebase session and continue immediately as a normal User.
              return const UserMain();
            }

            if (applicationStatus == 'demoted') {
              final reason =
                  data['collectorDemotionReason']?.toString().trim() ?? '';

              return _CollectorAccessChangedScreen(
                title: 'Collector Role Ended',
                message: reason.isEmpty
                    ? 'Your Collector role has been returned to a normal User account. Return to Login and choose User Login. You may apply to become a Collector again later.'
                    : 'Your Collector role has been returned to a normal User account.\n\nReason: $reason\n\nReturn to Login and choose User Login. You may apply to become a Collector again later.',
                icon: Icons.person_outline_rounded,
                accentColor: Colors.red,
              );
            }

            return const _CollectorAccessChangedScreen(
              title: 'Collector Access Changed',
              message:
                  'This account no longer has active Collector access. Return to Login and use the login type currently assigned to the account.',
              icon: Icons.info_outline_rounded,
              accentColor: Colors.orange,
            );
          },
        );
      },
    );
  }
}


class _CollectorSuspendedNoticeScreen extends StatefulWidget {
  final String userId;
  final String reason;

  const _CollectorSuspendedNoticeScreen({
    required this.userId,
    required this.reason,
  });

  @override
  State<_CollectorSuspendedNoticeScreen> createState() =>
      _CollectorSuspendedNoticeScreenState();
}

class _CollectorSuspendedNoticeScreenState
    extends State<_CollectorSuspendedNoticeScreen> {
  bool _isContinuing = false;

  Future<void> _continueAsUser() async {
    if (_isContinuing) return;

    setState(() {
      _isContinuing = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(
        {
          'collectorApprovalAcknowledged': true,
          'collectorApprovalAcknowledgedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // CollectorMainScreen's Firestore listener sees the acknowledgement and
      // returns UserMain. No sign-out or manual navigation is required.
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isContinuing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to continue as User: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Colors.orange,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Collector Access Suspended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reason.isEmpty
                        ? 'Your Collector access has been temporarily suspended by the administrator. You can continue using the application as a normal User.'
                        : 'Your Collector access has been temporarily suspended by the administrator. You can continue using the application as a normal User.\n\nReason: $reason',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isContinuing ? null : _continueAsUser,
                      icon: _isContinuing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.person_rounded),
                      label: Text(
                        _isContinuing
                            ? 'Opening User Account...'
                            : 'Continue as User',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB547),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectorReactivatedScreen extends StatefulWidget {
  final String userId;

  const _CollectorReactivatedScreen({
    required this.userId,
  });

  @override
  State<_CollectorReactivatedScreen> createState() =>
      _CollectorReactivatedScreenState();
}

class _CollectorReactivatedScreenState
    extends State<_CollectorReactivatedScreen> {
  bool _isContinuing = false;

  Future<void> _continueAsCollector() async {
    if (_isContinuing) return;

    setState(() {
      _isContinuing = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(
        {
          'collectorApprovalAcknowledged': true,
          'collectorApprovalAcknowledgedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // The Firestore listener in CollectorMainScreen rebuilds automatically
      // and restores the Collector dashboard after acknowledgement.
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isContinuing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to continue as Collector: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB547).withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restart_alt_rounded,
                      color: Color(0xFFFFB547),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Collector Access Reactivated',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your Collector access has been restored by the administrator. '
                    'You can now continue using the Collector system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _isContinuing ? null : _continueAsCollector,
                      icon: _isContinuing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.local_shipping_rounded),
                      label: Text(
                        _isContinuing
                            ? 'Restoring Collector Access...'
                            : 'Continue as Collector',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB547),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectorAccessChangedScreen extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;

  const _CollectorAccessChangedScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_CollectorAccessChangedScreen> createState() =>
      _CollectorAccessChangedScreenState();
}

class _CollectorAccessChangedScreenState
    extends State<_CollectorAccessChangedScreen> {
  bool _isSigningOut = false;

  Future<void> _backToLogin() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

    try {
      // Do not manually push/remove routes here. The CollectorMainScreen auth
      // listener will replace this screen with LoginScreen after sign-out.
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to sign out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 430,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSigningOut ? null : _backToLogin,
                      icon: _isSigningOut
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        _isSigningOut ? 'Signing Out...' : 'Back to Login',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB547),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
