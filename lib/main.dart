import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/user/user_main.dart';
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
  debugPrint('STARTUP: checking Firebase Auth session');

  // ============================================================
  // 1. CHECK CURRENT FIREBASE AUTH SESSION
  // ============================================================

  final user = await _authService.authStateChanges.first;

  if (user == null) {
    debugPrint('STARTUP: no signed-in Firebase user');

    return const _StartupResult(
      screen: LoginScreen(),
    );
  }

  debugPrint(
    'STARTUP: signed-in Firebase user = ${user.uid}',
  );

  // ============================================================
  // 2. READ FIRESTORE USER DOCUMENT
  // ============================================================

  final userRef =
      _firestore.collection('users').doc(user.uid);

  final userDoc = await userRef.get();

  if (!userDoc.exists || userDoc.data() == null) {
    debugPrint(
      'STARTUP: users/${user.uid} does not exist',
    );

    // Auth account exists but application user record
    // is missing. Do not allow access.
    await _authService.logout();

    return const _StartupResult(
      screen: LoginScreen(),
    );
  }

  final userData = userDoc.data()!;

  // ============================================================
  // 3. EMAIL VERIFICATION
  // ============================================================
  //
  // Only accounts that contain:
  //
  // emailVerificationRequired = true
  //
  // are forced to verify.
  //
  // This keeps your older development accounts compatible.
  //
  // Firebase Authentication's emailVerified value is the
  // actual source of truth.
  // ============================================================

  final verificationRequired =
      userData['emailVerificationRequired'] == true;

  if (verificationRequired) {
    debugPrint(
      'STARTUP: email verification is required',
    );

    // Refresh Firebase user information because the verification
    // may have happened while the application was closed.
    await user.reload();

    final refreshedUser = _authService.currentUser;

    if (refreshedUser == null) {
      debugPrint(
        'STARTUP: Firebase user disappeared after reload',
      );

      await _authService.logout();

      return const _StartupResult(
        screen: LoginScreen(),
      );
    }

    if (!refreshedUser.emailVerified) {
      debugPrint(
        'STARTUP: email is NOT verified',
      );

      return _StartupResult(
        screen: VerifyEmailScreen(
          email: refreshedUser.email ?? '',
        ),
      );
    }

    debugPrint(
      'STARTUP: Firebase confirms email is verified',
    );

    // Keep the Firestore convenience fields synchronized.
    if (userData['emailVerified'] != true) {
      await userRef.set(
        {
          'emailVerified': true,
          'emailVerifiedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  // ============================================================
  // 4. READ AND VALIDATE ROLE
  // ============================================================

  final role =
      userData['role']
          ?.toString()
          .trim()
          .toLowerCase() ??
      'user';

  debugPrint(
    'STARTUP: application role = $role',
  );

  // ============================================================
  // 5. ADMIN
  // ============================================================

  if (role == 'admin') {
    debugPrint(
      'STARTUP: routing to AdminMainScreen',
    );

    return const _StartupResult(
      screen: AdminMainScreen(),
    );
  }

  // ============================================================
  // 6. NORMAL USER
  // ============================================================

  if (role == 'user') {
    debugPrint(
      'STARTUP: routing to UserMain',
    );

    return const _StartupResult(
      screen: UserMain(),
    );
  }

  // ============================================================
  // 7. INVALID ROLE
  // ============================================================
  //
  // Previously your code treated any role other than
  // "collector" as a normal user.
  //
  // Example:
  //
  // role = abc
  //
  // would enter UserMain.
  //
  // Only user/admin/collector are accepted now.
  // ============================================================

  if (role != 'collector') {
    debugPrint(
      'STARTUP: invalid role "$role"',
    );

    await _authService.logout();

    return const _StartupResult(
      screen: LoginScreen(),
    );
  }

  // ============================================================
  // 8. COLLECTOR APPLICATION STATUS
  // ============================================================

  final applicationStatus =
      userData['collectorApplicationStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

  debugPrint(
    'STARTUP: collector application status = '
    '$applicationStatus',
  );

  // A user must not enter CollectorMainScreen simply because
  // their role field says collector.
  //
  // The collector application must also be approved.
  if (applicationStatus != 'approved') {
    debugPrint(
      'STARTUP: collector account is not approved',
    );

    await _authService.logout();

    return const _StartupResult(
      screen: LoginScreen(),
    );
  }

  // ============================================================
  // 9. COLLECTOR ASSIGNED ZONES
  // ============================================================

  final rawZones =
      userData['assignedCollectionZoneIds'];

  final assignedZones = rawZones is Iterable
      ? rawZones
          .map(
            (item) => item.toString().trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList()
      : <String>[];

  // ============================================================
  // 10. COLLECTOR APPROVAL TIMESTAMPS
  // ============================================================

  final approvedAt =
      userData['collectorApprovedAt'] is Timestamp
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

  // ============================================================
  // 11. DETERMINE WHETHER CURRENT APPROVAL WAS ACKNOWLEDGED
  // ============================================================

  final bool currentApprovalAcknowledged;

  if (!acknowledgedFlag) {
    // User has never acknowledged collector approval.
    currentApprovalAcknowledged = false;
  } else if (approvedAt == null) {
    // Compatibility for an older collector record that did
    // not store collectorApprovedAt.
    currentApprovalAcknowledged = true;
  } else if (acknowledgedAt == null) {
    // Approval exists but acknowledgement timestamp does not.
    currentApprovalAcknowledged = false;
  } else {
    // If collector was approved again later, an old
    // acknowledgement must not automatically acknowledge
    // the new approval.
    currentApprovalAcknowledged =
        !acknowledgedAt
            .toDate()
            .isBefore(
              approvedAt.toDate(),
            );
  }

  // ============================================================
  // 12. NEWLY APPROVED COLLECTOR
  // ============================================================

  if (!currentApprovalAcknowledged) {
    debugPrint(
      'STARTUP: collector approval acknowledgement required',
    );

    return _StartupResult(
      screen: const CollectorMainScreen(),
      showCollectorApproval: true,
      assignedZones: assignedZones,
    );
  }

  // ============================================================
  // 13. EXISTING APPROVED COLLECTOR
  // ============================================================

  debugPrint(
    'STARTUP: routing approved collector to CollectorMainScreen',
  );

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