import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name.trim());

        final appUser = AppUser(
          uid: user.uid,
          name: name.trim(),
          email: email.trim(),
          role: 'user',
        );

        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      print('Doc exists: ${doc.exists}');
      print('Doc data: ${doc.data()}');

      if (!doc.exists || doc.data() == null) {
        return 'user';
      }

      final role = doc.data()!['role'];
      if (role == null) {
        return 'user';
      }

      return role.toString().trim().toLowerCase();
    } catch (e) {
      print('Role read error: $e');
      return 'user';
    }
  }

  Future<AppUser?> getCurrentAppUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) return null;

      return AppUser.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get current user data: $e');
    }
  }

  Future<void> createAdminOrCollectorAccount({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      if (role != 'admin' && role != 'collector') {
        throw Exception('Role must be admin or collector');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(name.trim());

        final appUser = AppUser(
          uid: user.uid,
          name: name.trim(),
          email: email.trim(),
          role: role,
        );

        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to create $role account: $e');
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}
