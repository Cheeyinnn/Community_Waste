import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionEvent {
  final String id;

  // ============================================================
  // AREA / SCHEDULE
  // ============================================================

  final String areaId;
  final String areaName;

  final String scheduleId;

  final String zoneId;
  final String zoneName;

  // ============================================================
  // COLLECTION DATE
  //
  // Stored as YYYY-MM-DD, for example:
  // 2026-09-02
  //
  // This avoids timezone problems when finding today's event.
  // ============================================================

  final String collectionDate;

  // ============================================================
  // STATUS
  //
  // pending
  // in_progress
  // collected
  // missed
  // ============================================================

  final String status;

  // ============================================================
  // COLLECTOR
  // ============================================================

  final String collectorId;

  // ============================================================
  // ACTUAL ACTIVITY TIMES
  // ============================================================

  final DateTime? startedAt;
  final DateTime? collectedAt;

  // ============================================================
  // AUDIT
  // ============================================================

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CollectionEvent({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.scheduleId,
    required this.zoneId,
    required this.zoneName,
    required this.collectionDate,
    required this.status,
    required this.collectorId,
    required this.startedAt,
    required this.collectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ============================================================
  // FIRESTORE -> MODEL
  // ============================================================

  factory CollectionEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return CollectionEvent(
      id: doc.id,

      areaId:
          data['areaId']?.toString().trim() ?? '',

      areaName:
          data['areaName']?.toString().trim() ?? '',

      scheduleId:
          data['scheduleId']?.toString().trim() ?? '',

      zoneId:
          data['zoneId']?.toString().trim() ?? '',

      zoneName:
          data['zoneName']?.toString().trim() ?? '',

      collectionDate:
          data['collectionDate']?.toString().trim() ?? '',

      status:
          data['status']?.toString().trim() ?? 'pending',

      collectorId:
          data['collectorId']?.toString().trim() ?? '',

      startedAt:
          _timestampToDateTime(data['startedAt']),

      collectedAt:
          _timestampToDateTime(data['collectedAt']),

      createdAt:
          _timestampToDateTime(data['createdAt']),

      updatedAt:
          _timestampToDateTime(data['updatedAt']),
    );
  }

  // ============================================================
  // MODEL -> FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'areaId': areaId,
      'areaName': areaName,

      'scheduleId': scheduleId,

      'zoneId': zoneId,
      'zoneName': zoneName,

      'collectionDate': collectionDate,

      'status': status,

      'collectorId': collectorId,

      'startedAt': startedAt == null
          ? null
          : Timestamp.fromDate(startedAt!),

      'collectedAt': collectedAt == null
          ? null
          : Timestamp.fromDate(collectedAt!),

      'createdAt': createdAt == null
          ? null
          : Timestamp.fromDate(createdAt!),

      'updatedAt': updatedAt == null
          ? null
          : Timestamp.fromDate(updatedAt!),
    };
  }

  // ============================================================
  // TIMESTAMP HELPER
  // ============================================================

  static DateTime? _timestampToDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  bool get isPending {
    return status == 'pending';
  }

  bool get isInProgress {
    return status == 'in_progress';
  }

  bool get isCollected {
    return status == 'collected';
  }

  bool get isMissed {
    return status == 'missed';
  }

  // ============================================================
  // STATUS DISPLAY NAME
  // ============================================================

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Pending';

      case 'in_progress':
        return 'Collection In Progress';

      case 'collected':
        return 'Collected';

      case 'missed':
        return 'Missed';

      default:
        return 'Unknown';
    }
  }
}