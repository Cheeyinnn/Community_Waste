import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/user/user_main.dart';
import 'screens/admin/admin_main_screen.dart';
import 'screens/collector/collector_main_screen.dart';

import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

      // IMPORTANT:
      // Do not listen continuously to authStateChanges here.
      //
      // LoginScreen is responsible for deciding whether the user
      // entered through User, Admin, or Collector login and for
      // showing the one-time collector approval message.
      //
      // We only resolve an already-existing Firebase session once
      // when the app first starts.
      home: const StartupGate(),
    );
  }
}

// ============================================================
// STARTUP GATE
// ============================================================
//
// This checks Firebase only ONCE when the app launches.
//
// It does NOT rebuild immediately when LoginScreen calls
// signInWithEmailAndPassword(), so it cannot interrupt the
// approval dialog / role validation inside LoginScreen.
//
// ============================================================

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final AuthService _authService = AuthService();

  late final Future<Widget> _startupScreenFuture;

  @override
  void initState() {
    super.initState();

    _startupScreenFuture = _resolveStartupScreen();
  }

  Future<Widget> _resolveStartupScreen() async {
    final user = _authService.currentUser;

    // No existing Firebase session.
    // Let LoginScreen handle the complete login flow.
    if (user == null) {
      return const LoginScreen();
    }

    // Existing Firebase session from a previous app launch.
    final role = await _authService.getUserRole(user.uid);

    switch (role.trim().toLowerCase()) {
      case 'admin':
        return const AdminMainScreen();

      case 'collector':
        return const CollectorMainScreen();

      case 'user':
      default:
        return const UserMain();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _startupScreenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
