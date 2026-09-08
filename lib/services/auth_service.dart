import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // CURRENT FIREBASE USER
  // ============================================================

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ============================================================
  // REGISTER
  //
  // All public registrations start as:
  //
  // role = user
  //
  // Admin and Collector roles must NEVER be created from the
  // public registration screen.
  // ============================================================

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    UserCredential? credential;

    try {
      final cleanName = name.trim();
      final cleanEmail = email.trim();

      if (cleanName.isEmpty) {
        throw Exception('Name is required.');
      }

      if (cleanEmail.isEmpty) {
        throw Exception('Email is required.');
      }

      credential =
          await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception(
          'Unable to create Firebase user.',
        );
      }

      // --------------------------------------------------------
      // Firebase Authentication display name
      // --------------------------------------------------------

      await user.updateDisplayName(cleanName);

      // --------------------------------------------------------
      // Firestore application user document
      // --------------------------------------------------------

      final appUser = AppUser(
        uid: user.uid,
        name: cleanName,
        email: cleanEmail,
        role: 'user',
      );

      final data = <String, dynamic>{
        ...appUser.toMap(),

        // New public accounts must verify their email.
        'emailVerificationRequired': true,
        'emailVerified': false,
        'emailVerificationStartedAt':
            FieldValue.serverTimestamp(),
      };

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(data);
      } catch (e) {
        // ------------------------------------------------------
        // IMPORTANT
        //
        // If Firebase Auth account creation succeeded but the
        // Firestore user document failed, do not leave a broken
        // authentication account behind.
        // ------------------------------------------------------

        try {
          await user.delete();
        } catch (_) {
          // Best-effort cleanup.
        }

        throw Exception(
          'Unable to create user profile: $e',
        );
      }

      // --------------------------------------------------------
      // EMAIL VERIFICATION
      // --------------------------------------------------------

      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        // Registration itself remains successful.
        //
        // The user can use "Resend Verification Email"
        // from VerifyEmailScreen.
        print(
          'Initial verification email could not be sent: '
          '${e.code} - ${e.message}',
        );
      } catch (e) {
        print(
          'Initial verification email could not be sent: $e',
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _getAuthErrorMessage(e),
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Registration failed: $e',
      );
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
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _getAuthErrorMessage(e),
      );
    } catch (e) {
      throw Exception(
        'Login failed: $e',
      );
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
  //
  // Do NOT silently treat a missing/broken account as "user".
  //
  // Only these roles are accepted:
  //
  // user
  // admin
  // collector
  // ============================================================

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception(
          'User profile does not exist.',
        );
      }

      final role =
          doc.data()!['role']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (role != 'user' &&
          role != 'admin' &&
          role != 'collector') {
        throw Exception(
          'Invalid user role.',
        );
      }

      return role;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to read user role: $e',
      );
    }
  }

  // ============================================================
  // EMAIL VERIFICATION REQUIREMENT
  //
  // Older development accounts may not contain:
  //
  // emailVerificationRequired
  //
  // Missing field = false
  //
  // However, a Firestore READ FAILURE must NOT silently return
  // false because that could bypass email verification.
  // ============================================================

  Future<bool> isEmailVerificationRequired(
    String uid,
  ) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        throw Exception(
          'User profile does not exist.',
        );
      }

      final data = doc.data()!;

      if (!data.containsKey(
        'emailVerificationRequired',
      )) {
        // Compatibility for older development accounts.
        return false;
      }

      return data['emailVerificationRequired'] == true;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to check email verification requirement: $e',
      );
    }
  }

  // ============================================================
  // SEND / RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception(
          'No signed-in user found.',
        );
      }

      await user.reload();

      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception(
          'Unable to refresh the current user.',
        );
      }

      // Already verified.
      if (refreshedUser.emailVerified) {
        return;
      }

      await refreshedUser.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _getAuthErrorMessage(e),
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Failed to send verification email: $e',
      );
    }
  }

  // ============================================================
  // REFRESH EMAIL VERIFICATION STATUS
  //
  // Firebase Authentication is the source of truth.
  //
  // Firestore fields are only synchronized copies used by the
  // application's UI/database.
  // ============================================================

  Future<bool>
      refreshEmailVerificationStatus() async {
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

      final verified =
          refreshedUser.emailVerified;

      if (verified) {
        await _firestore
            .collection('users')
            .doc(refreshedUser.uid)
            .set(
          {
            'emailVerified': true,
            'emailVerifiedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      return verified;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        _getAuthErrorMessage(e),
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Failed to check email verification: $e',
      );
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

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return AppUser.fromMap(
        doc.data()!,
        doc.id,
      );
    } catch (e) {
      throw Exception(
        'Failed to get current user data: $e',
      );
    }
  }

  // ============================================================
  // LEGACY PRIVILEGED ACCOUNT CREATION
  //
  // IMPORTANT:
  //
  // Previous development versions allowed the Flutter client
  // to create Admin / Collector accounts directly.
  //
  // That is no longer allowed.
  //
  // We intentionally keep this method temporarily so any old
  // file that still references it will continue to COMPILE,
  // but calling it is blocked.
  //
  // After we finish cleaning the whole project and confirm that
  // nothing references it, we can delete this method entirely.
  // ============================================================

  @Deprecated(
    'Admin and Collector accounts cannot be created directly '
    'from the client application.',
  )
  Future<void> createAdminOrCollectorAccount({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    throw UnsupportedError(
      'Direct creation of Admin or Collector accounts '
      'is disabled. Collector accounts must be promoted '
      'through Admin approval.',
    );
  }

  // ============================================================
  // AUTH ERROR MESSAGES
  // ============================================================

  String _getAuthErrorMessage(
    FirebaseAuthException e,
  ) {
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

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'operation-not-allowed':
        return 'This authentication method is not enabled.';

      default:
        return e.message ??
            'Authentication error occurred.';
    }
  }
}