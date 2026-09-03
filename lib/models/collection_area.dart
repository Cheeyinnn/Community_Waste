import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionArea {
  final String id;
  final String areaId;

  final String state;
  final String district;

  final String localAuthorityId;
  final String localAuthorityName;

  final String zoneId;
  final String zoneName;
  final String zoneArea;

  final String areaName;
  final String sourceAreaName;

  final List<String> aliases;
  final List<String> landmarks;

  /// Street-name prefixes that can be used for GPS matching.
  ///
  /// Example:
  /// "Jalan Seksyen 4" can match:
  /// - Jalan Seksyen 4/1
  /// - Jalan Seksyen 4/4
  ///
  /// These values are data, not matching logic.
  final List<String> streetPatterns;

  final String scheduleId;

  final bool isActive;

  final String sourceUpdatedDate;
  final String sourceUrl;

  const CollectionArea({
    required this.id,
    required this.areaId,
    required this.state,
    required this.district,
    required this.localAuthorityId,
    required this.localAuthorityName,
    required this.zoneId,
    required this.zoneName,
    required this.zoneArea,
    required this.areaName,
    required this.sourceAreaName,
    required this.aliases,
    required this.landmarks,
    required this.streetPatterns,
    required this.scheduleId,
    required this.isActive,
    required this.sourceUpdatedDate,
    required this.sourceUrl,
  });

  factory CollectionArea.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return CollectionArea(
      id: doc.id,
      areaId: data['areaId']?.toString().trim() ?? doc.id,
      state: data['state']?.toString().trim() ?? '',
      district: data['district']?.toString().trim() ?? '',
      localAuthorityId:
          data['localAuthorityId']?.toString().trim() ?? '',
      localAuthorityName:
          data['localAuthorityName']?.toString().trim() ?? '',
      zoneId: data['zoneId']?.toString().trim() ?? '',
      zoneName: data['zoneName']?.toString().trim() ?? '',
      zoneArea: data['zoneArea']?.toString().trim() ?? '',
      areaName: data['areaName']?.toString().trim() ?? '',
      sourceAreaName:
          data['sourceAreaName']?.toString().trim() ?? '',
      aliases: _parseStringList(data['aliases']),
      landmarks: _parseStringList(data['landmarks']),
      streetPatterns: _parseStringList(data['streetPatterns']),
      scheduleId: data['scheduleId']?.toString().trim() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      sourceUpdatedDate:
          data['sourceUpdatedDate']?.toString().trim() ?? '',
      sourceUrl: data['sourceUrl']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'areaId': areaId,
      'state': state,
      'district': district,
      'localAuthorityId': localAuthorityId,
      'localAuthorityName': localAuthorityName,
      'zoneId': zoneId,
      'zoneName': zoneName,
      'zoneArea': zoneArea,
      'areaName': areaName,
      'sourceAreaName': sourceAreaName,
      'aliases': aliases,
      'landmarks': landmarks,
      'streetPatterns': streetPatterns,
      'scheduleId': scheduleId,
      'isActive': isActive,
      'sourceUpdatedDate': sourceUpdatedDate,
      'sourceUrl': sourceUrl,
    };
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Names intended for normal text search.
  List<String> get searchableNames {
    final names = <String>{
      areaName,
      sourceAreaName,
      ...aliases,
      ...landmarks,
      ...streetPatterns,
    };

    names.removeWhere((name) => name.trim().isEmpty);

    return names.toList();
  }

  /// Names used for strong area/landmark matching before street rules.
  List<String> get directMatchNames {
    final names = <String>{
      areaName,
      sourceAreaName,
      ...aliases,
      ...landmarks,
    };

    names.removeWhere((name) => name.trim().isEmpty);

    return names.toList();
  }

  String get displayName => areaName;

  String get fullLocation {
    final parts = <String>[
      areaName,
      district,
      state,
    ].where((value) => value.trim().isNotEmpty).toList();

    return parts.join(', ');
  }

  String get zoneDisplay {
    if (zoneName.isEmpty) {
      return zoneArea;
    }

    if (zoneArea.isEmpty) {
      return zoneName;
    }

    return '$zoneName - $zoneArea';
  }
}
