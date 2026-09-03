import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collection_area.dart';
import '../models/collection_schedule.dart';

class CollectionScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<CollectionArea>? _cachedAreas;

  CollectionReference<Map<String, dynamic>> get _areasCollection {
    return _firestore.collection('collection_areas');
  }

  CollectionReference<Map<String, dynamic>> get _schedulesCollection {
    return _firestore.collection('collection_schedules');
  }

  // ============================================================
  // AVAILABLE AREAS
  // ============================================================

  Future<List<CollectionArea>> getAvailableAreas({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedAreas != null) {
      return List<CollectionArea>.from(_cachedAreas!);
    }

    final snapshot = await _areasCollection
        .where('state', isEqualTo: 'Perak')
        .get();

    final areas = snapshot.docs
        .map(CollectionArea.fromDocument)
        .where((area) {
          return area.isActive &&
              area.state.toLowerCase() == 'perak' &&
              area.district.toLowerCase() == 'kampar';
        })
        .toList();

    areas.sort(
      (a, b) => a.areaName.toLowerCase().compareTo(
            b.areaName.toLowerCase(),
          ),
    );

    _cachedAreas = areas;

    return List<CollectionArea>.from(areas);
  }

  // ============================================================
  // AREA
  // ============================================================

  Future<CollectionArea?> getAreaById(
    String areaId,
  ) async {
    final id = areaId.trim();

    if (id.isEmpty) {
      return null;
    }

    final doc = await _areasCollection.doc(id).get();

    if (!doc.exists) {
      return null;
    }

    final area = CollectionArea.fromDocument(doc);

    return area.isActive ? area : null;
  }

  // ============================================================
  // SCHEDULE
  // ============================================================

  Future<CollectionSchedule?> getScheduleById(
    String scheduleId,
  ) async {
    final id = scheduleId.trim();

    if (id.isEmpty) {
      return null;
    }

    final doc = await _schedulesCollection.doc(id).get();

    if (!doc.exists) {
      return null;
    }

    final schedule = CollectionSchedule.fromDocument(doc);

    return schedule.isActive ? schedule : null;
  }

  Stream<CollectionSchedule?> watchScheduleById(
    String scheduleId,
  ) {
    final id = scheduleId.trim();

    if (id.isEmpty) {
      return Stream<CollectionSchedule?>.value(null);
    }

    return _schedulesCollection.doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      final schedule = CollectionSchedule.fromDocument(doc);

      return schedule.isActive ? schedule : null;
    });
  }

  Stream<CollectionSchedule?> watchScheduleForArea(
    CollectionArea area,
  ) {
    return watchScheduleById(area.scheduleId);
  }

  // ============================================================
  // SAVE / RESTORE USER PREFERRED AREA
  // ============================================================

  Future<void> savePreferredArea(
    CollectionArea area,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'preferredCollectionAreaId': area.areaId,
        'preferredCollectionAreaName': area.areaName,
        'preferredCollectionAreaUpdatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<CollectionArea?> getSavedPreferredArea() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final doc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      final areaId =
          data['preferredCollectionAreaId']?.toString().trim() ?? '';

      if (areaId.isEmpty) {
        return null;
      }

      return getAreaById(areaId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // MANUAL SEARCH
  // ============================================================

  List<CollectionArea> filterAreas(
    List<CollectionArea> areas,
    String query,
  ) {
    final normalizedQuery = _normalize(query);

    if (normalizedQuery.isEmpty) {
      final result = List<CollectionArea>.from(areas);

      result.sort(
        (a, b) => a.areaName.toLowerCase().compareTo(
              b.areaName.toLowerCase(),
            ),
      );

      return result;
    }

    final scored = <_AreaScore>[];

    for (final area in areas) {
      final score = _manualSearchScore(
        area,
        normalizedQuery,
      );

      if (score > 0) {
        scored.add(
          _AreaScore(
            area: area,
            score: score,
          ),
        );
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);

      if (byScore != 0) {
        return byScore;
      }

      return a.area.areaName.toLowerCase().compareTo(
            b.area.areaName.toLowerCase(),
          );
    });

    return scored.map((item) => item.area).toList();
  }

  // ============================================================
  // GPS MATCHING
  //
  // Matching priority:
  // 1. Exact official area / alias / landmark
  // 2. Strong contained area / alias / landmark
  // 3. Firebase streetPatterns
  // 4. Otherwise: no automatic match
  //
  // No street name is hard-coded in this service.
  // ============================================================

  Future<CollectionArea?> findCollectionAreaFromLocation(
    List<String> detectedNames,
  ) async {
    if (detectedNames.isEmpty) {
      return null;
    }

    final areas = await getAvailableAreas();

    if (areas.isEmpty) {
      return null;
    }

    final candidates = detectedNames
        .map(_normalize)
        .where((value) => value.isNotEmpty)
        .where(_containsLetter)
        .where((value) => !_isGenericGpsName(value))
        .toSet()
        .toList();

    if (candidates.isEmpty) {
      return null;
    }

    CollectionArea? bestArea;
    int bestScore = 0;

    // ==========================================================
    // 1 + 2. DIRECT AREA / ALIAS / LANDMARK MATCH
    // ==========================================================

    for (final area in areas) {
      final directNames = area.directMatchNames
          .map(_normalize)
          .where((value) => value.isNotEmpty)
          .where(_containsLetter)
          .where((value) => !_isGenericGpsName(value))
          .toSet();

      for (final candidate in candidates) {
        for (final storedName in directNames) {
          final score = _directGpsScore(
            candidate,
            storedName,
          );

          if (score > bestScore) {
            bestScore = score;
            bestArea = area;
          }
        }
      }
    }

    if (bestArea != null && bestScore >= 7500) {
      return bestArea;
    }

    // ==========================================================
    // 3. FIREBASE STREET PATTERN MATCH
    // ==========================================================

    bestArea = null;
    bestScore = 0;

    for (final area in areas) {
      for (final rawPattern in area.streetPatterns) {
        final pattern = _normalize(rawPattern);

        if (pattern.isEmpty || !_containsLetter(pattern)) {
          continue;
        }

        for (final candidate in candidates) {
          if (_matchesStreetPattern(
            candidate,
            pattern,
          )) {
            // Prefer longer/more-specific patterns.
            final score = 9000 + pattern.length;

            if (score > bestScore) {
              bestScore = score;
              bestArea = area;
            }
          }
        }
      }
    }

    return bestArea;
  }

  // ============================================================
  // MANUAL SEARCH SCORE
  // ============================================================

  int _manualSearchScore(
    CollectionArea area,
    String query,
  ) {
    int best = 0;

    for (final rawName in area.searchableNames) {
      final name = _normalize(rawName);

      if (name.isEmpty) {
        continue;
      }

      if (name == query) {
        best = _max(
          best,
          10000 + name.length,
        );
        continue;
      }

      if (name.startsWith(query)) {
        best = _max(
          best,
          8500 + query.length,
        );
        continue;
      }

      if (name.contains(query)) {
        best = _max(
          best,
          7000 + query.length,
        );
        continue;
      }

      if (query.contains(name) && name.length >= 5) {
        best = _max(
          best,
          6500 + name.length,
        );
        continue;
      }

      final queryWords = _meaningfulWords(query);
      final nameWords = _meaningfulWords(name);

      if (queryWords.isEmpty || nameWords.isEmpty) {
        continue;
      }

      final common = queryWords.intersection(nameWords);

      if (common.isEmpty) {
        continue;
      }

      final commonLength = common.fold<int>(
        0,
        (total, word) => total + word.length,
      );

      best = _max(
        best,
        (common.length * 500) + commonLength,
      );
    }

    return best;
  }

  // ============================================================
  // DIRECT GPS SCORE
  // ============================================================

  int _directGpsScore(
    String candidate,
    String storedName,
  ) {
    if (candidate == storedName) {
      return 10000 + storedName.length;
    }

    if (storedName.length >= 5 &&
        candidate.length >= 5 &&
        candidate.contains(storedName)) {
      return 8000 + storedName.length;
    }

    if (storedName.length >= 5 &&
        candidate.length >= 5 &&
        storedName.contains(candidate)) {
      return 7500 + candidate.length;
    }

    return 0;
  }

  // ============================================================
  // STREET PATTERN MATCH
  //
  // Uses token-prefix matching instead of raw startsWith.
  //
  // Pattern:
  // "jalan seksyen 4"
  //
  // Matches:
  // "jalan seksyen 4 4"
  //
  // Does NOT match:
  // "jalan seksyen 40"
  // ============================================================

  bool _matchesStreetPattern(
    String candidate,
    String pattern,
  ) {
    final candidateWords = candidate
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    final patternWords = pattern
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (patternWords.isEmpty ||
        candidateWords.length < patternWords.length) {
      return false;
    }

    for (int i = 0; i < patternWords.length; i++) {
      if (candidateWords[i] != patternWords[i]) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // NORMALIZATION
  // ============================================================

  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('&', ' and ')
        .replaceAll(
          RegExp(r'''[.,\-_/()'"]'''),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  bool _containsLetter(String value) {
    return RegExp(r'[a-z]').hasMatch(
      value.toLowerCase(),
    );
  }

  bool _isGenericGpsName(String value) {
    const genericNames = <String>{
      'malaysia',
      'perak',
      'perak darul ridzuan',
      'kampar',
      'daerah kampar',
      'kampar district',
    };

    return genericNames.contains(value);
  }

  Set<String> _meaningfulWords(String value) {
    const ignoredWords = <String>{
      'taman',
      'kampung',
      'kg',
      'jalan',
      'jln',
      'lorong',
      'persiaran',
      'pekan',
      'bandar',
      'daerah',
      'perak',
      'malaysia',
      'the',
      'of',
      'and',
    };

    return value
        .split(' ')
        .map((word) => word.trim())
        .where((word) => word.length >= 3)
        .where((word) => !ignoredWords.contains(word))
        .toSet();
  }

  int _max(int a, int b) {
    return a > b ? a : b;
  }
}

class _AreaScore {
  final CollectionArea area;
  final int score;

  const _AreaScore({
    required this.area,
    required this.score,
  });
}
