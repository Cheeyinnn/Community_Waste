import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUserManagementService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> suspendUserAccount({
    required String userId,
    String reason = '',
  }) async {
    final admin = await _requireAdmin();
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('User ID is missing.');
    }

    if (cleanUserId == admin.uid) {
      throw Exception('The current Admin account cannot be suspended.');
    }

    final userRef = _users.doc(cleanUserId);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User account was not found.');
      }

      final data = userDoc.data()!;
      final role =
          data['role']?.toString().trim().toLowerCase() ?? 'user';
      final accountStatus =
          data['accountStatus']?.toString().trim().toLowerCase() ?? 'active';
      final collectorStatus = data['collectorApplicationStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (role == 'admin') {
        throw Exception('Admin accounts cannot be suspended here.');
      }

      // Collector access is managed with the separate Collector controls.
      if (role == 'collector' || collectorStatus == 'suspended') {
        throw Exception(
          'This is a Collector account. Use Suspend Collector Access instead.',
        );
      }

      if (accountStatus == 'suspended') {
        throw Exception('This User account is already suspended.');
      }

      transaction.set(
        userRef,
        {
          'accountStatus': 'suspended',
          'accountSuspendedAt': FieldValue.serverTimestamp(),
          'accountSuspendedBy': admin.uid,
          'accountSuspensionReason': reason.trim(),
          'accountStatusUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> reactivateUserAccount({
    required String userId,
  }) async {
    final admin = await _requireAdmin();
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('User ID is missing.');
    }

    final userRef = _users.doc(cleanUserId);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User account was not found.');
      }

      final data = userDoc.data()!;
      final role =
          data['role']?.toString().trim().toLowerCase() ?? 'user';
      final accountStatus =
          data['accountStatus']?.toString().trim().toLowerCase() ?? 'active';
      final collectorStatus = data['collectorApplicationStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (role == 'admin') {
        throw Exception('Admin accounts cannot be managed here.');
      }

      if (role == 'collector' || collectorStatus == 'suspended') {
        throw Exception(
          'This is a Collector account. Use the Collector access controls instead.',
        );
      }

      if (accountStatus != 'suspended') {
        throw Exception('This User account is already active.');
      }

      transaction.set(
        userRef,
        {
          'accountStatus': 'active',
          'accountReactivatedAt': FieldValue.serverTimestamp(),
          'accountReactivatedBy': admin.uid,
          'accountStatusUpdatedAt': FieldValue.serverTimestamp(),
          'accountSuspensionReason': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<User> _requireAdmin() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in as an Admin.');
    }

    final userDoc = await _users.doc(user.uid).get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('Admin user profile was not found.');
    }

    final role = userDoc.data()!['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (role != 'admin') {
      throw Exception('Only an Admin can manage user accounts.');
    }

    return user;
  }
}
