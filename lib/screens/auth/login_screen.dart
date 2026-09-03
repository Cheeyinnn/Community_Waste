import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:community_waste_app/screens/collector/collector_main_screen.dart';

import '../../services/auth_service.dart';
import '../admin/admin_main_screen.dart';
import '../user/user_main.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

enum LoginRole { user, admin, collector }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  LoginRole _selectedRole = LoginRole.user;

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;

      if (user == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed: user not found'),
          ),
        );
        return;
      }

      final role = await _authService.getUserRole(user.uid);

      if (!mounted) return;

      // ==========================================================
      // EMAIL VERIFICATION
      // ==========================================================

      final verificationRequired =
          await _authService.isEmailVerificationRequired(user.uid);

      if (!mounted) return;

      if (verificationRequired) {
        await user.reload();

        final refreshedUser = _authService.currentUser;

        if (!mounted) return;

        if (refreshedUser != null &&
            !refreshedUser.emailVerified) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyEmailScreen(
                email: refreshedUser.email ??
                    _emailController.text.trim(),
              ),
            ),
          );

          return;
        }

        await _authService.refreshEmailVerificationStatus();
      }

      if (!mounted) return;

      // ==========================================================
      // READ CURRENT USER ROLE / COLLECTOR APPROVAL STATE
      //
      // We read this BEFORE routing anywhere so an approved user
      // cannot accidentally skip the approval message.
      // ==========================================================

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      if (!mounted) return;

      final selectedRole = _selectedRoleValue;

      final applicationStatus =
          userData['collectorApplicationStatus']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final rawZones =
          userData['assignedCollectionZoneIds'];

      final assignedZones = rawZones is Iterable
          ? rawZones
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[];

      final approvedAt =
          userData['collectorApprovedAt'] is Timestamp
              ? userData['collectorApprovedAt'] as Timestamp
              : null;

      final acknowledgedAt =
          userData['collectorApprovalAcknowledgedAt'] is Timestamp
              ? userData['collectorApprovalAcknowledgedAt']
                  as Timestamp
              : null;

      final acknowledgedFlag =
          userData['collectorApprovalAcknowledged'] == true;

      // A collector approval is considered acknowledged only when
      // the acknowledgement belongs to the CURRENT approval.
      //
      // This also fixes repeated testing with the same account:
      // if an old acknowledgement exists but admin approved again
      // later, the new approval message will appear again.
      final bool currentApprovalAcknowledged;

      if (!acknowledgedFlag) {
        currentApprovalAcknowledged = false;
      } else if (approvedAt == null) {
        currentApprovalAcknowledged = true;
      } else if (acknowledgedAt == null) {
        currentApprovalAcknowledged = false;
      } else {
        currentApprovalAcknowledged =
            !acknowledgedAt.toDate().isBefore(
                  approvedAt.toDate(),
                );
      }

      final bool isApprovedCollector =
          role == 'collector' &&
          applicationStatus == 'approved';

      // ==========================================================
      // ONE-TIME APPROVAL NOTICE
      //
      // Show this before ANY normal navigation.
      // It appears whether the person selected User or Collector,
      // so they cannot miss the fact that their role changed.
      // ==========================================================

      if (isApprovedCollector &&
          !currentApprovalAcknowledged) {
        final continueAsCollector =
            await _showCollectorApprovalDialog(
          assignedZones: assignedZones,
        );

        if (!mounted) return;

        if (continueAsCollector == true) {
          await userRef.set(
            {
              'collectorApprovalAcknowledged': true,
              'collectorApprovalAcknowledgedAt':
                  FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          if (!mounted) return;

          _navigateToRole('collector');
          return;
        }

        await _authService.logout();
        return;
      }

      // ==========================================================
      // AFTER APPROVAL HAS ALREADY BEEN ACKNOWLEDGED
      //
      // A collector is no longer allowed to use User Login.
      // Do NOT automatically jump them into Collector anymore.
      // ==========================================================

      if (isApprovedCollector &&
          currentApprovalAcknowledged &&
          selectedRole == 'user') {
        final switchToCollector =
            await _showCollectorMustUseCollectorLoginDialog();

        await _authService.logout();

        if (!mounted) return;

        if (switchToCollector == true) {
          setState(() {
            _selectedRole = LoginRole.collector;
          });
        }

        return;
      }

      // ==========================================================
      // CORRECT LOGIN TAB
      // ==========================================================

      if (selectedRole == role) {
        _navigateToRole(role);
        return;
      }

      // ==========================================================
      // OTHER WRONG LOGIN TABS
      // ==========================================================

      final switchToCorrectRole =
          await _showWrongRoleDialog(
        selectedRole: selectedRole,
        actualRole: role,
        applicationStatus: applicationStatus,
      );

      await _authService.logout();

      if (!mounted) return;

      if (switchToCorrectRole == true) {
        setState(() {
          _selectedRole =
              _loginRoleFromString(role);
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SELECTED LOGIN ROLE
  // ============================================================

  String get _selectedRoleValue {
    switch (_selectedRole) {
      case LoginRole.user:
        return 'user';
      case LoginRole.admin:
        return 'admin';
      case LoginRole.collector:
        return 'collector';
    }
  }

  LoginRole _loginRoleFromString(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return LoginRole.admin;
      case 'collector':
        return LoginRole.collector;
      case 'user':
      default:
        return LoginRole.user;
    }
  }

  // ============================================================
  // FIRST APPROVAL MESSAGE
  // ============================================================

  Future<bool?> _showCollectorApprovalDialog({
    required List<String> assignedZones,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            24,
            18,
            24,
            8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF35C76F).withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF35C76F),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Collector Application Approved',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your collector application has been approved. '
                  'Your account is now registered as a Collector.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),

                if (assignedZones.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            Colors.green.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignedZones.length == 1
                              ? 'Assigned Collection Zone'
                              : 'Assigned Collection Zones',
                          style: TextStyle(
                            color:
                                Colors.green.shade800,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ...assignedZones.map(
                          (zoneId) => Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 4,
                            ),
                            child: Text(
                              _zoneDisplayName(
                                zoneId,
                              ),
                              style:
                                  const TextStyle(
                                fontSize: 13.5,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Text(
                    'After you continue, please use Collector Login '
                    'for future sign-ins.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF35C76F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue as Collector',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // COLLECTOR CAN NO LONGER USE USER LOGIN
  // ============================================================

  Future<bool?> _showCollectorMustUseCollectorLoginDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                color: Color(0xFFFFB547),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Collector Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Your account has already been upgraded to Collector. '
            'User Login is no longer available for this account.\n\n'
            'Please use Collector Login with the same email and password.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFFB547),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text(
                'Switch to Collector Login',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OTHER WRONG ROLE MESSAGE
  // ============================================================

  Future<bool?> _showWrongRoleDialog({
    required String selectedRole,
    required String actualRole,
    required String applicationStatus,
  }) {
    String title = 'Wrong Login Type';
    String message =
        'You selected ${_roleDisplayName(selectedRole)} Login, '
        'but this account is registered as '
        '${_roleDisplayName(actualRole)}.';

    if (selectedRole == 'collector' &&
        actualRole == 'user' &&
        applicationStatus == 'pending') {
      title = 'Application Still Pending';
      message =
          'Your collector application is still waiting for '
          'administrator review. Please continue using User Login '
          'until your application is approved.';
    } else if (selectedRole == 'collector' &&
        actualRole == 'user' &&
        applicationStatus == 'rejected') {
      title = 'Collector Application Not Approved';
      message =
          'Your collector application was not approved. '
          'Your account is still registered as a User.';
    }

    final color = _colorForRole(actualRole);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(
                'Switch to ${_roleDisplayName(actualRole)} Login',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ROLE HELPERS
  // ============================================================

  String _roleDisplayName(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'collector':
        return 'Collector';
      case 'user':
      default:
        return 'User';
    }
  }

  Color _colorForRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'admin':
        return const Color(0xFF3FA9F5);
      case 'collector':
        return const Color(0xFFFFB547);
      case 'user':
      default:
        return const Color(0xFF35C76F);
    }
  }

  String _zoneDisplayName(String zoneId) {
    switch (zoneId) {
      case 'kampar_zone_1':
        return 'Zone 1 • Kampar - Tronoh Mines';
      case 'kampar_zone_2':
        return 'Zone 2 • Kampar - Bandar Baru';
      case 'kampar_zone_3':
        return 'Zone 3 • Kampar Barat - Jeram';
      case 'kampar_zone_4':
        return 'Zone 4 • Gopeng';
      default:
        return zoneId;
    }
  }

  // ============================================================
  // NAVIGATE BY ACTUAL FIRESTORE ROLE
  // ============================================================

  void _navigateToRole(String role) {
    Widget destination;

    switch (role.trim().toLowerCase()) {
      case 'admin':
        destination = const AdminMainScreen();
        break;

      case 'collector':
        destination = const CollectorMainScreen();
        break;

      case 'user':
      default:
        destination = const UserMain();
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => destination,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF2F4F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _primaryColor, width: 1.5),
      ),
    );
  }

  Color get _primaryColor {
    switch (_selectedRole) {
      case LoginRole.user:
        return const Color(0xFF35C76F);
      case LoginRole.admin:
        return const Color(0xFF3FA9F5);
      case LoginRole.collector:
        return const Color(0xFFFFB547);
    }
  }

  IconData get _topIcon {
    switch (_selectedRole) {
      case LoginRole.user:
        return Icons.public;
      case LoginRole.admin:
        return Icons.admin_panel_settings_rounded;
      case LoginRole.collector:
        return Icons.local_shipping_rounded;
    }
  }

  String get _titleText {
    switch (_selectedRole) {
      case LoginRole.user:
        return 'Welcome Back!';
      case LoginRole.admin:
        return 'Admin Login';
      case LoginRole.collector:
        return 'Collector Login';
    }
  }

  String get _buttonText => 'Log In';

  Widget _buildRoleButton(String label, LoginRole role) {
    final bool isSelected = _selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _primaryColor : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (_selectedRole == LoginRole.user) {
      return TextButton(
        onPressed: _isLoading
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
        child: const Text(
          "Don't have an account? Register",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return TextButton(
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _selectedRole = LoginRole.user;
              });
            },
      child: const Text(
        'Switch to User Login',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF8F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.12),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Community Waste Reporting',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: 380,
                      padding: const EdgeInsets.all(22),
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
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryColor.withOpacity(0.15),
                            ),
                            child: Icon(
                              _topIcon,
                              size: 42,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _titleText,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildRoleButton('User', LoginRole.user),
                              const SizedBox(width: 10),
                              _buildRoleButton('Admin', LoginRole.admin),
                              const SizedBox(width: 10),
                              _buildRoleButton('Collector', LoginRole.collector),
                            ],
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: _inputDecoration(hint: 'Email'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) {
                                _login();
                              }
                            },
                            decoration: _inputDecoration(
                              hint: 'Password',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _buttonText,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildBottomAction(),
                          const SizedBox(height: 8),
                          Text(
                            'Securely powered by Malaysia Waste Management.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
