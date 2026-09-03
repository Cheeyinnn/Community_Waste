import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collector_application.dart';

class CollectorApplicationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection('collector_applications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ============================================================
  // USER SIDE
  // ============================================================

  Stream<CollectorApplication?> watchMyApplication() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<CollectorApplication?>.value(null);
    }

    return _applications.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      return CollectorApplication.fromDocument(doc);
    });
  }

  Future<CollectorApplication?> getMyApplication() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final doc = await _applications.doc(user.uid).get();

    if (!doc.exists) {
      return null;
    }

    return CollectorApplication.fromDocument(doc);
  }

  Future<void> submitApplication({
    required String phone,
    required String preferredArea,
    required String experience,
    required String reason,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to apply.');
    }

    final cleanPhone = phone.trim();
    final cleanPreferredArea = preferredArea.trim();
    final cleanExperience = experience.trim();
    final cleanReason = reason.trim();

    if (cleanPhone.isEmpty) {
      throw Exception('Please enter your phone number.');
    }

    if (cleanPreferredArea.isEmpty) {
      throw Exception('Please enter your preferred work area.');
    }

    if (cleanReason.isEmpty) {
      throw Exception(
        'Please tell us why you want to become a collector.',
      );
    }

    final userRef = _users.doc(user.uid);
    final applicationRef = _applications.doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      final userData = userDoc.data() ?? <String, dynamic>{};

      final role =
          userData['role']?.toString().trim().toLowerCase() ?? 'user';

      if (role == 'admin') {
        throw Exception(
          'Admin accounts cannot submit collector applications.',
        );
      }

      if (role == 'collector') {
        throw Exception('This account is already a collector.');
      }

      final existing = await transaction.get(applicationRef);

      if (existing.exists) {
        final existingData =
            existing.data() ?? <String, dynamic>{};

        final existingStatus = existingData['status']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'pending';

        if (existingStatus == 'pending') {
          throw Exception(
            'Your collector application is already pending.',
          );
        }

        if (existingStatus == 'approved') {
          throw Exception(
            'Your collector application has already been approved.',
          );
        }
      }

      final applicantName =
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : userData['name']?.toString().trim().isNotEmpty == true
                  ? userData['name'].toString().trim()
                  : 'User';

      final email = user.email?.trim().isNotEmpty == true
          ? user.email!.trim()
          : userData['email']?.toString().trim() ?? '';

      transaction.set(
        applicationRef,
        {
          'applicationId': user.uid,
          'userId': user.uid,
          'applicantName': applicantName,
          'email': email,
          'phone': cleanPhone,
          'preferredArea': cleanPreferredArea,
          'experience': cleanExperience,
          'reason': cleanReason,
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'reviewedAt': null,
          'reviewedBy': '',
          'adminRemark': '',
          'assignedCollectionZoneIds': <String>[],
        },
        SetOptions(merge: true),
      );

      transaction.set(
        userRef,
        {
          'collectorApplicationStatus': 'pending',
          'collectorApplicationUpdatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================================================
  // ADMIN SIDE
  // ============================================================

  Stream<List<CollectorApplication>> watchAllApplications() {
    return _applications
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs
            .map(CollectorApplication.fromDocument)
            .toList();
      },
    );
  }

  Stream<List<CollectorApplication>> watchApplicationsByStatus(
    String status,
  ) {
    final cleanStatus = status.trim().toLowerCase();

    if (cleanStatus == 'all') {
      return watchAllApplications();
    }

    return _applications
        .where('status', isEqualTo: cleanStatus)
        .snapshots()
        .map(
      (snapshot) {
        final applications = snapshot.docs
            .map(CollectorApplication.fromDocument)
            .toList();

        applications.sort((a, b) {
          final aTime =
              a.submittedAt?.millisecondsSinceEpoch ?? 0;
          final bTime =
              b.submittedAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        return applications;
      },
    );
  }

  Future<void> approveApplication({
    required String applicationId,
    required List<String> assignedCollectionZoneIds,
    String adminRemark = '',
  }) async {
    final admin = await _requireAdmin();

    final cleanApplicationId = applicationId.trim();

    if (cleanApplicationId.isEmpty) {
      throw Exception('Application ID is missing.');
    }

    final cleanZones = assignedCollectionZoneIds
        .map((zone) => zone.trim())
        .where((zone) => zone.isNotEmpty)
        .toSet()
        .toList();

    if (cleanZones.isEmpty) {
      throw Exception(
        'Please assign at least one collection zone.',
      );
    }

    final applicationRef =
        _applications.doc(cleanApplicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc =
          await transaction.get(applicationRef);

      if (!applicationDoc.exists ||
          applicationDoc.data() == null) {
        throw Exception(
          'Collector application was not found.',
        );
      }

      final data = applicationDoc.data()!;
      final status =
          data['status']?.toString().trim().toLowerCase() ??
              'pending';

      if (status != 'pending') {
        throw Exception(
          'Only pending applications can be approved.',
        );
      }

      final applicantUserId =
          data['userId']?.toString().trim() ?? '';

      if (applicantUserId.isEmpty) {
        throw Exception(
          'Applicant user ID is missing.',
        );
      }

      final applicantUserRef =
          _users.doc(applicantUserId);

      final applicantUserDoc =
          await transaction.get(applicantUserRef);

      if (!applicantUserDoc.exists) {
        throw Exception(
          'Applicant user account was not found.',
        );
      }

      transaction.update(
        applicationRef,
        {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': admin.uid,
          'adminRemark': adminRemark.trim(),
          'assignedCollectionZoneIds': cleanZones,
        },
      );

      transaction.set(
        applicantUserRef,
        {
          'role': 'collector',
          'assignedCollectionZoneIds': cleanZones,
          'collectorApplicationStatus': 'approved',
          'collectorApprovedAt':
              FieldValue.serverTimestamp(),
          'collectorApprovedBy': admin.uid,

          // Force the newly approved collector to see the
          // one-time approval notice on their next login.
          'collectorApprovalAcknowledged': false,
          'collectorApprovalAcknowledgedAt': null,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> rejectApplication({
    required String applicationId,
    String adminRemark = '',
  }) async {
    final admin = await _requireAdmin();

    final cleanApplicationId = applicationId.trim();

    if (cleanApplicationId.isEmpty) {
      throw Exception('Application ID is missing.');
    }

    final applicationRef =
        _applications.doc(cleanApplicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc =
          await transaction.get(applicationRef);

      if (!applicationDoc.exists ||
          applicationDoc.data() == null) {
        throw Exception(
          'Collector application was not found.',
        );
      }

      final data = applicationDoc.data()!;
      final status =
          data['status']?.toString().trim().toLowerCase() ??
              'pending';

      if (status != 'pending') {
        throw Exception(
          'Only pending applications can be rejected.',
        );
      }

      final applicantUserId =
          data['userId']?.toString().trim() ?? '';

      if (applicantUserId.isEmpty) {
        throw Exception(
          'Applicant user ID is missing.',
        );
      }

      transaction.update(
        applicationRef,
        {
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': admin.uid,
          'adminRemark': adminRemark.trim(),
          'assignedCollectionZoneIds': <String>[],
        },
      );

      transaction.set(
        _users.doc(applicantUserId),
        {
          // IMPORTANT:
          // Rejection does NOT promote the user.
          'role': 'user',
          'collectorApplicationStatus': 'rejected',
          'collectorApplicationUpdatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<User> _requireAdmin() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in as an admin.');
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
      throw Exception(
        'Only an admin can review collector applications.',
      );
    }

    return user;
  }
}
