import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collector_application.dart';

class CollectorActiveWorkSummary {
  final int assignedReports;
  final int inProgressReports;
  final int completionSubmittedReports;
  final int inProgressCollectionRuns;

  const CollectorActiveWorkSummary({
    required this.assignedReports,
    required this.inProgressReports,
    required this.completionSubmittedReports,
    required this.inProgressCollectionRuns,
  });

  bool get hasActiveWork =>
      assignedReports > 0 ||
      inProgressReports > 0 ||
      completionSubmittedReports > 0 ||
      inProgressCollectionRuns > 0;

  int get activeReportTasks =>
      assignedReports + inProgressReports + completionSubmittedReports;

  String buildBlockingMessage() {
    final parts = <String>[];

    if (assignedReports > 0) {
      parts.add('$assignedReports Assigned Report Task${assignedReports == 1 ? '' : 's'}');
    }
    if (inProgressReports > 0) {
      parts.add('$inProgressReports In Progress Report Task${inProgressReports == 1 ? '' : 's'}');
    }
    if (completionSubmittedReports > 0) {
      parts.add(
        '$completionSubmittedReports Completion Submitted Report Task${completionSubmittedReports == 1 ? '' : 's'}',
      );
    }
    if (inProgressCollectionRuns > 0) {
      parts.add(
        '$inProgressCollectionRuns In Progress Collection Run${inProgressCollectionRuns == 1 ? '' : 's'}',
      );
    }

    if (parts.isEmpty) {
      return '';
    }

    return 'This Collector still has active work: ${parts.join(', ')}. '
        'Please complete or reassign the remaining duties before changing Collector access.';
  }
}

class CollectorApplicationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection('collector_applications');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> get _collectionEvents =>
      _firestore.collection('collection_events');

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

      final accountStatus =
          userData['accountStatus']?.toString().trim().toLowerCase() ??
              'active';

      if (accountStatus == 'suspended') {
        throw Exception(
          'This User account is suspended and cannot submit a Collector application.',
        );
      }

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
        final existingData = existing.data() ?? <String, dynamic>{};
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

        if (existingStatus == 'suspended') {
          throw Exception(
            'Your Collector access is suspended. An Admin must reactivate it; a new application is not required.',
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

          // Clear lifecycle details from an older rejected/demoted cycle.
          'suspendedAt': FieldValue.delete(),
          'suspendedBy': FieldValue.delete(),
          'suspensionReason': FieldValue.delete(),
          'reactivatedAt': FieldValue.delete(),
          'reactivatedBy': FieldValue.delete(),
          'demotedAt': FieldValue.delete(),
          'demotedBy': FieldValue.delete(),
          'demotionReason': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        userRef,
        {
          'collectorApplicationStatus': 'pending',
          'collectorApplicationUpdatedAt':
              FieldValue.serverTimestamp(),
          'assignedCollectionZoneIds': <String>[],
          'collectorSuspendedAt': FieldValue.delete(),
          'collectorSuspendedBy': FieldValue.delete(),
          'collectorSuspensionReason': FieldValue.delete(),
          'collectorReactivatedAt': FieldValue.delete(),
          'collectorReactivatedBy': FieldValue.delete(),
          'collectorDemotedAt': FieldValue.delete(),
          'collectorDemotedBy': FieldValue.delete(),
          'collectorDemotionReason': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================================================
  // ADMIN LISTS
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
          final aTime = a.submittedAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.submittedAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        return applications;
      },
    );
  }

  // ============================================================
  // ACTIVE WORK CHECK
  // ============================================================

  Future<CollectorActiveWorkSummary> getActiveWorkSummary(
    String collectorUserId,
  ) async {
    await _requireAdmin();

    final cleanCollectorId = collectorUserId.trim();
    if (cleanCollectorId.isEmpty) {
      throw Exception('Collector user ID is missing.');
    }

    final results = await Future.wait([
      _reports.where('collectorId', isEqualTo: cleanCollectorId).get(),
      _collectionEvents
          .where('collectorId', isEqualTo: cleanCollectorId)
          .get(),
    ]);

    final reportSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final eventSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

    var assignedReports = 0;
    var inProgressReports = 0;
    var completionSubmittedReports = 0;

    for (final doc in reportSnapshot.docs) {
      final status =
          doc.data()['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'assigned') {
        assignedReports++;
      } else if (status == 'in progress' || status == 'in_progress') {
        inProgressReports++;
      } else if (status == 'completion submitted' ||
          status == 'completion_submitted') {
        completionSubmittedReports++;
      }
    }

    var inProgressCollectionRuns = 0;

    for (final doc in eventSnapshot.docs) {
      final status =
          doc.data()['status']?.toString().trim().toLowerCase() ?? '';

      if (status == 'in_progress' || status == 'in progress') {
        inProgressCollectionRuns++;
      }
    }

    return CollectorActiveWorkSummary(
      assignedReports: assignedReports,
      inProgressReports: inProgressReports,
      completionSubmittedReports: completionSubmittedReports,
      inProgressCollectionRuns: inProgressCollectionRuns,
    );
  }

  Future<void> _ensureNoActiveWork(String collectorUserId) async {
    final summary = await getActiveWorkSummary(collectorUserId);

    if (summary.hasActiveWork) {
      throw Exception(summary.buildBlockingMessage());
    }
  }

  // ============================================================
  // APPROVE / REJECT
  // ============================================================

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

    final applicationRef = _applications.doc(cleanApplicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);

      if (!applicationDoc.exists || applicationDoc.data() == null) {
        throw Exception(
          'Collector application was not found.',
        );
      }

      final data = applicationDoc.data()!;
      final status =
          data['status']?.toString().trim().toLowerCase() ?? 'pending';

      if (status != 'pending') {
        throw Exception(
          'Only pending applications can be approved.',
        );
      }

      final applicantUserId = data['userId']?.toString().trim() ?? '';

      if (applicantUserId.isEmpty) {
        throw Exception(
          'Applicant user ID is missing.',
        );
      }

      final applicantUserRef = _users.doc(applicantUserId);
      final applicantUserDoc = await transaction.get(applicantUserRef);

      if (!applicantUserDoc.exists || applicantUserDoc.data() == null) {
        throw Exception(
          'Applicant user account was not found.',
        );
      }

      final applicantAccountStatus = applicantUserDoc.data()!['accountStatus']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'active';

      if (applicantAccountStatus == 'suspended') {
        throw Exception(
          'This User account is suspended. Reactivate the account before approving the Collector application.',
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
          'collectorApplicationUpdatedAt': FieldValue.serverTimestamp(),
          'collectorApprovedAt': FieldValue.serverTimestamp(),
          'collectorApprovedBy': admin.uid,
          // A fresh approval (including a new application after demotion) is
          // different from reactivation. Clear any older reactivation marker
          // so the first-time approval notice is used correctly.
          'collectorReactivatedAt': FieldValue.delete(),
          'collectorReactivatedBy': FieldValue.delete(),
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

    final applicationRef = _applications.doc(cleanApplicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);

      if (!applicationDoc.exists || applicationDoc.data() == null) {
        throw Exception(
          'Collector application was not found.',
        );
      }

      final data = applicationDoc.data()!;
      final status =
          data['status']?.toString().trim().toLowerCase() ?? 'pending';

      if (status != 'pending') {
        throw Exception(
          'Only pending applications can be rejected.',
        );
      }

      final applicantUserId = data['userId']?.toString().trim() ?? '';

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
          'role': 'user',
          'collectorApplicationStatus': 'rejected',
          'collectorApplicationUpdatedAt': FieldValue.serverTimestamp(),
          'assignedCollectionZoneIds': <String>[],
        },
        SetOptions(merge: true),
      );
    });
  }

  // ============================================================
  // SUSPEND / REACTIVATE / DEMOTE
  // ============================================================

  Future<void> suspendCollector({
    required String applicationId,
    String reason = '',
  }) async {
    final admin = await _requireAdmin();
    final application = await _getApplicationForAdmin(applicationId);

    if (!application.isApproved) {
      throw Exception('Only an active approved Collector can be suspended.');
    }

    await _ensureNoActiveWork(application.userId);

    final applicationRef = _applications.doc(application.id);
    final userRef = _users.doc(application.userId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);
      final userDoc = await transaction.get(userRef);

      if (!applicationDoc.exists || applicationDoc.data() == null) {
        throw Exception('Collector application was not found.');
      }
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('Collector user account was not found.');
      }

      final liveStatus = applicationDoc.data()!['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      final liveRole = userDoc.data()!['role']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (liveStatus != 'approved' || liveRole != 'collector') {
        throw Exception('Collector access has already changed. Please refresh.');
      }

      transaction.update(
        applicationRef,
        {
          'status': 'suspended',
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedBy': admin.uid,
          'suspensionReason': reason.trim(),
        },
      );

      transaction.set(
        userRef,
        {
          // Keep assigned zones so reactivation does not require
          // rebuilding the Collector's zone assignment.
          'role': 'user',

          // Collector suspension only removes Collector privileges.
          // The underlying User account must stay active so this person can
          // immediately continue using User Login.
          'accountStatus': 'active',
          'accountStatusUpdatedAt': FieldValue.serverTimestamp(),
          'accountSuspensionReason': FieldValue.delete(),
          'accountSuspendedAt': FieldValue.delete(),
          'accountSuspendedBy': FieldValue.delete(),

          'collectorApplicationStatus': 'suspended',
          'collectorApplicationUpdatedAt': FieldValue.serverTimestamp(),
          'collectorSuspendedAt': FieldValue.serverTimestamp(),
          'collectorSuspendedBy': admin.uid,
          'collectorSuspensionReason': reason.trim(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> reactivateCollector({
    required String applicationId,
  }) async {
    final admin = await _requireAdmin();
    final application = await _getApplicationForAdmin(applicationId);

    if (!application.isSuspended) {
      throw Exception('Only a suspended Collector can be reactivated.');
    }

    final zones = application.assignedCollectionZoneIds
        .map((zone) => zone.trim())
        .where((zone) => zone.isNotEmpty)
        .toSet()
        .toList();

    if (zones.isEmpty) {
      throw Exception(
        'This suspended Collector has no assigned collection zone. Demote the account and ask the User to apply again, or restore the zone data first.',
      );
    }

    final applicationRef = _applications.doc(application.id);
    final userRef = _users.doc(application.userId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);
      final userDoc = await transaction.get(userRef);

      if (!applicationDoc.exists || applicationDoc.data() == null) {
        throw Exception('Collector application was not found.');
      }
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('Collector user account was not found.');
      }

      final liveStatus = applicationDoc.data()!['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (liveStatus != 'suspended') {
        throw Exception('Collector access has already changed. Please refresh.');
      }

      transaction.update(
        applicationRef,
        {
          'status': 'approved',
          'reactivatedAt': FieldValue.serverTimestamp(),
          'reactivatedBy': admin.uid,
        },
      );

      transaction.set(
        userRef,
        {
          'role': 'collector',
          'accountStatus': 'active',
          'accountStatusUpdatedAt': FieldValue.serverTimestamp(),
          'accountSuspensionReason': FieldValue.delete(),
          'accountSuspendedAt': FieldValue.delete(),
          'accountSuspendedBy': FieldValue.delete(),
          'collectorApplicationStatus': 'approved',
          'collectorApplicationUpdatedAt': FieldValue.serverTimestamp(),
          'assignedCollectionZoneIds': zones,
          'collectorReactivatedAt': FieldValue.serverTimestamp(),
          'collectorReactivatedBy': admin.uid,
          // Do NOT reset or overwrite the approval acknowledgement here.
          // collectorApprovalAcknowledgedAt is reused as the timestamp of the
          // last Collector lifecycle notice the person acknowledged. Because
          // collectorReactivatedAt is newer than that old acknowledgement,
          // the app can show a one-time "Collector Access Reactivated"
          // message immediately after this update.
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> demoteCollector({
    required String applicationId,
    String reason = '',
  }) async {
    final admin = await _requireAdmin();
    final application = await _getApplicationForAdmin(applicationId);

    if (!application.isApproved && !application.isSuspended) {
      throw Exception(
        'Only an approved or suspended Collector can be demoted.',
      );
    }

    // Even suspended accounts are checked again so stale or manually
    // created active work cannot be orphaned.
    await _ensureNoActiveWork(application.userId);

    final applicationRef = _applications.doc(application.id);
    final userRef = _users.doc(application.userId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);
      final userDoc = await transaction.get(userRef);

      if (!applicationDoc.exists || applicationDoc.data() == null) {
        throw Exception('Collector application was not found.');
      }
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('Collector user account was not found.');
      }

      final liveStatus = applicationDoc.data()!['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';

      if (liveStatus != 'approved' && liveStatus != 'suspended') {
        throw Exception('Collector access has already changed. Please refresh.');
      }

      transaction.update(
        applicationRef,
        {
          'status': 'demoted',
          'assignedCollectionZoneIds': <String>[],
          'demotedAt': FieldValue.serverTimestamp(),
          'demotedBy': admin.uid,
          'demotionReason': reason.trim(),
        },
      );

      transaction.set(
        userRef,
        {
          'role': 'user',
          'accountStatus': 'active',
          'accountStatusUpdatedAt': FieldValue.serverTimestamp(),
          'accountSuspensionReason': FieldValue.delete(),
          'accountSuspendedAt': FieldValue.delete(),
          'accountSuspendedBy': FieldValue.delete(),
          'collectorApplicationStatus': 'demoted',
          'collectorApplicationUpdatedAt': FieldValue.serverTimestamp(),
          'assignedCollectionZoneIds': <String>[],
          'collectorDemotedAt': FieldValue.serverTimestamp(),
          'collectorDemotedBy': admin.uid,
          'collectorDemotionReason': reason.trim(),
          'collectorReactivatedAt': FieldValue.delete(),
          'collectorReactivatedBy': FieldValue.delete(),
          'collectorApprovalAcknowledged': false,
          'collectorApprovalAcknowledgedAt': null,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<CollectorApplication> _getApplicationForAdmin(
    String applicationId,
  ) async {
    final cleanId = applicationId.trim();

    if (cleanId.isEmpty) {
      throw Exception('Application ID is missing.');
    }

    final doc = await _applications.doc(cleanId).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Collector application was not found.');
    }

    final application = CollectorApplication.fromDocument(doc);

    if (application.userId.trim().isEmpty) {
      throw Exception('Collector user ID is missing.');
    }

    return application;
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
        'Only an admin can manage Collector access.',
      );
    }

    return user;
  }
}
