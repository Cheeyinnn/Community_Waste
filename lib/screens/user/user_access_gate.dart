import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'user_main.dart';

/// Keeps normal User access synchronized with the Firestore accountStatus.
///
/// Existing users without accountStatus are treated as active. When an Admin
/// suspends a User, this listener immediately replaces the User interface with
/// a blocked screen. Collector-only suspension does not use accountStatus, so a
/// suspended Collector can still continue as a normal User as intended.
class UserAccessGate extends StatelessWidget {
  const UserAccessGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final accountStatus =
            data['accountStatus']?.toString().trim().toLowerCase() ??
                'active';

        if (accountStatus == 'suspended') {
          final reason =
              data['accountSuspensionReason']?.toString().trim() ?? '';

          return _SuspendedUserScreen(reason: reason);
        }

        return const UserMain();
      },
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

    await AuthService().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
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
