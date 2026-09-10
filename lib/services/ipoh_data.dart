import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore seeder for Ipoh collection-zone coverage.
///
/// Service information sources:
/// - Majlis Bandaraya Ipoh waste-management frequency:
///   https://www.mbi.gov.my/index.php/perkhidmatan?catid=2&id=263&view=article
/// - MBI published service-zone list:
///   https://www.mbi.gov.my/sumber/muat-turun-dokumen?catid=27&id=350&view=article
///
/// MBI publishes domestic and industrial collection three times weekly, using
/// either Monday/Wednesday/Friday or Tuesday/Thursday/Saturday. The application
/// stores one recurring schedule for each supported service zone so collection
/// information can be used consistently by Users, Admins and Collectors.
///
/// MBI waste-collection operating hours have also been publicly reported as
/// 7:00 AM to 7:00 PM. The schedule records therefore use 07:00-19:00 as the
/// service operating window shown in the application.
class IpohData {
  IpohData._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _state = 'Perak';
  static const String _district = 'Ipoh';
  static const String _localAuthorityId = 'mbi_ipoh';
  static const String _localAuthorityName = 'Majlis Bandaraya Ipoh';
  static const String _sourceUpdatedDate = '2026-09-04';

  static const String _scheduleSourceUrl =
      'https://www.mbi.gov.my/index.php/perkhidmatan?catid=2&id=263&view=article';

  static const String _zoneSourceUrl =
      'https://www.mbi.gov.my/sumber/muat-turun-dokumen?catid=27&id=350&view=article';

  static const String _scheduleNote =
      'Please place household waste at the designated collection point before '
      'the scheduled collection period begins.';

