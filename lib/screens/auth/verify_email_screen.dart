import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState
    extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;
  bool _isLeaving = false;

  // ============================================================
  // CHECK EMAIL VERIFICATION
  // ============================================================

  Future<void> _checkVerification() async {
    if (_isChecking || _isLeaving) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final verified =
          await _authService
              .refreshEmailVerificationStatus();

      if (!mounted) return;

      // --------------------------------------------------------
      // NOT VERIFIED YET
      // --------------------------------------------------------

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email is not verified yet. '
              'Open the verification email and tap the '
              'verification link first.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // VERIFIED
      // --------------------------------------------------------
      //
      // Do NOT directly route based on role here.
      //
      // LoginScreen contains the complete authentication routing:
      //
      // - User role
      // - Admin role
      // - Collector role
      // - Collector approval status
      // - Collector approval acknowledgement
      // - Wrong login type
      //
      // Logging out and returning to LoginScreen prevents this
      // screen from accidentally bypassing those checks.
      // --------------------------------------------------------

      setState(() {
        _isLeaving = true;
      });

      await _authService.logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email verified successfully. '
            'Please log in to continue.',
          ),
          backgroundColor: Color(0xFF35C76F),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification check failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && !_isLeaving) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> _resendVerificationEmail() async {
    if (_isResending ||
        _isChecking ||
        _isLeaving) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.sendVerificationEmail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification email sent. '
            'Please check your inbox and spam folder.',
          ),
          backgroundColor: Color(0xFF35C76F),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to resend verification email: $e',
          ),
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

  // ============================================================
  // BACK TO LOGIN
  // ============================================================

  Future<void> _backToLogin() async {
    if (_isLeaving) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLeaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to return to login: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ANDROID / SYSTEM BACK BUTTON
  // ============================================================

  Future<bool> _onWillPop() async {
    await _backToLogin();

    // Navigation has already been handled manually.
    return false;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF35C76F);

    final controlsDisabled =
        _isChecking ||
        _isResending ||
        _isLeaving;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFEFF8F6),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                width: 390,
                padding:
                    const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.08),
                      blurRadius: 18,
                      offset:
                          const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================

                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary
                            .withOpacity(0.14),
                      ),
                      child: const Icon(
                        Icons
                            .mark_email_read_outlined,
                        size: 43,
                        color: primary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    const Text(
                      'Verify Your Email',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'We sent a verification link to:',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      widget.email,
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // INSTRUCTION
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFF2F8F5,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      child: Text(
                        'Open your email app, tap the '
                        'Firebase verification link, then '
                        'return here and press '
                        '"I\'ve Verified My Email".',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Colors
                              .grey.shade700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // CHECK VERIFICATION BUTTON
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            controlsDisabled
                                ? null
                                : _checkVerification,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primary,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                        ),
                        icon: _isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .verified_rounded,
                              ),
                        label: Text(
                          _isChecking
                              ? 'Checking...'
                              : 'I\'ve Verified My Email',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // RESEND BUTTON
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            controlsDisabled
                                ? null
                                : _resendVerificationEmail,
                        icon: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .refresh_rounded,
                              ),
                        label: Text(
                          _isResending
                              ? 'Sending...'
                              : 'Resend Verification Email',
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              primary,
                          side:
                              const BorderSide(
                            color: primary,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              15,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ==================================================
                    // BACK TO LOGIN
                    // ==================================================

                    TextButton(
                      onPressed:
                          controlsDisabled
                              ? null
                              : _backToLogin,
                      child: Text(
                        _isLeaving
                            ? 'Returning...'
                            : 'Back to Login',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Didn\'t receive it? '
                      'Check your spam/junk folder '
                      'before resending.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            Colors.grey.shade500,
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