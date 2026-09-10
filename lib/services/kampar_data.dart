import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time Firestore seeder for the verified Majlis Daerah Kampar
/// waste-collection schedule.
///
/// Source:
/// https://www.mdkampar.gov.my/index.php/perkhidmatan?catid=2&id=263&view=article
///
/// Official posters are dated 1 September 2021.
/// Keep this file as the source dataset for Kampar. Do not call resetAndSeed
/// during normal app startup.
class KamparData {
  KamparData._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _state = 'Perak';
  static const String _district = 'Kampar';
  static const String _localAuthorityId = 'md_kampar';
  static const String _localAuthorityName = 'Majlis Daerah Kampar';
  static const String _sourceUpdatedDate = '2021-09-01';

  static const Map<String, String> _zoneNames = {
    'kampar_zone_1': 'Zone 1',
    'kampar_zone_2': 'Zone 2',
    'kampar_zone_3': 'Zone 3',
    'kampar_zone_4': 'Zone 4',
  };

  static const Map<String, String> _zoneAreas = {
    'kampar_zone_1': 'Kampar - Tronoh Mines',
    'kampar_zone_2': 'Kampar - Bandar Baru',
    'kampar_zone_3': 'Kampar Barat - Jeram',
    'kampar_zone_4': 'Gopeng',
  };



  static const Map<String, String> _sourceUrls = {
    'kampar_zone_1':
        'https://www.mdkampar.gov.my/templates/yootheme/cache/1a/zon1-1aa1cc36.jpeg',
    'kampar_zone_2':
        'https://www.mdkampar.gov.my/templates/yootheme/cache/77/zon2-77273f6c.jpeg',
    'kampar_zone_3':
        'https://www.mdkampar.gov.my/templates/yootheme/cache/53/zon3-53a56e5a.jpeg',
    'kampar_zone_4':
        'https://www.mdkampar.gov.my/templates/yootheme/cache/ac/zon4-ac2ad9d8.jpeg',
  };

