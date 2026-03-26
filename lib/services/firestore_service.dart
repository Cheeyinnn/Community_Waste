import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/waste_report.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection('reports');

  Future<void> createReport(WasteReport report) async {
    await _reportsRef.add(report.toMap());
  }

  Stream<List<WasteReport>> getUserReports(String userId) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<WasteReport>> getAllReports() {
    return _reportsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<WasteReport>> getReportsByStatus(String status) {
    return _reportsRef
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<WasteReport>> getCollectorReports(String collectorId) {
    return _reportsRef
        .where('collectorId', isEqualTo: collectorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WasteReport.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<WasteReport?> getReportById(String reportId) async {
    final doc = await _reportsRef.doc(reportId).get();
    if (!doc.exists || doc.data() == null) return null;
    return WasteReport.fromMap(doc.data()!, doc.id);
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

  Future<void> updateReport({
    required String reportId,
    required String title,
    required String description,
    required String location,
    required String wasteType,
    double? latitude,
    double? longitude,
  }) async {
    final data = {
      'title': title,
      'description': description,
      'location': location,
      'wasteType': wasteType,
      'updatedAt': Timestamp.now(),
    };

    if (latitude != null) {
      data['latitude'] = latitude;
    }
    if (longitude != null) {
      data['longitude'] = longitude;
    }

    await _reportsRef.doc(reportId).update(data);
  }

  Future<void> assignCollector({
    required String reportId,
    required String collectorId,
    required String collectorName,
    String adminRemark = '',
  }) async {
    await _reportsRef.doc(reportId).update({
      'collectorId': collectorId,
      'collectorName': collectorName,
      'status': 'Assigned',
      'adminRemark': adminRemark,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> removeCollector({
    required String reportId,
  }) async {
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
  }) async {
    await _reportsRef.doc(reportId).update({
      'status': 'Rejected',
      'adminRemark': adminRemark,
      'updatedAt': Timestamp.now(),
    });
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
}