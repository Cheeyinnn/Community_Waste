import 'package:cloud_firestore/cloud_firestore.dart';

class WasteReport {
  final String id;
  final String userId;
  final String userName;

  final String title;
  final String description;

  /// Full address used for display/navigation.
  final String location;

  /// Grouped area used for analytics/hotspot/priority.
  final String area;

  final String wasteType;
  final String imageUrl;

  final String status;
  final String priority;

  final String collectorId;
  final String collectorName;

  final String adminRemark;
  final String collectorRemark;

  final String completionImageUrl;

  /// Collector completion review state:
  /// '', 'pending', 'approved', or 'rejected'.
  final String completionVerificationStatus;

  final String completionRejectionReason;
  final String completionReviewedBy;

  final Timestamp? completionSubmittedAt;
  final Timestamp? completionReviewedAt;
  final Timestamp? resolvedAt;

  final double latitude;
  final double longitude;

  final Timestamp createdAt;
  final Timestamp updatedAt;

  const WasteReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.location,
    required this.area,
    required this.wasteType,
    required this.imageUrl,
    required this.status,
    required this.priority,
    required this.collectorId,
    required this.collectorName,
    required this.adminRemark,
    required this.collectorRemark,
    required this.completionImageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,

    // Final collector-completion workflow fields.
    this.completionVerificationStatus = '',
    this.completionRejectionReason = '',
    this.completionReviewedBy = '',
    this.completionSubmittedAt,
    this.completionReviewedAt,
    this.resolvedAt,
  });

  // ============================================================
  // FACTORY
  // ============================================================

  factory WasteReport.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    final rawLatitude = map['latitude'];
    final rawLongitude = map['longitude'];

    final rawCreatedAt = map['createdAt'];
    final rawUpdatedAt = map['updatedAt'];

    return WasteReport(
      id: docId,

      userId: _asString(map['userId']),
      userName: _asString(map['userName']),

      title: _asString(map['title']),
      description: _asString(map['description']),

      location: _asString(map['location']),
      area: _asString(map['area']),

      wasteType: _asString(map['wasteType']),
      imageUrl: _asString(map['imageUrl']),

      status: _asString(
        map['status'],
        fallback: 'Pending',
      ),

      priority: _asString(
        map['priority'],
        fallback: 'Medium',
      ),

      collectorId: _asString(map['collectorId']),
      collectorName: _asString(map['collectorName']),

      adminRemark: _asString(map['adminRemark']),
      collectorRemark: _asString(map['collectorRemark']),

      completionImageUrl:
          _asString(map['completionImageUrl']),

      completionVerificationStatus:
          _asString(map['completionVerificationStatus']),

      completionRejectionReason:
          _asString(map['completionRejectionReason']),

      completionReviewedBy:
          _asString(map['completionReviewedBy']),

      completionSubmittedAt:
          _asTimestamp(map['completionSubmittedAt']),

      completionReviewedAt:
          _asTimestamp(map['completionReviewedAt']),

      resolvedAt:
          _asTimestamp(map['resolvedAt']),

      latitude:
          rawLatitude is num ? rawLatitude.toDouble() : 0.0,

      longitude:
          rawLongitude is num ? rawLongitude.toDouble() : 0.0,

      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt
          : Timestamp.now(),

      updatedAt: rawUpdatedAt is Timestamp
          ? rawUpdatedAt
          : rawCreatedAt is Timestamp
              ? rawCreatedAt
              : Timestamp.now(),
    );
  }

  // ============================================================
  // FIRESTORE MAP
  // ============================================================
  //
  // Base report fields are always written.
  //
  // Collector completion-review fields are written only when
  // they contain meaningful data. This keeps newly-created
  // Pending reports compatible with the existing Firestore
  // structure and security rules.
  // ============================================================

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location,
      'area': area,
      'wasteType': wasteType,
      'imageUrl': imageUrl,
      'status': status,
      'priority': priority,
      'collectorId': collectorId,
      'collectorName': collectorName,
      'adminRemark': adminRemark,
      'collectorRemark': collectorRemark,
      'completionImageUrl': completionImageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

    if (completionVerificationStatus.isNotEmpty) {
      data['completionVerificationStatus'] =
          completionVerificationStatus;
    }

    if (completionRejectionReason.isNotEmpty) {
      data['completionRejectionReason'] =
          completionRejectionReason;
    }

    if (completionReviewedBy.isNotEmpty) {
      data['completionReviewedBy'] =
          completionReviewedBy;
    }

    if (completionSubmittedAt != null) {
      data['completionSubmittedAt'] =
          completionSubmittedAt;
    }

    if (completionReviewedAt != null) {
      data['completionReviewedAt'] =
          completionReviewedAt;
    }

    if (resolvedAt != null) {
      data['resolvedAt'] = resolvedAt;
    }

    return data;
  }

  // ============================================================
  // CONVENIENCE GETTERS
  // ============================================================

  bool get isPending => status == 'Pending';

  bool get isAssigned => status == 'Assigned';

  bool get isInProgress => status == 'In Progress';

  bool get isCompletionSubmitted =>
      status == 'Completion Submitted';

  bool get isResolved => status == 'Resolved';

  bool get isRejected => status == 'Rejected';

  bool get hasCollector =>
      collectorId.trim().isNotEmpty;

  bool get hasCompletionEvidence =>
      completionImageUrl.trim().isNotEmpty;

  bool get completionAwaitingReview =>
      isCompletionSubmitted &&
      completionVerificationStatus.toLowerCase() == 'pending';

  bool get completionApproved =>
      completionVerificationStatus.toLowerCase() == 'approved';

  bool get completionRejected =>
      completionVerificationStatus.toLowerCase() == 'rejected';

  // ============================================================
  // COPY
  // ============================================================

  WasteReport copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    String? location,
    String? area,
    String? wasteType,
    String? imageUrl,
    String? status,
    String? priority,
    String? collectorId,
    String? collectorName,
    String? adminRemark,
    String? collectorRemark,
    String? completionImageUrl,
    String? completionVerificationStatus,
    String? completionRejectionReason,
    String? completionReviewedBy,
    Timestamp? completionSubmittedAt,
    Timestamp? completionReviewedAt,
    Timestamp? resolvedAt,
    double? latitude,
    double? longitude,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return WasteReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      area: area ?? this.area,
      wasteType: wasteType ?? this.wasteType,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      collectorId: collectorId ?? this.collectorId,
      collectorName: collectorName ?? this.collectorName,
      adminRemark: adminRemark ?? this.adminRemark,
      collectorRemark: collectorRemark ?? this.collectorRemark,
      completionImageUrl:
          completionImageUrl ?? this.completionImageUrl,
      completionVerificationStatus:
          completionVerificationStatus ??
              this.completionVerificationStatus,
      completionRejectionReason:
          completionRejectionReason ??
              this.completionRejectionReason,
      completionReviewedBy:
          completionReviewedBy ??
              this.completionReviewedBy,
      completionSubmittedAt:
          completionSubmittedAt ??
              this.completionSubmittedAt,
      completionReviewedAt:
          completionReviewedAt ??
              this.completionReviewedAt,
      resolvedAt:
          resolvedAt ?? this.resolvedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // PARSING HELPERS
  // ============================================================

  static String _asString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString();

    return result.isEmpty ? fallback : result;
  }

  static Timestamp? _asTimestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }
}