  /// Updates search aliases and landmarks on existing area documents
  /// without deleting any schedule or area.
  static Future<void> refreshLocationMetadata() async {
    final batch = _db.batch();
    int writes = 0;

    for (final group in _areaGroups) {
      for (final sourceName in group.areas) {
        final areaId = '${group.zoneId}_${_slug(sourceName)}';
        final ref = _db.collection('collection_areas').doc(areaId);

        batch.set(
          ref,
          {
            'aliases': _aliasesFor(sourceName),
            'landmarks': _landmarksFor(sourceName),
            'streetPatterns': _streetPatternsFor(sourceName),
          },
          SetOptions(merge: true),
        );

        writes++;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  static Future<void> refreshSearchMetadata() async {
    await refreshLocationMetadata();
  }

  /// Creates/updates the verified Kampar dataset without deleting data from
  /// other Perak local authorities (for example Ipoh). This is safe to run
  /// repeatedly from the Admin collection-data sync action.
  static Future<void> seedOrUpdate() async {
    final batch = _db.batch();

    for (final schedule in _schedules) {
      final ref =
          _db.collection('collection_schedules').doc(schedule.scheduleId);

      batch.set(ref, {
        'scheduleId': schedule.scheduleId,
        'state': _state,
        'district': _district,
        'localAuthorityId': _localAuthorityId,
        'localAuthorityName': _localAuthorityName,
        'zoneId': schedule.zoneId,
        'zoneName': _zoneNames[schedule.zoneId],
        'zoneArea': _zoneAreas[schedule.zoneId],
        'scheduleType': schedule.scheduleType,
        'daysOfWeek': schedule.daysOfWeek,
        'startHour': 6,
        'startMinute': 0,
        'endHour': 17,
        'endMinute': 0,
        'serviceType': 'Waste Collection',
        'scheduleNote':
            'Schedule configured from the Majlis Daerah Kampar collection '
            'schedule dataset used by this project.',
        'scheduleBasis': 'official_authority_schedule',
        'officialServiceFrequency':
            _frequencyLabelForScheduleType(schedule.scheduleType),
        'patternVerifiedByAuthority': true,
        'timeVerifiedByAuthority': true,
        'exactScheduleAvailable': true,
        'isActive': true,
        'sourceUpdatedDate': _sourceUpdatedDate,
        'sourceUrl': _sourceUrls[schedule.zoneId],
      });
    }

    for (final group in _areaGroups) {
      for (final sourceName in group.areas) {
        final areaId = '${group.zoneId}_${_slug(sourceName)}';
        final ref = _db.collection('collection_areas').doc(areaId);

        batch.set(ref, {
          'areaId': areaId,
          'state': _state,
          'district': _district,
          'localAuthorityId': _localAuthorityId,
          'localAuthorityName': _localAuthorityName,
          'zoneId': group.zoneId,
          'zoneName': _zoneNames[group.zoneId],
          'zoneArea': _zoneAreas[group.zoneId],
          'areaName': sourceName,
          'sourceAreaName': sourceName,
          'aliases': _aliasesFor(sourceName),
          'landmarks': _landmarksFor(sourceName),
          'streetPatterns': _streetPatternsFor(sourceName),
          'scheduleId': group.scheduleId,
          'isActive': true,
          'sourceUpdatedDate': _sourceUpdatedDate,
          'sourceUrl': _sourceUrls[group.zoneId],
        });
      }
    }

    await batch.commit();
  }

  /// Recreates only Majlis Daerah Kampar documents. Ipoh and any future
  /// authority datasets are preserved.
  static Future<void> resetAndSeed() async {
    await _clearAuthorityCollection('collection_areas');
    await _clearAuthorityCollection('collection_schedules');
    await seedOrUpdate();
  }

  static Future<void> _clearAuthorityCollection(String collectionName) async {
    while (true) {
      final snapshot = await _db
          .collection(collectionName)
          .where('localAuthorityId', isEqualTo: _localAuthorityId)
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

  static String _frequencyLabelForScheduleType(String scheduleType) {
    switch (scheduleType.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'mwf':
        return '3 times weekly - Monday, Wednesday & Friday';
      case 'tts':
        return '3 times weekly - Tuesday, Thursday & Saturday';
      default:
        return scheduleType;
    }
  }

  static String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static List<String> _aliasesFor(String sourceName) {
    final aliases = <String>{};

    // Expand common Malay abbreviations used on the council posters.
    if (sourceName.startsWith('Kg. ')) {
      aliases.add('Kampung ${sourceName.substring(4)}');
    } else if (sourceName.startsWith('Kg ')) {
      aliases.add('Kampung ${sourceName.substring(3)}');
    }

    if (sourceName.contains('Sg. ')) {
      aliases.add(sourceName.replaceAll('Sg. ', 'Sungai '));
    }

    if (sourceName.contains('Diawan')) {
      aliases.add(sourceName.replaceAll('Diawan', 'Di Awan'));
    }

    const explicitAliases = <String, List<String>>{
      'Pekan Mambang Diawan': [
        'Mambang Diawan',
        'Mambang Di Awan',
        'Pekan Mambang Di Awan',
      ],
      'Kg. Mesjid': [
        'Kampung Mesjid',
        'Kg Masjid',
        'Kampung Masjid',
      ],
      'Taman Julong': [
        'Taman Joo Loong',
      ],
      'Kampar Height (Puncak Kampar)': [
        'Kampar Height',
        'Puncak Kampar',
        'Taman Puncak Kampar',
      ],
      'Taman Indah 1&2': [
        'Taman Indah 1',
        'Taman Indah 2',
        'Taman Indah',
      ],
      'Jalan Stesyen': [
        'Jalan Stesen',
        'RPT Jalan Stesen',
      ],
      'Tropika Diawan': [
        'Taman Tropika Diawan',
        'Taman Tropika Di Awan',
      ],
      'Kawasan Perindustrian MDA 1 & 2': [
        'Kawasan Perindustrian MDA 1',
        'Kawasan Perindustrian MDA 2',
      ],
      'Taman Bandar Baru': [
        'Bandar Baru',
        'Taman Bandar Baru Kampar',
        'TAR UMT',
        'TAR UMT Perak',
        'TAR UMT Perak Branch',
        'Jalan Kolej',
      ],
      'Taman Bandar Barat': [
        'Bandar Barat',
        'Taman Bandar Barat Kampar',
        'Stanford',
        'Stanford Kampar',
        'Kampar Stanford',
        'Stanford Residence',
        'Jalan Section 4/1',
        'Jalan Seksyen 4/1',
      ],
      'Taman Tiara / Terminal One': [
        'Taman Tiara',
        'Terminal One',
        'Terminal 1',
      ],
      'UTAR': [
        'Universiti Tunku Abdul Rahman',
        'Universiti Tunku Abdul Rahman Kampar',
        'UTAR Kampar',
      ],
      'Kampus West Condominium': [
        'Kampus West City',
        'Kampus West',
      ],
      'Taman Kampar Makmur (Meadow Park)': [
        'Taman Kampar Makmur',
        'Meadow Park',
      ],
      'RPT Paya Basung': [
        'RPT Paya Basong',
      ],
      'Sg. Siput Selatan': [
        'Sungai Siput Selatan',
        'Pekan Sungai Siput Selatan',
      ],
      'Persiaraan Kebajikan': [
        'Persiaran Kebajikan',
      ],
      'Taman Gopeng Bestari': [
        'Taman Gopeng Bistari',
      ],
      'RPA 1 Gopeng (Jalan Sg. Itek)': [
        'RPA 1 Gopeng',
        'Jalan Sg. Itek',
        'Jalan Sungai Itek',
      ],
      'RPA 2 Gopeng (Belakang Bomba)': [
        'RPA 2 Gopeng',
        'Belakang Bomba',
      ],
      'Kg. Baru Lawan Kuda (Indian Camp)': [
        'Kampung Baru Lawan Kuda Indian Camp',
        'Indian Camp Lawan Kuda',
      ],
      'Kg Rawa Baru': [
        'Kampung Rawa Baru',
      ],
      'RPT Kg Rawa': [
        'RPT Kampung Rawa',
      ],
    };

    aliases.addAll(explicitAliases[sourceName] ?? const []);

    aliases.remove(sourceName);
    return aliases.toList()..sort();
  }

  static List<String> _landmarksFor(String sourceName) {
    switch (sourceName) {
      case 'Taman Bandar Baru':
        return const [
          'TAR UMT Perak Branch',
          'Tunku Abdul Rahman University of Management and Technology Perak Branch',
        ];

      case 'Taman Bandar Barat':
        return const [
          'Stanford',
          'Stanford Kampar',
          'Stanford Residence',
        ];

      default:
        return const [];
    }
  }

  static List<String> _streetPatternsFor(String sourceName) {
    switch (sourceName) {
      case 'Taman Bandar Barat':
        return const [
          'Jalan Seksyen 4',
          'Jalan Section 4',
        ];

      case 'Taman Bandar Baru':
        return const [
          'Jalan Kolej',
        ];

      default:
        return const [];
    }
  }

  static const List<_ScheduleSeed> _schedules = [
    _ScheduleSeed(
      scheduleId: 'kampar_zone_1_daily',
      zoneId: 'kampar_zone_1',
      scheduleType: 'daily',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_1_mwf',
      zoneId: 'kampar_zone_1',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_1_tts',
      zoneId: 'kampar_zone_1',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_2_daily',
      zoneId: 'kampar_zone_2',
      scheduleType: 'daily',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_2_mwf',
      zoneId: 'kampar_zone_2',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_2_tts',
      zoneId: 'kampar_zone_2',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_3_daily',
      zoneId: 'kampar_zone_3',
      scheduleType: 'daily',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_3_mwf',
      zoneId: 'kampar_zone_3',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_3_tts',
      zoneId: 'kampar_zone_3',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_4_daily',
      zoneId: 'kampar_zone_4',
      scheduleType: 'daily',
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_4_mwf',
      zoneId: 'kampar_zone_4',
      scheduleType: 'mwf',
      daysOfWeek: [1, 3, 5],
    ),
    _ScheduleSeed(
      scheduleId: 'kampar_zone_4_tts',
      zoneId: 'kampar_zone_4',
      scheduleType: 'tts',
      daysOfWeek: [2, 4, 6],
    ),
  ];

  static const List<_AreaGroup> _areaGroups = [
    // ============================================================
    // ZONE 1 - KAMPAR - TRONOH MINES
    // ============================================================
    _AreaGroup(
      zoneId: 'kampar_zone_1',
      scheduleId: 'kampar_zone_1_daily',
      areas: [
        'Kompleks Majlis Daerah Kampar',
        'Pekan Mambang Diawan',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_1',
      scheduleId: 'kampar_zone_1_mwf',
      areas: [
        'Persiaran Jalan Iskandar',
        'Kelab Kampar',
        'Flat Taman Pelangi',
        'Taman Kampar Jaya',
        'Taman Mutiara',
        'Taman Golden Dragon',
        'Golden Dragon Villa',
        'Kg. Changkat',
        'Kg. Mesjid',
        'Taman Julong',
        'Taman Ros',
        'Kampar Height (Puncak Kampar)',
        'Taman Kampar Permai',
        'Taman Sri Emas',
        'Taman Bukit Emas',
        'Taman Timur',
        'Taman Sri Kampar',
        'Taman Indah 1&2',
        'Taman Cahaya',
        'Taman Mesra Rakyat',
        'Taman Sejahtera',
        'Taman Sejahtera Indah',
        'Taman Sejahtera Jaya',
        'Taman Sejahtera Utama',
        'Taman Mambang',
        'Taman Awan Mas',
        'Taman Desa Aman',
        'Taman Aman',
        'Taman Aman Baru',
        'Taman Awan Jaya',
        'Tronoh Mines',
        'RPT Tronoh Mines',
        'Jalan Degong',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_1',
      scheduleId: 'kampar_zone_1_tts',
      areas: [
        'Taman Melayu Jaya',
        'RPT Batu Putih',
        'RPT Batu Putih Muhibah',
        'Jalan Stesyen',
        'Taman Sri Intan',
        'New Wah Loong',
        'Taman Merdeka',
        'Taman Damai',
        'Taman Permai',
        'Taman Diawan',
        'Kampung Baru Mambang Diawan',
        'Tropika Diawan',
        'Kawasan Perindustrian MDA 1 & 2',
        'Kawasan Perindustrian MDA 3',
      ],
    ),

    // ============================================================
    // ZONE 2 - KAMPAR - BANDAR BARU
    // ============================================================
    _AreaGroup(
      zoneId: 'kampar_zone_2',
      scheduleId: 'kampar_zone_2_daily',
      areas: [
        'Pekan Kampar',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_2',
      scheduleId: 'kampar_zone_2_mwf',
      areas: [
        'Taman Bandar Baru',
        'Taman Kolej Perdana',
        'Kolej UNITAR',
        'Pangsapuri Sutera',
        'Westlake Villa',
        'UTAR',
        'Sekolah Antarabangsa',
        'Bandar Baru Utama',
        'Taman Bandar Barat',
        'Taman Kampar Sentral',
        'Taman Bandar Baru Selatan',
        'Taman Perak',
        'Taman Perak Indah',
        'Taman Perak Mewah',
        'Taman Perak Permai',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_2',
      scheduleId: 'kampar_zone_2_tts',
      areas: [
        'Taman Sentosa',
        'Aston Settlement',
        'Taman Tiara / Terminal One',
        'Hoong Chan Estate',
        'Taman Kampar Siswa',
        'Taman Kampar Perdana',
        'Taman Kampar Perdana II',
        'Taman Angkasa',
        'Taman Kampar',
        'Kampung Abdullah',
        'Taman Bandar Baru Jaya',
        'Taman Mahsuri',
        'Taman Mahsuri Impian',
        'Taman Mahsuri Jaya',
        'Taman Perak Jaya',
      ],
    ),

    // ============================================================
    // ZONE 3 - KAMPAR BARAT - JERAM
    // ============================================================
    _AreaGroup(
      zoneId: 'kampar_zone_3',
      scheduleId: 'kampar_zone_3_daily',
      areas: [
        'Pekan Jeram',
        'Pekan Malim Nawar',
        'Taman Kampar Barat',
        'Kampus West Condominium',
        'Bandar Agacia',
        'Taman Kampar Makmur (Meadow Park)',
        'Trails Of Kampar',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_3',
      scheduleId: 'kampar_zone_3_mwf',
      areas: [
        'Taman Kampar Putra',
        'Taman Camelia',
        'Kediaman PRIMA Kampar',
        'Batu Karang',
        'Kg. Batu 20',
        'Taman Dipang Permai',
        'RPT Paya Basung',
        'Kg. Baru Jeram',
        'RPA Jeram',
        'Taman Harmoni',
        'Kg. Baru Kuala Dipang',
        'Sg. Siput Selatan',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_3',
      scheduleId: 'kampar_zone_3_tts',
      areas: [
        'RPA 1 Malim Nawar',
        'Indian Settlement',
        'RPT Muhibbah',
        'Kg. Baru Malim Nawar',
        'Taman Malim Nawar',
        'Taman Malim Permai',
        'RPA 2 Malim Nawar',
        'Taman Tualang Sekah',
        'Kg. Seri Malim',
        'Taman Bina Jaya',
      ],
    ),

    // ============================================================
    // ZONE 4 - GOPENG
    // ============================================================
    _AreaGroup(
      zoneId: 'kampar_zone_4',
      scheduleId: 'kampar_zone_4_daily',
      areas: [
        'Pekan Gopeng',
        'Pasar Kopisan',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_4',
      scheduleId: 'kampar_zone_4_mwf',
      areas: [
        'Kawasan Industri Gopeng 1',
        'Kawasan Industri Gopeng 2',
        'RPT Tekah 1',
        'RPT Tekah 2',
        'RTC Gopeng',
        'Persiaraan Kebajikan',
        'RPT Muhibah Kopisan',
        'Kg. Baru Kopisan',
        'Kg. Tersusun Kopisan',
        'Kota Bharu',
        'Taman Sri Indah',
        'Kg. Tersusun Lawan Kuda',
        'RPA Lawan Kuda',
        'RPA 3 Lawan Kuda',
        'RPA 1 Gopeng (Jalan Sg. Itek)',
        'RPA 2 Gopeng (Belakang Bomba)',
      ],
    ),
    _AreaGroup(
      zoneId: 'kampar_zone_4',
      scheduleId: 'kampar_zone_4_tts',
      areas: [
        'Gopeng PRIMA',
        'Taman Changkat Golf',
        'Taman Gopeng Bestari',
        'Taman Gopeng Mewah',
        'Taman Gopeng Indah',
        'Taman Gopeng Perdana',
        'Taman Gopeng Baru',
        'Taman Gopeng Jaya',
        'Taman Gopeng Setia',
        'Taman Gopeng',
        'Taman Bertuah',
        'Kg Rawa Baru',
        'RPT Kg Rawa',
        'Taman Kinta',
        'Taman Kinta Baru',
        'Desa Lawan Kuda',
        'Taman Desa Cahaya',
        'Kg. Baru Lawan Kuda',
        'Kg. Baru Lawan Kuda (Indian Camp)',
      ],
    ),
  ];
}

class _ScheduleSeed {
  final String scheduleId;
  final String zoneId;
  final String scheduleType;
  final List<int> daysOfWeek;

  const _ScheduleSeed({
    required this.scheduleId,
    required this.zoneId,
    required this.scheduleType,
    required this.daysOfWeek,
  });
}

class _AreaGroup {
  final String zoneId;
  final String scheduleId;
  final List<String> areas;

  const _AreaGroup({
    required this.zoneId,
    required this.scheduleId,
    required this.areas,
  });
}
