import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/user/user_access_gate.dart';
import 'screens/admin/admin_main_screen.dart';
import 'screens/collector/collector_main_screen.dart';

import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Android development configuration.
  // Change to Play Integrity before production release.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // Temporary development diagnostic.
  // We will remove this during final cleanup.
  try {
    final token =
        await FirebaseAppCheck.instance.getToken(true);

    if (token != null && token.isNotEmpty) {
      debugPrint(
        'APP_CHECK_DIAGNOSTIC: token received successfully '
        '(length=${token.length})',
      );
    } else {
      debugPrint(
        'APP_CHECK_DIAGNOSTIC: no App Check token was returned',
      );
    }
  } catch (e) {
    debugPrint(
      'APP_CHECK_DIAGNOSTIC_ERROR: $e',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waste Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

// ============================================================
// STARTUP RESULT
// ============================================================

class _StartupResult {
  final Widget screen;
  final bool showCollectorApproval;
  final List<String> assignedZones;

  const _StartupResult({
    required this.screen,
    this.showCollectorApproval = false,
    this.assignedZones = const [],
  });
}

// ============================================================
// STARTUP GATE
// ============================================================
//
// Checks an existing Firebase session once when the app starts.
//
// It must NOT bypass:
// - email verification
// - collector approval acknowledgement
//
// Normal manual login remains handled by LoginScreen.
//
// ============================================================

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() =>
      _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  late final Future<_StartupResult>
      _startupFuture;

  bool _approvalDialogShown = false;

  @override
  void initState() {
    super.initState();
    _startupFuture = _resolveStartup();
  }

  Future<_StartupResult> _resolveStartup() async {
    final user = await _authService.authStateChanges.first;

    // ----------------------------------------------------------
    // NO EXISTING SESSION
    // ----------------------------------------------------------

    if (user == null) {
      return const _StartupResult(
        screen: LoginScreen(),
      );
    }

    final userRef =
        _firestore.collection('users').doc(user.uid);

    final userDoc = await userRef.get();

    final userData =
        userDoc.data() ?? <String, dynamic>{};

    // ----------------------------------------------------------
    // OVERALL ACCOUNT SUSPENSION
    // ----------------------------------------------------------

    final startupRole =
        userData['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'user';

    final accountStatus =
        userData['accountStatus']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'active';

    final startupCollectorStatus =
        userData['collectorApplicationStatus']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    // Collector suspension is NOT a full User-account suspension.
    // During Collector suspension the account is deliberately downgraded to
    // role=user and must continue to work through User Login.  The Collector
    // status is checked here as well so older test data with a stale
    // accountStatus='suspended' cannot incorrectly block normal User access.
    final startupCollectorOnlySuspension =
        startupRole == 'user' && startupCollectorStatus == 'suspended';

    if (accountStatus == 'suspended' &&
        startupRole != 'admin' &&
        !startupCollectorOnlySuspension) {
      // Only a true normal-User account suspension blocks the whole app.
      await _authService.logout();

      return const _StartupResult(
        screen: LoginScreen(),
      );
    }

    // ----------------------------------------------------------
    // EMAIL VERIFICATION
    // ----------------------------------------------------------

    final verificationRequired =
        userData['emailVerificationRequired'] == true;

    if (verificationRequired) {
      await user.reload();

      final refreshedUser =
          _authService.currentUser;

      if (refreshedUser == null) {
        return const _StartupResult(
          screen: LoginScreen(),
        );
      }

      if (!refreshedUser.emailVerified) {
        return _StartupResult(
          screen: VerifyEmailScreen(
            email: refreshedUser.email ?? '',
          ),
        );
      }

      await _authService
          .refreshEmailVerificationStatus();
    }

    // ----------------------------------------------------------
    // ROLE
    // ----------------------------------------------------------

    final role =
        userData['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'user';

    // ----------------------------------------------------------
    // ADMIN
    // ----------------------------------------------------------

    if (role == 'admin') {
      return const _StartupResult(
        screen: AdminMainScreen(),
      );
    }

    // ----------------------------------------------------------
    // NORMAL USER
    // ----------------------------------------------------------

    if (role != 'collector') {
      return const _StartupResult(
        screen: UserAccessGate(),
      );
    }

    // ----------------------------------------------------------
    // COLLECTOR APPROVAL INFORMATION
    // ----------------------------------------------------------

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
            .map(
              (item) =>
                  item.toString().trim(),
            )
            .where(
              (item) => item.isNotEmpty,
            )
            .toList()
        : <String>[];

    final approvedAt =
        userData['collectorApprovedAt']
                is Timestamp
            ? userData['collectorApprovedAt']
                as Timestamp
            : null;

    final acknowledgedAt =
        userData[
                'collectorApprovalAcknowledgedAt']
            is Timestamp
            ? userData[
                    'collectorApprovalAcknowledgedAt']
                as Timestamp
            : null;

    final acknowledgedFlag =
        userData[
                'collectorApprovalAcknowledged'] ==
            true;

    final reactivatedAt =
        userData['collectorReactivatedAt'] is Timestamp
            ? userData['collectorReactivatedAt'] as Timestamp
            : null;

    final bool currentApprovalAcknowledged;

    if (!acknowledgedFlag) {
      currentApprovalAcknowledged = false;
    } else if (approvedAt == null) {
      currentApprovalAcknowledged = true;
    } else if (acknowledgedAt == null) {
      currentApprovalAcknowledged = false;
    } else {
      currentApprovalAcknowledged =
          !acknowledgedAt
              .toDate()
              .isBefore(
                approvedAt.toDate(),
              );
    }

    final isApprovedCollector =
        applicationStatus == 'approved';

    final reactivationNoticePending =
        isApprovedCollector &&
        reactivatedAt != null &&
        (acknowledgedAt == null ||
            acknowledgedAt
                .toDate()
                .isBefore(reactivatedAt.toDate()));

    // ----------------------------------------------------------
    // REACTIVATED COLLECTOR
    //
    // Do not reuse the first-time application approval dialog here.
    // CollectorMainScreen has a real-time Firestore gate that shows the
    // one-time "Collector Access Reactivated" message and records the
    // acknowledgement. This branch must come before first approval logic.
    // ----------------------------------------------------------

    if (reactivationNoticePending) {
      return const _StartupResult(
        screen: CollectorMainScreen(),
      );
    }

    // ----------------------------------------------------------
    // NEWLY APPROVED COLLECTOR
    //
    // Keep Firebase session.
    // Show approval dialog directly after app reopen.
    // ----------------------------------------------------------

    if (isApprovedCollector &&
        !currentApprovalAcknowledged) {
      return _StartupResult(
        screen: const CollectorMainScreen(),
        showCollectorApproval: true,
        assignedZones: assignedZones,
      );
    }

    // ----------------------------------------------------------
    // NORMAL EXISTING COLLECTOR SESSION
    // ----------------------------------------------------------

    return const _StartupResult(
      screen: CollectorMainScreen(),
    );
  }

  Future<void> _showCollectorApprovalDialog(
    List<String> assignedZones,
  ) async {
    final user = _authService.currentUser;

    if (user == null || !mounted) {
      return;
    }

    final continueAsCollector =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),
          titlePadding:
              const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            0,
          ),
          contentPadding:
              const EdgeInsets.fromLTRB(
            24,
            18,
            24,
            8,
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          title: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF35C76F)
                          .withOpacity(0.12),
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
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Your collector application has been approved. '
                  'Your account is now registered as a Collector.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color:
                        Colors.grey.shade700,
                  ),
                ),
                if (assignedZones
                    .isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                      border: Border.all(
                        color: Colors
                            .green.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          assignedZones.length ==
                                  1
                              ? 'Assigned Collection Zone'
                              : 'Assigned Collection Zones',
                          style: TextStyle(
                            color: Colors
                                .green.shade800,
                            fontSize: 12,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        const SizedBox(
                          height: 7,
                        ),
                        ...assignedZones.map(
                          (zoneId) =>
                              Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 4,
                            ),
                            child: Text(
                              _zoneDisplayName(
                                zoneId,
                              ),
                              style:
                                  const TextStyle(
                                fontSize:
                                    13.5,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color: Colors
                                    .black87,
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
                  padding:
                      const EdgeInsets.all(
                    13,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Colors.orange.shade50,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Text(
                    'After you continue, please use Collector Login '
                    'for future manual sign-ins.',
                    style: TextStyle(
                      color:
                          Colors.orange.shade900,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight:
                          FontWeight.w600,
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
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF35C76F),
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
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

    if (!mounted) return;

    if (continueAsCollector == true) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'collectorApprovalAcknowledged':
              true,
          'collectorApprovalAcknowledgedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const CollectorMainScreen(),
        ),
        (route) => false,
      );

      return;
    }

    // Cancel means the collector chooses not
    // to continue into the Collector account.
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  String _zoneDisplayName(
    String zoneId,
  ) {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _startupFuture,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'STARTUP_GATE_ERROR: '
            '${snapshot.error}',
          );

          return const LoginScreen();
        }

        final result =
            snapshot.data ??
                const _StartupResult(
                  screen: LoginScreen(),
                );

        if (result.showCollectorApproval &&
            !_approvalDialogShown) {
          _approvalDialogShown = true;

          WidgetsBinding.instance
              .addPostFrameCallback(
            (_) {
              if (!mounted) return;

              _showCollectorApprovalDialog(
                result.assignedZones,
              );
            },
          );
        }

        return result.screen;
      },
    );
  }
}