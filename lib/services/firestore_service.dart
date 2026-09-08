import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/waste_report.dart';

class FirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // COLLECTION REFERENCES
  // ============================================================

  CollectionReference<Map<String, dynamic>>
      get _reportsRef =>
          _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>>
      get _usersRef =>
          _firestore.collection('users');

  // ============================================================
  // VALID VALUES
  // ============================================================

  static const Set<String> _validStatuses = {
    'Pending',
    'Assigned',
    'In Progress',
    'Completion Submitted',
    'Resolved',
    'Rejected',
  };

  static const Set<String> _validPriorities = {
    'Low',
    'Medium',
    'High',
  };

  // ============================================================
  // COMMON HELPERS
  // ============================================================

  List<WasteReport> _mapSnapshotToWasteReports(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(
          (doc) => WasteReport.fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  String _cleanRequired(
    String value,
    String fieldName,
  ) {
    final clean = value.trim();

    if (clean.isEmpty) {
      throw Exception(
        '$fieldName is required.',
      );
    }

    return clean;
  }

  void _validatePriority(
    String priority,
  ) {
    if (!_validPriorities.contains(priority)) {
      throw Exception(
        'Invalid report priority.',
      );
    }
  }

  void _validateStatus(
    String status,
  ) {
    if (!_validStatuses.contains(status)) {
      throw Exception(
        'Invalid report status.',
      );
    }
  }

  // ============================================================
  // AUTHORIZATION HELPERS
  // ============================================================

  Future<Map<String, dynamic>>
      _getCurrentUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in to perform this action.',
      );
    }

    final doc =
        await _usersRef.doc(user.uid).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'User account information was not found.',
      );
    }

    return doc.data()!;
  }

  Future<String> _requireNormalUserUid() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User must be logged in.',
      );
    }

    final data = await _getCurrentUserData();

    final role =
        data['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (role != 'user') {
      throw Exception(
        'Only a normal User account can perform this action.',
      );
    }

    return user.uid;
  }

  Future<String> _requireAdminUid() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Admin must be logged in.',
      );
    }

    final data = await _getCurrentUserData();

    final role =
        data['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (role != 'admin') {
      throw Exception(
        'Only an Admin account can perform this action.',
      );
    }

    return user.uid;
  }

  Future<String> _requireCollectorUid() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Collector must be logged in.',
      );
    }

    final data = await _getCurrentUserData();

    final role =
        data['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    final applicationStatus =
        data['collectorApplicationStatus']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (role != 'collector' ||
        applicationStatus != 'approved') {
      throw Exception(
        'Only an approved Collector account '
        'can perform this action.',
      );
    }

    return user.uid;
  }

  Future<bool> _currentUserIsAdmin() async {
    final user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    final doc =
        await _usersRef.doc(user.uid).get();

    if (!doc.exists || doc.data() == null) {
      return false;
    }

    return doc.data()!['role']
            ?.toString()
            .trim()
            .toLowerCase() ==
        'admin';
  }

  // ============================================================
  // CREATE REPORT
  // ============================================================

  Future<void> createReport(
    WasteReport report,
  ) async {
    final uid =
        await _requireNormalUserUid();

    if (report.userId != uid) {
      throw Exception(
        'You can only submit a report for your own account.',
      );
    }

    if (report.status != 'Pending') {
      throw Exception(
        'A new report must start as Pending.',
      );
    }

    if (report.collectorId.trim().isNotEmpty ||
        report.collectorName.trim().isNotEmpty) {
      throw Exception(
        'A new report cannot already have a collector.',
      );
    }

    _validatePriority(report.priority);

    _cleanRequired(
      report.title,
      'Report title',
    );

    _cleanRequired(
      report.description,
      'Description',
    );

    _cleanRequired(
      report.location,
      'Location',
    );

    _cleanRequired(
      report.area,
      'Area',
    );

    _cleanRequired(
      report.wasteType,
      'Waste type',
    );

    _cleanRequired(
      report.imageUrl,
      'Report image',
    );

    final data = report.toMap();

    data['priority'] =
        report.priority;

    data['status'] = 'Pending';

    data['collectorId'] = '';
    data['collectorName'] = '';

    data['adminRemark'] = '';
    data['collectorRemark'] = '';

    data['completionImageUrl'] = '';

    data['updatedAt'] =
        data['createdAt'] ??
        Timestamp.now();

    await _reportsRef.add(data);
  }

  // ============================================================
  // DUPLICATE REPORT CHECKING
  // ============================================================

  Future<List<WasteReport>>
      findPotentialDuplicateReports({
    required String wasteType,
    Duration withinDuration =
        const Duration(hours: 24),
    int maxResults = 50,
  }) async {
    final cutoff =
        DateTime.now().subtract(
      withinDuration,
    );

    final snapshot = await _reportsRef
        .where(
          'wasteType',
          isEqualTo: wasteType,
        )
        .where(
          'createdAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(cutoff),
        )
        .limit(maxResults)
        .get();

    return snapshot.docs
        .map(
          (doc) => WasteReport.fromMap(
            doc.data(),
            doc.id,
          ),
        )
        .toList();
  }

  Future<List<WasteReport>>
      findNearbyDuplicateCandidates({
    required String wasteType,
    required double latitude,
    required double longitude,
    Duration withinDuration =
        const Duration(hours: 24),
    double radiusMeters = 100,
    int maxResults = 50,
  }) async {
    final recentReports =
        await findPotentialDuplicateReports(
      wasteType: wasteType,
      withinDuration: withinDuration,
      maxResults: maxResults,
    );

    return recentReports.where(
      (report) {
        if (report.latitude == 0.0 &&
            report.longitude == 0.0) {
          return false;
        }

        final distance =
            Geolocator.distanceBetween(
          latitude,
          longitude,
          report.latitude,
          report.longitude,
        );

        return distance <= radiusMeters;
      },
    ).toList();
  }

  // ============================================================
  // AUTOMATIC PRIORITY
  // ============================================================

  Future<int> getRecentReportCountByArea(
    String area,
  ) async {
    final now = DateTime.now();

    final sevenDaysAgo =
        now.subtract(
      const Duration(days: 7),
    );

    final snapshot = await _reportsRef
        .where(
          'area',
          isEqualTo: area.trim(),
        )
        .where(
          'createdAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(
            sevenDaysAgo,
          ),
        )
        .get();

    return snapshot.docs.length;
  }

  Future<String> getAutoPriorityByArea(
    String area,
  ) async {
    final existingCount =
        await getRecentReportCountByArea(
      area,
    );

    final totalAfterSubmit =
        existingCount + 1;

    if (totalAfterSubmit >= 3) {
      return 'High';
    }

    if (totalAfterSubmit == 2) {
      return 'Medium';
    }

    return 'Low';
  }

  // ============================================================
  // REPORT STREAMS
  // ============================================================

  Stream<List<WasteReport>> getUserReports(
    String userId,
  ) {
    return _reportsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  Stream<List<WasteReport>> getAllReports() {
    return _reportsRef
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  Stream<List<WasteReport>>
      getReportsByStatus(
    String status,
  ) {
    _validateStatus(status);

    return _reportsRef
        .where(
          'status',
          isEqualTo: status,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  Stream<List<WasteReport>>
      getCollectorReports(
    String collectorId,
  ) {
    return _reportsRef
        .where(
          'collectorId',
          isEqualTo: collectorId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  Stream<List<WasteReport>>
      getCollectorReportsByDateRange({
    required String collectorId,
    required DateTime start,
    required DateTime end,
  }) {
    return _reportsRef
        .where(
          'collectorId',
          isEqualTo: collectorId,
        )
        .where(
          'createdAt',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(start),
        )
        .where(
          'createdAt',
          isLessThan:
              Timestamp.fromDate(end),
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  Future<WasteReport?> getReportById(
    String reportId,
  ) async {
    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final doc =
        await _reportsRef
            .doc(cleanId)
            .get();

    final data = doc.data();

    if (!doc.exists || data == null) {
      return null;
    }

    return WasteReport.fromMap(
      data,
      doc.id,
    );
  }

  // ============================================================
  // USER REPORT COUNTS
  // ============================================================

  Stream<int> getUserReportCount(
    String userId,
  ) {
    return _reportsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.length,
        );
  }

  Stream<int> getUserReportCountByStatus(
    String userId,
    String status,
  ) {
    _validateStatus(status);

    return _reportsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'status',
          isEqualTo: status,
        )
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.length,
        );
  }

  Stream<List<WasteReport>>
      getRecentUserActivities(
    String userId,
  ) {
    return _reportsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .snapshots()
        .map(
      (snapshot) {
        final reports =
            _mapSnapshotToWasteReports(
          snapshot,
        );

        reports.sort(
          (a, b) =>
              b.updatedAt.compareTo(
            a.updatedAt,
          ),
        );

        return reports
            .take(5)
            .toList();
      },
    );
  }

  Stream<List<WasteReport>>
      getRecentUserReports(
    String userId,
  ) {
    return _reportsRef
        .where(
          'userId',
          isEqualTo: userId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(5)
        .snapshots()
        .map(
          _mapSnapshotToWasteReports,
        );
  }

  // ============================================================
  // ADMIN REPORT MANAGEMENT
  // ============================================================

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanStatus =
        status.trim();

    _validateStatus(cleanStatus);

    // ----------------------------------------------------------
    // IMPORTANT
    //
    // These statuses belong to Collector/Admin completion
    // workflow and should not be manually forced using the
    // generic status function.
    // ----------------------------------------------------------

    if (cleanStatus ==
            'In Progress' ||
        cleanStatus ==
            'Completion Submitted' ||
        cleanStatus ==
            'Resolved') {
      throw Exception(
        'This status must be changed through '
        'the Collector completion workflow.',
      );
    }

    await _reportsRef
        .doc(cleanId)
        .update(
      {
        'status': cleanStatus,
        'updatedAt':
            Timestamp.now(),
      },
    );
  }

  Future<void> updateReportPriority({
    required String reportId,
    required String priority,
  }) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanPriority =
        priority.trim();

    _validatePriority(
      cleanPriority,
    );

    await _reportsRef
        .doc(cleanId)
        .update(
      {
        'priority': cleanPriority,
        'updatedAt':
            Timestamp.now(),
      },
    );
  }

  // ============================================================
  // USER / ADMIN REPORT EDIT
  // ============================================================

  Future<void> updateReport({
    required String reportId,
    required String title,
    required String description,
    required String location,
    required String area,
    required String wasteType,
    String? priority,
    double? latitude,
    double? longitude,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanTitle =
        _cleanRequired(
      title,
      'Title',
    );

    final cleanDescription =
        _cleanRequired(
      description,
      'Description',
    );

    final cleanLocation =
        _cleanRequired(
      location,
      'Location',
    );

    final cleanArea =
        _cleanRequired(
      area,
      'Area',
    );

    final cleanWasteType =
        _cleanRequired(
      wasteType,
      'Waste type',
    );

    final isAdmin =
        await _currentUserIsAdmin();

    // ----------------------------------------------------------
    // ADMIN EDIT
    // ----------------------------------------------------------

    if (isAdmin) {
      final Map<String, dynamic> data = {
        'title': cleanTitle,
        'description':
            cleanDescription,
        'location':
            cleanLocation,
        'area': cleanArea,
        'wasteType':
            cleanWasteType,
        'updatedAt':
            Timestamp.now(),
      };

      if (priority != null) {
        final cleanPriority =
            priority.trim();

        _validatePriority(
          cleanPriority,
        );

        data['priority'] =
            cleanPriority;
      }

      if (latitude != null) {
        data['latitude'] =
            latitude;
      }

      if (longitude != null) {
        data['longitude'] =
            longitude;
      }

      await _reportsRef
          .doc(cleanId)
          .update(data);

      return;
    }

    // ----------------------------------------------------------
    // NORMAL USER EDIT
    //
    // IMPORTANT:
    // Re-check ownership and CURRENT report status inside a
    // Firestore transaction.
    //
    // This prevents:
    //
    // User opens Pending Edit page
    // → Admin assigns report
    // → User presses Save using old page
    // ----------------------------------------------------------

    if (priority != null) {
      throw Exception(
        'Users cannot manually change report priority.',
      );
    }

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final currentData =
            reportDoc.data()!;

        final ownerId =
            currentData['userId']
                    ?.toString() ??
                '';

        final status =
            currentData['status']
                    ?.toString() ??
                '';

        if (ownerId != user.uid) {
          throw Exception(
            'You can only edit your own report.',
          );
        }

        if (status != 'Pending') {
          throw Exception(
            'This report can no longer be edited '
            'because it is not Pending.',
          );
        }

        final update =
            <String, dynamic>{
          'title': cleanTitle,
          'description':
              cleanDescription,
          'location':
              cleanLocation,
          'area': cleanArea,
          'wasteType':
              cleanWasteType,
          'updatedAt':
              Timestamp.now(),
        };

        if (latitude != null) {
          update['latitude'] =
              latitude;
        }

        if (longitude != null) {
          update['longitude'] =
              longitude;
        }

        transaction.update(
          reportRef,
          update,
        );
      },
    );
  }

  // ============================================================
  // ADMIN ASSIGN COLLECTOR
  // ============================================================

  Future<void> assignCollector({
    required String reportId,
    required String collectorId,
    required String collectorName,
    String adminRemark = '',
    String? priority,
  }) async {
    await _requireAdminUid();

    final cleanReportId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanCollectorId =
        _cleanRequired(
      collectorId,
      'Collector',
    );

    final cleanCollectorName =
        _cleanRequired(
      collectorName,
      'Collector name',
    );

    // ----------------------------------------------------------
    // VERIFY COLLECTOR ACCOUNT
    // ----------------------------------------------------------

    final collectorDoc =
        await _usersRef
            .doc(cleanCollectorId)
            .get();

    if (!collectorDoc.exists ||
        collectorDoc.data() == null) {
      throw Exception(
        'Collector account was not found.',
      );
    }

    final collectorData =
        collectorDoc.data()!;

    final role =
        collectorData['role']
            ?.toString()
            .trim()
            .toLowerCase();

    final applicationStatus =
        collectorData[
                'collectorApplicationStatus']
            ?.toString()
            .trim()
            .toLowerCase();

    if (role != 'collector' ||
        applicationStatus !=
            'approved') {
      throw Exception(
        'The selected account is not '
        'an approved Collector.',
      );
    }

    String? cleanPriority;

    if (priority != null) {
      cleanPriority =
          priority.trim();

      _validatePriority(
        cleanPriority,
      );
    }

    final reportRef =
        _reportsRef.doc(
      cleanReportId,
    );

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final currentStatus =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        if (currentStatus ==
                'In Progress' ||
            currentStatus ==
                'Completion Submitted' ||
            currentStatus ==
                'Resolved') {
          throw Exception(
            'This report can no longer be '
            'assigned to another collector.',
          );
        }

        final Map<String, dynamic>
            updateData = {
          'collectorId':
              cleanCollectorId,
          'collectorName':
              cleanCollectorName,
          'status': 'Assigned',
          'adminRemark':
              adminRemark.trim(),

          // Reset completion review state.
          'completionImageUrl': '',
          'collectorRemark': '',
          'completionVerificationStatus':
              '',
          'completionRejectionReason':
              '',
          'completionReviewedBy': '',
          'completionReviewedAt': null,
          'completionSubmittedAt': null,
          'resolvedAt': null,

          'updatedAt':
              Timestamp.now(),
        };

        if (cleanPriority != null) {
          updateData['priority'] =
              cleanPriority;
        }

        transaction.update(
          reportRef,
          updateData,
        );
      },
    );
  }

  // ============================================================
  // ADMIN REMOVE COLLECTOR
  // ============================================================

  Future<void> removeCollector({
    required String reportId,
  }) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final reportRef =
        _reportsRef.doc(
      cleanId,
    );

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final status =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        if (status != 'Assigned') {
          throw Exception(
            'Collector can only be removed '
            'before the task starts.',
          );
        }

        transaction.update(
          reportRef,
          {
            'collectorId': '',
            'collectorName': '',
            'status': 'Pending',

            'collectorRemark': '',
            'completionImageUrl': '',
            'completionVerificationStatus':
                '',
            'completionRejectionReason':
                '',
            'completionReviewedBy': '',
            'completionReviewedAt': null,
            'completionSubmittedAt': null,
            'resolvedAt': null,

            'updatedAt':
                Timestamp.now(),
          },
        );
      },
    );
  }

  // ============================================================
  // ADMIN REJECT REPORT
  // ============================================================

  Future<void> rejectReport({
    required String reportId,
    required String adminRemark,
    String? priority,
  }) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanRemark =
        _cleanRequired(
      adminRemark,
      'Rejection reason',
    );

    String? cleanPriority;

    if (priority != null) {
      cleanPriority =
          priority.trim();

      _validatePriority(
        cleanPriority,
      );
    }

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final currentStatus =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        if (currentStatus ==
                'In Progress' ||
            currentStatus ==
                'Completion Submitted' ||
            currentStatus ==
                'Resolved') {
          throw Exception(
            'This report can no longer be rejected '
            'using the normal report review workflow.',
          );
        }

        final Map<String, dynamic>
            updateData = {
          'status': 'Rejected',
          'adminRemark':
              cleanRemark,

          // Rejected reports are no longer
          // assigned to a collector.
          'collectorId': '',
          'collectorName': '',

          'updatedAt':
              Timestamp.now(),
        };

        if (cleanPriority != null) {
          updateData['priority'] =
              cleanPriority;
        }

        transaction.update(
          reportRef,
          updateData,
        );
      },
    );
  }

  // ============================================================
  // ADMIN VERIFY / REMARK
  // ============================================================

  Future<void> verifyReport({
    required String reportId,
    String adminRemark =
        'Report verified by admin',
  }) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    await _reportsRef
        .doc(cleanId)
        .update(
      {
        'adminRemark':
            adminRemark.trim(),
        'updatedAt':
            Timestamp.now(),
      },
    );
  }

  // ============================================================
  // COLLECTOR REPORT TASK WORKFLOW
  // ============================================================

  Future<void> startCollectorTask({
    required String reportId,
    String collectorRemark = '',
  }) async {
    final collectorUid =
        await _requireCollectorUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final assignedCollectorId =
            data['collectorId']
                    ?.toString()
                    .trim() ??
                '';

        final status =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        if (assignedCollectorId !=
            collectorUid) {
          throw Exception(
            'This report is not assigned '
            'to the current collector.',
          );
        }

        if (status ==
            'Completion Submitted') {
          throw Exception(
            'This task is waiting for '
            'Admin completion review.',
          );
        }

        if (status == 'Resolved') {
          throw Exception(
            'This report has already been resolved.',
          );
        }

        if (status == 'Rejected') {
          throw Exception(
            'This report has been rejected by Admin.',
          );
        }

        if (status != 'Assigned' &&
            status != 'In Progress') {
          throw Exception(
            'Only an Assigned task can be started.',
          );
        }

        transaction.update(
          reportRef,
          {
            'status': 'In Progress',
            'collectorRemark':
                collectorRemark.trim(),
            'updatedAt':
                Timestamp.now(),
          },
        );
      },
    );
  }

  // ============================================================
  // COLLECTOR SUBMIT COMPLETION
  // ============================================================

  Future<void> submitCollectorCompletion({
    required String reportId,
    required String collectorRemark,
    required String completionImageUrl,
  }) async {
    final collectorUid =
        await _requireCollectorUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final cleanImageUrl =
        _cleanRequired(
      completionImageUrl,
      'Completion image',
    );

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final collectorId =
            data['collectorId']
                    ?.toString()
                    .trim() ??
                '';

        final status =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        if (collectorId !=
            collectorUid) {
          throw Exception(
            'This report is not assigned '
            'to the current collector.',
          );
        }

        if (status !=
            'In Progress') {
          throw Exception(
            'The task must be In Progress '
            'before completion can be submitted.',
          );
        }

        final now =
            Timestamp.now();

        transaction.update(
          reportRef,
          {
            'status':
                'Completion Submitted',

            'collectorRemark':
                collectorRemark.trim(),

            'completionImageUrl':
                cleanImageUrl,

            'completionVerificationStatus':
                'pending',

            'completionSubmittedAt':
                now,

            'completionReviewedBy':
                '',

            'completionReviewedAt':
                null,

            'completionRejectionReason':
                '',

            'resolvedAt': null,

            'updatedAt': now,
          },
        );
      },
    );
  }

  // ============================================================
  // BACKWARD COMPATIBILITY
  // ============================================================

  Future<void> completeCollectorTask({
    required String reportId,
    required String collectorRemark,
    required String completionImageUrl,
  }) async {
    await submitCollectorCompletion(
      reportId: reportId,
      collectorRemark:
          collectorRemark,
      completionImageUrl:
          completionImageUrl,
    );
  }

  // ============================================================
  // ADMIN APPROVE COLLECTOR COMPLETION
  // ============================================================

  Future<void> approveCollectorCompletion({
    required String reportId,
  }) async {
    final adminUid =
        await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final status =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        final verificationStatus =
            data[
                    'completionVerificationStatus']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        final completionImageUrl =
            data['completionImageUrl']
                    ?.toString()
                    .trim() ??
                '';

        if (status !=
                'Completion Submitted' ||
            verificationStatus !=
                'pending') {
          throw Exception(
            'This report is not waiting '
            'for completion verification.',
          );
        }

        if (completionImageUrl.isEmpty) {
          throw Exception(
            'Completion evidence is missing '
            'and cannot be approved.',
          );
        }

        final now =
            Timestamp.now();

        transaction.update(
          reportRef,
          {
            'status': 'Resolved',

            'completionVerificationStatus':
                'approved',

            'completionReviewedBy':
                adminUid,

            'completionReviewedAt':
                now,

            'completionRejectionReason':
                '',

            'resolvedAt': now,

            'updatedAt': now,
          },
        );
      },
    );
  }

  // ============================================================
  // ADMIN REJECT COLLECTOR COMPLETION
  // ============================================================

  Future<void> rejectCollectorCompletion({
    required String reportId,
    required String rejectionReason,
  }) async {
    final cleanReason =
        _cleanRequired(
      rejectionReason,
      'Rejection reason',
    );

    final adminUid =
        await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    final reportRef =
        _reportsRef.doc(cleanId);

    await _firestore.runTransaction(
      (transaction) async {
        final reportDoc =
            await transaction.get(
          reportRef,
        );

        if (!reportDoc.exists ||
            reportDoc.data() == null) {
          throw Exception(
            'Report not found.',
          );
        }

        final data =
            reportDoc.data()!;

        final status =
            data['status']
                    ?.toString()
                    .trim() ??
                '';

        final verificationStatus =
            data[
                    'completionVerificationStatus']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

        if (status !=
                'Completion Submitted' ||
            verificationStatus !=
                'pending') {
          throw Exception(
            'This report is not waiting '
            'for completion verification.',
          );
        }

        final now =
            Timestamp.now();

        transaction.update(
          reportRef,
          {
            // Same collector must correct
            // and resubmit the task.
            'status':
                'In Progress',

            'completionVerificationStatus':
                'rejected',

            'completionRejectionReason':
                cleanReason,

            'completionReviewedBy':
                adminUid,

            'completionReviewedAt':
                now,

            'updatedAt': now,
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE REPORT
  // ============================================================

  Future<void> deleteReport(
    String reportId,
  ) async {
    await _requireAdminUid();

    final cleanId =
        _cleanRequired(
      reportId,
      'Report ID',
    );

    await _reportsRef
        .doc(cleanId)
        .delete();
  }

  // ============================================================
  // UPDATE USER PROFILE
  // ============================================================

  Future<void> updateUserProfile(
    String uid,
    String displayName,
    String? photoUrl,
  ) async {
    final currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You must be logged in.',
      );
    }

    final cleanUid =
        _cleanRequired(
      uid,
      'User ID',
    );

    final cleanDisplayName =
        _cleanRequired(
      displayName,
      'Display name',
    );

    final isAdmin =
        await _currentUserIsAdmin();

    if (currentUser.uid != cleanUid &&
        !isAdmin) {
      throw Exception(
        'You can only update your own profile.',
      );
    }

    final Map<String, dynamic> data = {
      // Keep both while older screens/database
      // records may still use either field.
      'name':
          cleanDisplayName,

      'displayName':
          cleanDisplayName,

      'updatedAt':
          Timestamp.now(),
    };

    if (photoUrl != null &&
        photoUrl.trim().isNotEmpty) {
      final cleanPhotoUrl =
          photoUrl.trim();

      // Keep both names synchronized.
      data['photoUrl'] =
          cleanPhotoUrl;

      data['profileImageUrl'] =
          cleanPhotoUrl;
    }

    await _usersRef
        .doc(cleanUid)
        .set(
      data,
      SetOptions(
        merge: true,
      ),
    );
  }
}