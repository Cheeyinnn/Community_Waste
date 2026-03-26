import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_main.dart';
import 'services/auth_service.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/collector/collector_main_screen.dart';

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
    final AuthService authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Community Waste App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Something went wrong')),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }

          final user = snapshot.data!;

          return FutureBuilder<String>(
            future: authService.getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (roleSnapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Failed to load user role')),
                );
              }

              final role = roleSnapshot.data ?? 'user';

              switch (role) {
                case 'admin':
                  return const AdminDashboardScreen();
                case 'collector':
                  return const CollectorMainScreen();
                default:
                  return const UserMain();
              }
            },
          );
        },
      ),
    );
  }
}