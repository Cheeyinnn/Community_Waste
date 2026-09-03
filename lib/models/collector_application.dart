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
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusDisplayName {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }
}
