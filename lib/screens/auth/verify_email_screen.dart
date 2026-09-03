import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_main_screen.dart';
import '../collector/collector_main_screen.dart';
import '../user/user_main.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final verified =
          await _authService.refreshEmailVerificationStatus();

      if (!mounted) return;

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email is not verified yet. Open the verification email and tap the verification link first.',
            ),
          ),
        );
        return;
      }

      final user = _authService.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to find the signed-in account. Please log in again.',
            ),
          ),
        );
        return;
      }

      final role = await _authService.getUserRole(user.uid);

      if (!mounted) return;

      Widget destination;

      if (role == 'admin') {
        destination = const AdminMainScreen();
      } else if (role == 'collector') {
        destination = const CollectorMainScreen();
      } else {
        destination = const UserMain();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => destination,
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification check failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.sendVerificationEmail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. Please check your inbox and spam folder.',
          ),
          backgroundColor: Color(0xFF35C76F),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to resend verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _backToLogin() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.isFirst,
    );
  }

  Future<bool> _onWillPop() async {
    await _authService.logout();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF35C76F);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF8F6),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                width: 390,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withOpacity(0.14),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 43,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F8F5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Open your email app, tap the Firebase verification link, then return here and press "I\'ve Verified My Email".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_rounded),
                        label: Text(
                          _isChecking
                              ? 'Checking...'
                              : 'I\'ve Verified My Email',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isResending ? null : _resendVerificationEmail,
                        icon: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: Text(
                          _isResending
                              ? 'Sending...'
                              : 'Resend Verification Email',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: const BorderSide(color: primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _backToLogin,
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Didn\'t receive it? Check your spam/junk folder before resending.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
