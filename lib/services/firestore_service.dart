import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/waste_report.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection('reports');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  List<WasteReport> _mapSnapshotToWasteReports(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createReport(WasteReport report) async {
    final data = report.toMap();
    data['priority'] ??= 'Medium';
    data['updatedAt'] ??= data['createdAt'] ?? Timestamp.now();

    await _reportsRef.add(data);
  }

  Future<List<WasteReport>> findPotentialDuplicateReports({
    required String wasteType,
    Duration withinDuration = const Duration(hours: 24),
    int maxResults = 50,
  }) async {
    final cutoff = DateTime.now().subtract(withinDuration);

    final snapshot = await _reportsRef
        .where('wasteType', isEqualTo: wasteType)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .limit(maxResults)
        .get();

    return snapshot.docs
        .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<WasteReport>> findNearbyDuplicateCandidates({
    required String wasteType,
    required double latitude,
    required double longitude,
    Duration withinDuration = const Duration(hours: 24),
    double radiusMeters = 100,
    int maxResults = 50,
  }) async {
    final recentReports = await findPotentialDuplicateReports(
      wasteType: wasteType,
      withinDuration: withinDuration,
      maxResults: maxResults,
    );

    return recentReports.where((report) {
      if (report.latitude == 0.0 && report.longitude == 0.0) {
        return false;
      }

      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        report.latitude,
        report.longitude,
      );

      return distance <= radiusMeters;
    }).toList();
  }

  Future<int> getRecentReportCountByArea(String area) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snapshot = await _reportsRef
        .where('area', isEqualTo: area.trim())
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
        )
        .get();

    return snapshot.docs.length;
  }

  Future<String> getAutoPriorityByArea(String area) async {
    final existingCount = await getRecentReportCountByArea(area);
    final totalAfterSubmit = existingCount + 1;

    if (totalAfterSubmit >= 3) {
      return 'High';
    } else if (totalAfterSubmit == 2) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  Stream<List<WasteReport>> getUserReports(String userId) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Stream<List<WasteReport>> getAllReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Stream<List<WasteReport>> getReportsByStatus(String status) {
    return _reportsRef
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Stream<List<WasteReport>> getCollectorReports(String collectorId) {
    return _reportsRef
        .where('collectorId', isEqualTo: collectorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Stream<List<WasteReport>> getCollectorReportsByDateRange({
    required String collectorId,
    required DateTime start,
    required DateTime end,
  }) {
    return _reportsRef
        .where('collectorId', isEqualTo: collectorId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Future<WasteReport?> getReportById(String reportId) async {
    final doc = await _reportsRef.doc(reportId).get();
    final data = doc.data();

    if (!doc.exists || data == null) return null;

    return WasteReport.fromMap(data, doc.id);
  }

  Stream<int> getUserReportCount(String userId) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getUserReportCountByStatus(String userId, String status) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<WasteReport>> getRecentUserActivities(String userId) {
    return _reportsRef.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final reports = _mapSnapshotToWasteReports(snapshot);

      reports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return reports.take(5).toList();
    });
  }

  Stream<List<WasteReport>> getRecentUserReports(String userId) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map(_mapSnapshotToWasteReports);
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    await _reportsRef.doc(reportId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateReportPriority({
    required String reportId,
    required String priority,
  }) async {
    await _reportsRef.doc(reportId).update({
      'priority': priority,
      'updatedAt': Timestamp.now(),
    });
  }

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
    final Map<String, dynamic> data = {
      'title': title,
      'description': description,
      'location': location,
      'area': area,
      'wasteType': wasteType,
      'updatedAt': Timestamp.now(),
    };

    if (priority != null) data['priority'] = priority;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    await _reportsRef.doc(reportId).update(data);
  }

  Future<void> assignCollector({
    required String reportId,
    required String collectorId,
    required String collectorName,
    String adminRemark = '',
    String? priority,
  }) async {
    final Map<String, dynamic> data = {
      'collectorId': collectorId,
      'collectorName': collectorName,
      'status': 'Assigned',
      'adminRemark': adminRemark,
      'updatedAt': Timestamp.now(),
    };

    if (priority != null) data['priority'] = priority;

    await _reportsRef.doc(reportId).update(data);
  }

  Future<void> removeCollector({required String reportId}) async {
    await _reportsRef.doc(reportId).update({
      'collectorId': '',
      'collectorName': '',
      'status': 'Pending',
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> rejectReport({
    required String reportId,
    required String adminRemark,
    String? priority,
  }) async {
    final Map<String, dynamic> data = {
      'status': 'Rejected',
      'adminRemark': adminRemark,
      'updatedAt': Timestamp.now(),
    };

    if (priority != null) data['priority'] = priority;

    await _reportsRef.doc(reportId).update(data);
  }

  Future<void> verifyReport({
    required String reportId,
    String adminRemark = 'Report verified by admin',
  }) async {
    await _reportsRef.doc(reportId).update({
      'adminRemark': adminRemark,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> startCollectorTask({
    required String reportId,
    String collectorRemark = '',
  }) async {
    await _reportsRef.doc(reportId).update({
      'status': 'In Progress',
      'collectorRemark': collectorRemark,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> completeCollectorTask({
    required String reportId,
    required String collectorRemark,
    required String completionImageUrl,
  }) async {
    await _reportsRef.doc(reportId).update({
      'status': 'Resolved',
      'collectorRemark': collectorRemark,
      'completionImageUrl': completionImageUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteReport(String reportId) async {
    await _reportsRef.doc(reportId).delete();
  }

  Future<void> updateUserProfile(
    String uid,
    String displayName,
    String? photoUrl,
  ) async {
    final Map<String, dynamic> data = {
      'displayName': displayName,
      'updatedAt': Timestamp.now(),
    };

    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photoUrl'] = photoUrl;
    }

    await _usersRef.doc(uid).set(data, SetOptions(merge: true));
  }
}
