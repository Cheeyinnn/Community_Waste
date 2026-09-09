import 'package:cloud_firestore/cloud_firestore.dart';

class CollectorApplication {
  final String id;
  final String userId;
  final String applicantName;
  final String email;
  final String phone;
  final String preferredArea;
  final String experience;
  final String reason;
  final String status;
  final String reviewedBy;
  final String adminRemark;
  final List<String> assignedCollectionZoneIds;
  final Timestamp? submittedAt;
  final Timestamp? reviewedAt;

  final Timestamp? suspendedAt;
  final String suspendedBy;
  final String suspensionReason;

  final Timestamp? reactivatedAt;
  final String reactivatedBy;

  final Timestamp? demotedAt;
  final String demotedBy;
  final String demotionReason;

  const CollectorApplication({
    required this.id,
    required this.userId,
    required this.applicantName,
    required this.email,
    required this.phone,
    required this.preferredArea,
    required this.experience,
    required this.reason,
    required this.status,
    required this.reviewedBy,
    required this.adminRemark,
    required this.assignedCollectionZoneIds,
    required this.submittedAt,
    required this.reviewedAt,
    required this.suspendedAt,
    required this.suspendedBy,
    required this.suspensionReason,
    required this.reactivatedAt,
    required this.reactivatedBy,
    required this.demotedAt,
    required this.demotedBy,
    required this.demotionReason,
  });

  factory CollectorApplication.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawZones = data['assignedCollectionZoneIds'];

    return CollectorApplication(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      applicantName: data['applicantName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      preferredArea: data['preferredArea']?.toString() ?? '',
      experience: data['experience']?.toString() ?? '',
      reason: data['reason']?.toString() ?? '',
      status:
          data['status']?.toString().trim().toLowerCase() ?? 'pending',
      reviewedBy: data['reviewedBy']?.toString() ?? '',
      adminRemark: data['adminRemark']?.toString() ?? '',
      assignedCollectionZoneIds: rawZones is Iterable
          ? rawZones
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : const <String>[],
      submittedAt: data['submittedAt'] is Timestamp
          ? data['submittedAt'] as Timestamp
          : null,
      reviewedAt: data['reviewedAt'] is Timestamp
          ? data['reviewedAt'] as Timestamp
          : null,
      suspendedAt: data['suspendedAt'] is Timestamp
          ? data['suspendedAt'] as Timestamp
          : null,
      suspendedBy: data['suspendedBy']?.toString() ?? '',
      suspensionReason: data['suspensionReason']?.toString() ?? '',
      reactivatedAt: data['reactivatedAt'] is Timestamp
          ? data['reactivatedAt'] as Timestamp
          : null,
      reactivatedBy: data['reactivatedBy']?.toString() ?? '',
      demotedAt: data['demotedAt'] is Timestamp
          ? data['demotedAt'] as Timestamp
          : null,
      demotedBy: data['demotedBy']?.toString() ?? '',
      demotionReason: data['demotionReason']?.toString() ?? '',
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
  bool get isDemoted => status == 'demoted';

  String get statusDisplayName {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      case 'demoted':
        return 'Demoted';
      case 'pending':
      default:
        return 'Pending';
    }
  }
}
