import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionSchedule {
  final String id;
  final String scheduleId;

  final String state;
  final String district;

  final String localAuthorityId;
  final String localAuthorityName;

  final String zoneId;
  final String zoneName;
  final String zoneArea;

  final String scheduleType;
  final List<int> daysOfWeek;

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  final String serviceType;
  final String scheduleNote;

  /// Describes where the exact day/time configuration came from.
  ///
  /// Values used by the built-in datasets:
  /// - official_authority_schedule
  /// - service_schedule
  final String scheduleBasis;

  /// Human-readable frequency confirmed by the authority source.
  final String officialServiceFrequency;

  /// Whether the exact recurring weekday mapping is confirmed by the authority.
  final bool patternVerifiedByAuthority;

  /// Whether the displayed time window is confirmed by the authority for this
  /// exact service.
  final bool timeVerifiedByAuthority;

  /// True when the application has enough configured data to calculate a next
  /// collection and run the Collection Run workflow.
  final bool exactScheduleAvailable;

  final bool isActive;

  final String sourceUpdatedDate;
  final String sourceUrl;

  const CollectionSchedule({
    required this.id,
    required this.scheduleId,
    required this.state,
    required this.district,
    required this.localAuthorityId,
    required this.localAuthorityName,
    required this.zoneId,
    required this.zoneName,
    required this.zoneArea,
    required this.scheduleType,
    required this.daysOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.serviceType,
    required this.scheduleNote,
    required this.scheduleBasis,
    required this.officialServiceFrequency,
    required this.patternVerifiedByAuthority,
    required this.timeVerifiedByAuthority,
    required this.exactScheduleAvailable,
    required this.isActive,
    required this.sourceUpdatedDate,
    required this.sourceUrl,
  });

  factory CollectionSchedule.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return CollectionSchedule(
      id: doc.id,
      scheduleId: data['scheduleId']?.toString().trim() ?? doc.id,
      state: data['state']?.toString().trim() ?? '',
      district: data['district']?.toString().trim() ?? '',
      localAuthorityId:
          data['localAuthorityId']?.toString().trim() ?? '',
      localAuthorityName:
          data['localAuthorityName']?.toString().trim() ?? '',
      zoneId: data['zoneId']?.toString().trim() ?? '',
      zoneName: data['zoneName']?.toString().trim() ?? '',
      zoneArea: data['zoneArea']?.toString().trim() ?? '',
      scheduleType: data['scheduleType']?.toString().trim() ?? '',
      daysOfWeek: _parseDaysOfWeek(data['daysOfWeek']),
      startHour: (data['startHour'] as num?)?.toInt() ?? 6,
      startMinute: (data['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (data['endHour'] as num?)?.toInt() ?? 17,
      endMinute: (data['endMinute'] as num?)?.toInt() ?? 0,
      serviceType:
          data['serviceType']?.toString().trim() ?? 'Waste Collection',
      scheduleNote: data['scheduleNote']?.toString().trim() ?? '',
      scheduleBasis:
          data['scheduleBasis']?.toString().trim() ?? 'official_authority_schedule',
      officialServiceFrequency:
          data['officialServiceFrequency']?.toString().trim() ?? '',
      patternVerifiedByAuthority:
          data['patternVerifiedByAuthority'] as bool? ?? true,
      timeVerifiedByAuthority:
          data['timeVerifiedByAuthority'] as bool? ?? true,
      exactScheduleAvailable:
          data['exactScheduleAvailable'] as bool? ?? true,
      isActive: data['isActive'] as bool? ?? true,
      sourceUpdatedDate:
          data['sourceUpdatedDate']?.toString().trim() ?? '',
      sourceUrl: data['sourceUrl']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'state': state,
      'district': district,
      'localAuthorityId': localAuthorityId,
      'localAuthorityName': localAuthorityName,
      'zoneId': zoneId,
      'zoneName': zoneName,
      'zoneArea': zoneArea,
      'scheduleType': scheduleType,
      'daysOfWeek': daysOfWeek,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'serviceType': serviceType,
      'scheduleNote': scheduleNote,
      'scheduleBasis': scheduleBasis,
      'officialServiceFrequency': officialServiceFrequency,
      'patternVerifiedByAuthority': patternVerifiedByAuthority,
      'timeVerifiedByAuthority': timeVerifiedByAuthority,
      'exactScheduleAvailable': exactScheduleAvailable,
      'isActive': isActive,
      'sourceUpdatedDate': sourceUpdatedDate,
      'sourceUrl': sourceUrl,
    };
  }

  static List<int> _parseDaysOfWeek(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final days = <int>{};

    for (final item in value) {
      if (item is num) {
        final day = item.toInt();

        if (day >= 1 && day <= 7) {
          days.add(day);
        }
      } else {
        final day = int.tryParse(item.toString());

        if (day != null && day >= 1 && day <= 7) {
          days.add(day);
        }
      }
    }

    final result = days.toList()..sort();

    return result;
  }


  bool get isAuthorityVerifiedExactSchedule {
    return scheduleBasis == 'official_authority_schedule' &&
        patternVerifiedByAuthority &&
        timeVerifiedByAuthority;
  }

  bool get isConfiguredServiceSchedule {
    return scheduleBasis == 'service_schedule' ||
        scheduleBasis == 'configured_service_schedule';
  }

  String get scheduleBasisLabel {
    if (isAuthorityVerifiedExactSchedule) {
      return 'Official authority schedule';
    }

    if (isConfiguredServiceSchedule) {
      return 'Collection service schedule';
    }

    return 'Collection schedule';
  }

  bool collectsOnDay(int dayOfWeek) {
    return daysOfWeek.contains(dayOfWeek);
  }

  bool get isDaily {
    return daysOfWeek.length == 7;
  }

  String get scheduleDisplayName {
    switch (scheduleType.toLowerCase()) {
      case 'daily':
        return 'Daily';

      case 'mwf':
        return 'Monday, Wednesday & Friday';

      case 'tts':
        return 'Tuesday, Thursday & Saturday';

      case 'three_times_weekly_variable':
        return '3 times weekly';

      default:
        return scheduleType.isEmpty
            ? 'Collection Schedule'
            : scheduleType;
    }
  }
}
