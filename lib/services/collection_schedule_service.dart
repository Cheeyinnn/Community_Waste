import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/collection_schedule.dart';

class CollectionScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // GET SCHEDULES BY AREA
  // ============================================================

  Stream<List<CollectionSchedule>> getSchedulesByArea(String area) {
    return _firestore
        .collection('collection_schedules')
        .where('state', isEqualTo: 'Perak')
        .where('area', isEqualTo: area)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => CollectionSchedule.fromDocument(doc))
              .toList();

          schedules.sort((a, b) {
            if (a.dayOfWeek != b.dayOfWeek) {
              return a.dayOfWeek.compareTo(b.dayOfWeek);
            }

            if (a.startHour != b.startHour) {
              return a.startHour.compareTo(b.startHour);
            }

            return a.startMinute.compareTo(b.startMinute);
          });

          return schedules;
        });
  }

  // ============================================================
  // GET AVAILABLE SCHEDULE AREAS
  // ============================================================

  Future<List<String>> getAvailableAreas() async {
    final snapshot = await _firestore
        .collection('collection_schedules')
        .where('state', isEqualTo: 'Perak')
        .where('isActive', isEqualTo: true)
        .get();

    final areas = snapshot.docs
        .map((doc) => doc.data()['area']?.toString().trim() ?? '')
        .where((area) => area.isNotEmpty)
        .toSet()
        .toList();

    areas.sort();

    return areas;
  }

  // ============================================================
  // FIND SCHEDULE AREA FROM GPS LOCATION
  // ============================================================

  Future<String?> findScheduleAreaFromLocation(
    List<String> detectedNames,
  ) async {
    final snapshot = await _firestore
        .collection('collection_areas')
        .where('state', isEqualTo: 'Perak')
        .where('isActive', isEqualTo: true)
        .get();

    final candidates = detectedNames
        .map(_normalize)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    if (candidates.isEmpty) {
      return null;
    }

    // First use exact matching.
    for (final doc in snapshot.docs) {
      final data = doc.data();

      final areaName = data['name']?.toString().trim() ?? '';

      final rawLocalities = data['localities'];

      final List<String> localities = rawLocalities is List
          ? rawLocalities.map((item) => item.toString()).toList()
          : [];

      final namesToCheck = <String>[areaName, ...localities];

      for (final storedName in namesToCheck) {
        final normalizedStored = _normalize(storedName);

        for (final candidate in candidates) {
          if (candidate == normalizedStored) {
            return areaName;
          }
        }
      }
    }

    // Then allow a partial match for GPS names such as
    // "Kampar District" or "Taman Malim Nawar".
    for (final doc in snapshot.docs) {
      final data = doc.data();

      final areaName = data['name']?.toString().trim() ?? '';

      final rawLocalities = data['localities'];

      final List<String> localities = rawLocalities is List
          ? rawLocalities.map((item) => item.toString()).toList()
          : [];

      final namesToCheck = <String>[areaName, ...localities];

      for (final storedName in namesToCheck) {
        final normalizedStored = _normalize(storedName);

        if (normalizedStored.length < 4) {
          continue;
        }

        for (final candidate in candidates) {
          if (candidate.length < 4) {
            continue;
          }

          if (candidate.contains(normalizedStored) ||
              normalizedStored.contains(candidate)) {
            return areaName;
          }
        }
      }
    }

    return null;
  }

  // ============================================================
  // NORMALIZE LOCATION NAME
  // ============================================================

  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[.,\-_/()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
