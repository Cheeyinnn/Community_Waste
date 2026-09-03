import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============================================================
  // REGISTER
  //
  // Every account created from the public Register screen starts
  // as a normal user.
  //
  // Only NEW accounts created through this method get:
  // emailVerificationRequired = true
  //
  // Existing accounts without this field keep working normally.
  // ============================================================

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

        final data = <String, dynamic>{
          ...appUser.toMap(),
          'emailVerificationRequired': true,
          'emailVerified': false,
          'emailVerificationStartedAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(user.uid).set(
          data,
          SetOptions(merge: true),
        );

        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException catch (e) {
          print(
            'Initial verification email could not be sent: '
            '${e.code} - ${e.message}',
          );
        } catch (e) {
          print('Initial verification email could not be sent: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

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

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ============================================================
  // USER ROLE
  // ============================================================

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

  // ============================================================
  // EMAIL VERIFICATION REQUIREMENT
  //
  // Existing account:
  // field missing -> false
  //
  // New account:
  // emailVerificationRequired = true
  // ============================================================

  Future<bool> isEmailVerificationRequired(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        return false;
      }

      final value = doc.data()!['emailVerificationRequired'];

      return value == true;
    } catch (e) {
      // Do not accidentally lock out an existing account if this
      // optional compatibility field cannot be read.
      print('Verification requirement read error: $e');
      return false;
    }
  }

  // ============================================================
  // SEND / RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('No signed-in user found.');
      }

      await user.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception('Unable to refresh the current user.');
      }

      if (refreshedUser.emailVerified) {
        return;
      }

      await refreshedUser.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception('Failed to send verification email: $e');
    }
  }

  // ============================================================
  // CHECK EMAIL VERIFICATION
  //
  // Firebase Authentication is the source of truth.
  // If verified, Firestore is updated for convenient display.
  // ============================================================

  Future<bool> refreshEmailVerificationStatus() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      await user.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        return false;
      }

      final verified = refreshedUser.emailVerified;

      if (verified) {
        await _firestore.collection('users').doc(refreshedUser.uid).set(
          {
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      return verified;
    } catch (e) {
      throw Exception('Failed to check email verification: $e');
    }
  }

  // ============================================================
  // CURRENT APP USER
  // ============================================================

  Future<AppUser?> getCurrentAppUser() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return null;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return AppUser.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get current user data: $e');
    }
  }

  // ============================================================
  // LEGACY / DEVELOPMENT ACCOUNT CREATION
  //
  // Kept so your existing testing workflow is not broken.
  // The public Register screen DOES NOT call this method.
  // Later, collector promotion should happen by admin approval.
  // ============================================================

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

        await _firestore.collection('users').doc(user.uid).set(
          appUser.toMap(),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      throw Exception('Failed to create $role account: $e');
    }
  }

  // ============================================================
  // AUTH ERROR MESSAGE
  // ============================================================

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