  /// Creates/updates only MBI Ipoh documents. Existing Kampar documents are
  /// preserved. Safe to run repeatedly.
  static Future<void> seedOrUpdate() async {
    final batch = _db.batch();

    for (final zone in _zones) {
      final scheduleId = '${zone.zoneId}_${zone.scheduleType}';

      final scheduleRef =
          _db.collection('collection_schedules').doc(scheduleId);

      batch.set(
        scheduleRef,
        <String, dynamic>{
          'scheduleId': scheduleId,
          'state': _state,
          'district': _district,
          'localAuthorityId': _localAuthorityId,
          'localAuthorityName': _localAuthorityName,
          'zoneId': zone.zoneId,
          'zoneName': zone.zoneName,
          'zoneArea': zone.zoneArea,
          'scheduleType': zone.scheduleType,
          'daysOfWeek': zone.daysOfWeek,
          'startHour': 7,
          'startMinute': 0,
          'endHour': 19,
          'endMinute': 0,
          'serviceType': 'Waste Collection',
          'scheduleNote': _scheduleNote,
          'scheduleBasis': 'service_schedule',
          'officialServiceFrequency':
              _officialFrequencyFor(zone.scheduleType),
          'patternVerifiedByAuthority': false,
          'timeVerifiedByAuthority': true,
          'exactScheduleAvailable': true,
          'isActive': true,
          'sourceUpdatedDate': _sourceUpdatedDate,
          'sourceUrl': _scheduleSourceUrl,
        },
        SetOptions(merge: true),
      );

      final areaId = zone.zoneId;
      final areaRef = _db.collection('collection_areas').doc(areaId);

      batch.set(
        areaRef,
        <String, dynamic>{
          'areaId': areaId,
          'state': _state,
          'district': _district,
          'localAuthorityId': _localAuthorityId,
          'localAuthorityName': _localAuthorityName,
          'zoneId': zone.zoneId,
          'zoneName': zone.zoneName,
          'zoneArea': zone.zoneArea,
          'areaName': zone.zoneName,
          'sourceAreaName': zone.zoneName,
          'aliases': zone.aliases,
          'landmarks': <String>[],
          'streetPatterns': zone.streetPatterns,
          'scheduleId': scheduleId,
          'isActive': true,
          'sourceUpdatedDate': _sourceUpdatedDate,
          'sourceUrl': _zoneSourceUrl,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Recreates only the MBI Ipoh dataset. Kampar is never deleted.
  ///
  /// Two cleanup passes are intentional:
  /// 1. localAuthorityId clears the current MBI schema.
  /// 2. district clears older Ipoh seed documents created before the
  ///    localAuthorityId field was standardised.
  static Future<void> resetAndSeed() async {
    await _clearWhere(
      'collection_areas',
      field: 'localAuthorityId',
      value: _localAuthorityId,
    );
    await _clearWhere(
      'collection_schedules',
      field: 'localAuthorityId',
      value: _localAuthorityId,
    );
    await _clearWhere(
      'collection_areas',
      field: 'district',
      value: _district,
    );
    await _clearWhere(
      'collection_schedules',
      field: 'district',
      value: _district,
    );
    await seedOrUpdate();
  }

  static Future<void> _clearWhere(
    String collectionName, {
    required String field,
    required String value,
  }) async {
    while (true) {
      final snapshot = await _db
          .collection(collectionName)
          .where(field, isEqualTo: value)
          .limit(400)
          .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  static String _officialFrequencyFor(String scheduleType) {
    if (scheduleType.toLowerCase() == 'daily') {
      return 'Daily';
    }

    return '3 times weekly';
  }

  static const List<_IpohZoneSeed> _zones = [
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_bercham',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Bercham',
      zoneArea: 'Ipoh - Bercham',
      aliases: [
        'Zon Bercham',
        'Bercham Ipoh',
        'Taman Sri Bercham',
        'Bandar Baru Bercham',
        'Pusat Bandar Baru Bercham',
        'Kampung Baru Bercham',
      ],
      streetPatterns: ['Jalan Bercham'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_buntong',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Buntong',
      zoneArea: 'Ipoh - Buntong',
      aliases: ['Zon Buntong', 'Buntong Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_chempaka',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Chempaka',
      zoneArea: 'Ipoh - Chempaka',
      aliases: [
        'Zon Chempaka',
        'Cempaka',
        'Zon Cempaka',
        'Taman Cempaka',
        'Taman Chempaka',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_chemor',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Chemor',
      zoneArea: 'Ipoh - Chemor',
      aliases: [
        'Zon Chemor',
        'Chemor Ipoh',
        'Klebang',
        'Bandar Baru Sri Klebang',
        'Chepor',
        'Kanthan',
      ],
      streetPatterns: ['Jalan Besar Chemor'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_cherry',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Cherry',
      zoneArea: 'Ipoh - Cherry',
      aliases: ['Zon Cherry', 'Taman Cherry', 'Cherry Park'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_gunung_rapat',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Gunung Rapat',
      zoneArea: 'Ipoh - Gunung Rapat',
      aliases: ['Zon Gunung Rapat', 'Gunung Rapat Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_happy_garden',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Happy Garden',
      zoneArea: 'Ipoh - Happy Garden',
      aliases: ['Zon Happy Garden', 'Happy Garden Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_housing_trust',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Housing Trust',
      zoneArea: 'Ipoh - Housing Trust',
      aliases: ['Zon Housing Trust', 'Housing Trust Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_jelapang',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Jelapang',
      zoneArea: 'Ipoh - Jelapang / Meru',
      aliases: [
        'Zon Jelapang',
        'Jelapang Ipoh',
        'Meru',
        'Taman Meru',
        'Meru Heights',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_lahat',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Lahat',
      zoneArea: 'Ipoh - Lahat',
      aliases: ['Zon Lahat', 'Lahat Ipoh', 'Taman Lahat'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_manjoi',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Manjoi',
      zoneArea: 'Ipoh - Manjoi',
      aliases: ['Zon Manjoi', 'Manjoi Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_menglembu',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Menglembu',
      zoneArea: 'Ipoh - Menglembu',
      aliases: ['Zon Menglembu', 'Menglembu Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_pasir_pinji',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Pasir Pinji',
      zoneArea: 'Ipoh - Pasir Pinji',
      aliases: [
        'Zon Pasir Pinji',
        'Pasir Pinji Ipoh',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_pekan_lama_baru',
      scheduleType: 'daily',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      zoneName: 'Pekan Lama & Baru',
      zoneArea: 'Ipoh - Old Town / New Town',
      aliases: [
        'Zon Pekan Lama',
        'Zon Pekan Baru',
        'Pekan Lama Ipoh',
        'Pekan Baru Ipoh',
        'Ipoh Old Town',
        'Ipoh New Town',
        'Old Town Ipoh',
        'New Town Ipoh',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_simee_canning',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Simee Canning',
      zoneArea: 'Ipoh - Simee / Canning',
      aliases: [
        'Zon Simee Canning',
        'Simee',
        'Taman Simee',
        'Canning',
        'Canning Garden',
        'Taman Canning',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_simpang_pulai',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Simpang Pulai',
      zoneArea: 'Ipoh - Simpang Pulai',
      aliases: ['Zon Simpang Pulai', 'Simpang Pulai Ipoh'],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_tambun',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Tambun',
      zoneArea: 'Ipoh - Tambun',
      aliases: [
        'Zon Tambun',
        'Tambun Ipoh',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_tanjung_rambutan',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
      zoneName: 'Tanjung Rambutan',
      zoneArea: 'Ipoh - Tanjung Rambutan',
      aliases: [
        'Zon Tanjung Rambutan',
        'Tanjung Rambutan Ipoh',
        'Tg Rambutan',
        'Tg. Rambutan',
      ],
    ),
    _IpohZoneSeed(
      zoneId: 'ipoh_zone_tasek',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
      zoneName: 'Tasek',
      zoneArea: 'Ipoh - Tasek',
      aliases: [
        'Zon Tasek',
        'Tasek Ipoh',
        'Taman Tasek',
        'Bandar Baru Tasek',
      ],
    ),
  ];
}

class _IpohZoneSeed {
  final String zoneId;
  final String zoneName;
  final String zoneArea;
  final String scheduleType;
  final List<int> daysOfWeek;
  final List<String> aliases;
  final List<String> streetPatterns;

  const _IpohZoneSeed({
    required this.zoneId,
    required this.zoneName,
    required this.zoneArea,
    required this.scheduleType,
    required this.daysOfWeek,
    this.aliases = const [],
    this.streetPatterns = const [],
  });
}
