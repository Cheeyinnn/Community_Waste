import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../collector/collector_main_screen.dart';
import 'user_main.dart';

/// Keeps normal User access synchronized with Firebase Authentication and
/// Firestore account status.
///
/// Existing users without accountStatus are treated as active. When an Admin
/// suspends a User, this listener immediately replaces the User interface with
/// a blocked screen. Pressing "Back to Login" only signs out; the outer auth
/// listener then swaps to LoginScreen. This avoids manually removing routes at
/// the same time Firebase/Firestore streams are being disposed.
class UserAccessGate extends StatelessWidget {
  const UserAccessGate({super.key});

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
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            // If sign-out happened while the Firestore stream was still
            // unwinding, immediately follow the auth state instead of showing
            // a stale permission error from the previous User interface.
            if (FirebaseAuth.instance.currentUser == null) {
              return const LoginScreen();
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return _UserAccessErrorScreen(
                message: 'Unable to verify account access. Please try again.',
                onBackToLogin: () async {
                  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                  await AuthService().logout();
                },
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final accountStatus =
                data['accountStatus']?.toString().trim().toLowerCase() ??
                    'active';
            final collectorStatus =
                data['collectorApplicationStatus']
                        ?.toString()
                        .trim()
                        .toLowerCase() ??
                    '';

            final role =
                data['role']?.toString().trim().toLowerCase() ?? 'user';

            final approvalAcknowledged =
                data['collectorApprovalAcknowledged'] == true;

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
                collectorStatus == 'approved' &&
                reactivatedAt != null &&
                (acknowledgedAt == null ||
                    acknowledgedAt
                        .toDate()
                        .isBefore(reactivatedAt.toDate()));

            // A Collector suspension is NOT a full User-account suspension.
            // Admin changes the Collector to role=user so normal User access
            // must remain available immediately. The collectorStatus check also
            // tolerates stale accountStatus values from older test data.
            final isCollectorOnlySuspension =
                role == 'user' && collectorStatus == 'suspended';

            final suspensionNoticePending =
                isCollectorOnlySuspension &&
                suspendedAt != null &&
                (acknowledgedAt == null ||
                    acknowledgedAt.toDate().isBefore(suspendedAt.toDate()));

            if (accountStatus == 'suspended' &&
                !isCollectorOnlySuspension) {
              final reason =
                  data['accountSuspensionReason']?.toString().trim() ?? '';

              return _SuspendedUserScreen(reason: reason);
            }

            // When Admin suspends a Collector while this account is currently
            // showing Collector UI through UserAccessGate, do not silently jump
            // straight to UserMain. Show a one-time suspension notice first.
            if (suspensionNoticePending) {
              final reason =
                  data['collectorSuspensionReason']?.toString().trim() ?? '';

              return _CollectorSuspendedNoticeScreen(
                userId: currentUser.uid,
                reason: reason,
              );
            }

            // Admin reactivated this Collector while the person was still
            // using the normal User interface. Show the correct lifecycle
            // message immediately instead of the first-time approval message.
            if (reactivationNoticePending) {
              return _CollectorReactivatedScreen(
                userId: currentUser.uid,
              );
            }

            // Once the reactivation notice has been acknowledged, the same
            // Firestore stream immediately switches the interface back to the
            // Collector app. First-time approval still uses its existing flow.
            if (role == 'collector' &&
                collectorStatus == 'approved' &&
                approvalAcknowledged) {
              return const CollectorMainScreen();
            }

            return const UserMain();
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
          // Reuse the existing lifecycle acknowledgement timestamp. The next
          // reactivation gets a newer collectorReactivatedAt, so its own
          // one-time notice will still appear correctly.
          'collectorApprovalAcknowledged': true,
          'collectorApprovalAcknowledgedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // No Navigator call is needed. The Firestore listener above rebuilds
      // immediately and shows UserMain after this notice is acknowledged.
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

      // No manual Navigator call is needed. The Firestore StreamBuilder above
      // rebuilds immediately and returns CollectorMainScreen after the
      // acknowledgement timestamp becomes newer than collectorReactivatedAt.
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

class _SuspendedUserScreen extends StatefulWidget {
  final String reason;

  const _SuspendedUserScreen({
    required this.reason,
  });

  @override
  State<_SuspendedUserScreen> createState() =>
      _SuspendedUserScreenState();
}

class _SuspendedUserScreenState extends State<_SuspendedUserScreen> {
  bool _isSigningOut = false;

  Future<void> _backToLogin() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    // Remove any SnackBar queued by a child screen before its Firestore query
    // was cancelled. The auth listener above will handle the screen change.
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();

    try {
      await AuthService().logout();
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
      backgroundColor: const Color(0xFFF7F9FC),
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
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block_rounded,
                      color: Colors.red.shade700,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Account Suspended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.reason.trim().isEmpty
                        ? 'Your account has been suspended by the administrator. You cannot use the application until the account is reactivated.'
                        : 'Your account has been suspended by the administrator.\n\nReason: ${widget.reason.trim()}',
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
                        backgroundColor: Colors.red.shade700,
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

class _UserAccessErrorScreen extends StatefulWidget {
  final String message;
  final Future<void> Function() onBackToLogin;

  const _UserAccessErrorScreen({
    required this.message,
    required this.onBackToLogin,
  });

  @override
  State<_UserAccessErrorScreen> createState() =>
      _UserAccessErrorScreenState();
}

class _UserAccessErrorScreenState extends State<_UserAccessErrorScreen> {
  bool _isSigningOut = false;

  Future<void> _handleBackToLogin() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await widget.onBackToLogin();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          _isSigningOut ? null : _handleBackToLogin,
                      child: Text(
                        _isSigningOut ? 'Signing Out...' : 'Back to Login',
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
