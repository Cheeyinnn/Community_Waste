import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;

  final String name;
  final String displayName;
  final String email;
  final String role;

  // Overall account access. Existing users without this field are treated as active.
  final String accountStatus;
  final String accountSuspensionReason;
  final Timestamp? accountSuspendedAt;
  final Timestamp? accountReactivatedAt;

  final String photoUrl;
  final String profileImageUrl;

  final bool emailVerificationRequired;
  final bool emailVerified;

  final Timestamp? emailVerificationStartedAt;
  final Timestamp? emailVerifiedAt;

  final String preferredCollectionAreaId;
  final String preferredCollectionAreaName;
  final Timestamp? preferredCollectionAreaUpdatedAt;

  final String collectorApplicationStatus;
  final Timestamp? collectorApplicationUpdatedAt;

  final List<String> assignedCollectionZoneIds;

  final Timestamp? collectorApprovedAt;

  final bool collectorApprovalAcknowledged;
  final Timestamp? collectorApprovalAcknowledgedAt;

  final Timestamp? updatedAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,

    this.accountStatus = 'active',
    this.accountSuspensionReason = '',
    this.accountSuspendedAt,
    this.accountReactivatedAt,

    this.displayName = '',
    this.photoUrl = '',
    this.profileImageUrl = '',

    this.emailVerificationRequired = false,
    this.emailVerified = false,
    this.emailVerificationStartedAt,
    this.emailVerifiedAt,

    this.preferredCollectionAreaId = '',
    this.preferredCollectionAreaName = '',
    this.preferredCollectionAreaUpdatedAt,

    this.collectorApplicationStatus = '',
    this.collectorApplicationUpdatedAt,

    this.assignedCollectionZoneIds = const [],

    this.collectorApprovedAt,

    this.collectorApprovalAcknowledged = false,
    this.collectorApprovalAcknowledgedAt,

    this.updatedAt,
  });

  // ============================================================
  // FACTORY
  // ============================================================

  factory AppUser.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    final name = _asString(map['name']);

    final displayName = _asString(
      map['displayName'],
      fallback: name,
    );

    final photoUrl = _asString(map['photoUrl']);

    final profileImageUrl = _asString(
      map['profileImageUrl'],
      fallback: photoUrl,
    );

    return AppUser(
      uid: docId,

      name: name,
      displayName: displayName,

      email: _asString(map['email']),

      role: _asString(
        map['role'],
        fallback: 'user',
      ).toLowerCase(),

      accountStatus: _asString(
        map['accountStatus'],
        fallback: 'active',
      ).toLowerCase(),
      accountSuspensionReason: _asString(
        map['accountSuspensionReason'],
      ),
      accountSuspendedAt: _asTimestamp(
        map['accountSuspendedAt'],
      ),
      accountReactivatedAt: _asTimestamp(
        map['accountReactivatedAt'],
      ),

      photoUrl: photoUrl,
      profileImageUrl: profileImageUrl,

      emailVerificationRequired:
          map['emailVerificationRequired'] == true,

      emailVerified:
          map['emailVerified'] == true,

      emailVerificationStartedAt:
          _asTimestamp(
        map['emailVerificationStartedAt'],
      ),

      emailVerifiedAt:
          _asTimestamp(
        map['emailVerifiedAt'],
      ),

      preferredCollectionAreaId:
          _asString(
        map['preferredCollectionAreaId'],
      ),

      preferredCollectionAreaName:
          _asString(
        map['preferredCollectionAreaName'],
      ),

      preferredCollectionAreaUpdatedAt:
          _asTimestamp(
        map['preferredCollectionAreaUpdatedAt'],
      ),

      collectorApplicationStatus:
          _asString(
        map['collectorApplicationStatus'],
      ).toLowerCase(),

      collectorApplicationUpdatedAt:
          _asTimestamp(
        map['collectorApplicationUpdatedAt'],
      ),

      assignedCollectionZoneIds:
          _asStringList(
        map['assignedCollectionZoneIds'],
      ),

      collectorApprovedAt:
          _asTimestamp(
        map['collectorApprovedAt'],
      ),

      collectorApprovalAcknowledged:
          map['collectorApprovalAcknowledged'] == true,

      collectorApprovalAcknowledgedAt:
          _asTimestamp(
        map['collectorApprovalAcknowledgedAt'],
      ),

      updatedAt:
          _asTimestamp(
        map['updatedAt'],
      ),
    );
  }

  // ============================================================
  // FIRESTORE MAP
  // ============================================================
  //
  // The three original fields remain always present so current
  // registration/AuthService code stays compatible.
  //
  // Optional fields are included only when they contain useful
  // values.
  // ============================================================

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'role': role,
      'accountStatus': accountStatus,
    };

    if (accountSuspensionReason.isNotEmpty) {
      data['accountSuspensionReason'] = accountSuspensionReason;
    }

    if (accountSuspendedAt != null) {
      data['accountSuspendedAt'] = accountSuspendedAt;
    }

    if (accountReactivatedAt != null) {
      data['accountReactivatedAt'] = accountReactivatedAt;
    }

    if (displayName.isNotEmpty) {
      data['displayName'] = displayName;
    }

    if (photoUrl.isNotEmpty) {
      data['photoUrl'] = photoUrl;
    }

    if (profileImageUrl.isNotEmpty) {
      data['profileImageUrl'] =
          profileImageUrl;
    }

    if (emailVerificationRequired) {
      data['emailVerificationRequired'] = true;
    }

    if (emailVerified) {
      data['emailVerified'] = true;
    }

    if (emailVerificationStartedAt != null) {
      data['emailVerificationStartedAt'] =
          emailVerificationStartedAt;
    }

    if (emailVerifiedAt != null) {
      data['emailVerifiedAt'] =
          emailVerifiedAt;
    }

    if (preferredCollectionAreaId.isNotEmpty) {
      data['preferredCollectionAreaId'] =
          preferredCollectionAreaId;
    }

    if (preferredCollectionAreaName.isNotEmpty) {
      data['preferredCollectionAreaName'] =
          preferredCollectionAreaName;
    }

    if (preferredCollectionAreaUpdatedAt != null) {
      data['preferredCollectionAreaUpdatedAt'] =
          preferredCollectionAreaUpdatedAt;
    }

    if (collectorApplicationStatus.isNotEmpty) {
      data['collectorApplicationStatus'] =
          collectorApplicationStatus;
    }

    if (collectorApplicationUpdatedAt != null) {
      data['collectorApplicationUpdatedAt'] =
          collectorApplicationUpdatedAt;
    }

    if (assignedCollectionZoneIds.isNotEmpty) {
      data['assignedCollectionZoneIds'] =
          assignedCollectionZoneIds;
    }

    if (collectorApprovedAt != null) {
      data['collectorApprovedAt'] =
          collectorApprovedAt;
    }

    if (collectorApprovalAcknowledged) {
      data['collectorApprovalAcknowledged'] = true;
    }

    if (collectorApprovalAcknowledgedAt != null) {
      data['collectorApprovalAcknowledgedAt'] =
          collectorApprovalAcknowledgedAt;
    }

    if (updatedAt != null) {
      data['updatedAt'] = updatedAt;
    }

    return data;
  }

  // ============================================================
  // CONVENIENCE GETTERS
  // ============================================================

  String get effectiveDisplayName {
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    return name.trim();
  }

  String get effectiveProfileImageUrl {
    if (profileImageUrl.trim().isNotEmpty) {
      return profileImageUrl.trim();
    }

    return photoUrl.trim();
  }

  bool get isAccountSuspended =>
      accountStatus.toLowerCase() == 'suspended';

  bool get isAccountActive => !isAccountSuspended;

  bool get isUser =>
      role.toLowerCase() == 'user';

  bool get isAdmin =>
      role.toLowerCase() == 'admin';

  bool get isCollector =>
      role.toLowerCase() == 'collector';

  bool get isApprovedCollector =>
      isCollector &&
      collectorApplicationStatus == 'approved';

  bool get hasAssignedCollectionZones =>
      assignedCollectionZoneIds.isNotEmpty;

  // ============================================================
  // COPY
  // ============================================================

  AppUser copyWith({
    String? uid,
    String? name,
    String? displayName,
    String? email,
    String? role,
    String? accountStatus,
    String? accountSuspensionReason,
    Timestamp? accountSuspendedAt,
    Timestamp? accountReactivatedAt,
    String? photoUrl,
    String? profileImageUrl,
    bool? emailVerificationRequired,
    bool? emailVerified,
    Timestamp? emailVerificationStartedAt,
    Timestamp? emailVerifiedAt,
    String? preferredCollectionAreaId,
    String? preferredCollectionAreaName,
    Timestamp? preferredCollectionAreaUpdatedAt,
    String? collectorApplicationStatus,
    Timestamp? collectorApplicationUpdatedAt,
    List<String>? assignedCollectionZoneIds,
    Timestamp? collectorApprovedAt,
    bool? collectorApprovalAcknowledged,
    Timestamp? collectorApprovalAcknowledgedAt,
    Timestamp? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      displayName:
          displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      accountSuspensionReason:
          accountSuspensionReason ?? this.accountSuspensionReason,
      accountSuspendedAt:
          accountSuspendedAt ?? this.accountSuspendedAt,
      accountReactivatedAt:
          accountReactivatedAt ?? this.accountReactivatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      profileImageUrl:
          profileImageUrl ??
              this.profileImageUrl,
      emailVerificationRequired:
          emailVerificationRequired ??
              this.emailVerificationRequired,
      emailVerified:
          emailVerified ??
              this.emailVerified,
      emailVerificationStartedAt:
          emailVerificationStartedAt ??
              this.emailVerificationStartedAt,
      emailVerifiedAt:
          emailVerifiedAt ??
              this.emailVerifiedAt,
      preferredCollectionAreaId:
          preferredCollectionAreaId ??
              this.preferredCollectionAreaId,
      preferredCollectionAreaName:
          preferredCollectionAreaName ??
              this.preferredCollectionAreaName,
      preferredCollectionAreaUpdatedAt:
          preferredCollectionAreaUpdatedAt ??
              this.preferredCollectionAreaUpdatedAt,
      collectorApplicationStatus:
          collectorApplicationStatus ??
              this.collectorApplicationStatus,
      collectorApplicationUpdatedAt:
          collectorApplicationUpdatedAt ??
              this.collectorApplicationUpdatedAt,
      assignedCollectionZoneIds:
          assignedCollectionZoneIds ??
              this.assignedCollectionZoneIds,
      collectorApprovedAt:
          collectorApprovedAt ??
              this.collectorApprovedAt,
      collectorApprovalAcknowledged:
          collectorApprovalAcknowledged ??
              this.collectorApprovalAcknowledged,
      collectorApprovalAcknowledgedAt:
          collectorApprovalAcknowledgedAt ??
              this.collectorApprovalAcknowledgedAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
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

  static Timestamp? _asTimestamp(
    dynamic value,
  ) {
    return value is Timestamp ? value : null;
  }

  static List<String> _asStringList(
    dynamic value,
  ) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .map(
          (item) => item.toString().trim(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toSet()
        .toList();
  }
}
