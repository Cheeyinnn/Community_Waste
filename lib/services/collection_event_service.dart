import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collection_area.dart';
import '../models/collection_event.dart';
import '../models/collection_schedule.dart';

class CollectionEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _eventsCollection {
    return _firestore.collection('collection_events');
  }

  // ============================================================
  // CURRENT COLLECTOR
  // ============================================================

  User _requireCurrentUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Collector must be logged in before updating collection status.',
      );
    }

    return user;
  }

  // ============================================================
  // TODAY DATE STRING
  //
  // Example:
  // 2026-09-02
  // ============================================================

  String getTodayDateString() {
    return formatDate(DateTime.now());
  }

  // ============================================================
  // FORMAT DATE
  //
  // Store collection date as local YYYY-MM-DD.
  // ============================================================

  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // EVENT DOCUMENT ID
  //
  // One event per:
  // area + collection date
  //
  // Example:
  // kampar_zone_2_taman_bandar_barat_2026_09_02
  // ============================================================

  String buildEventId({
    required String areaId,
    required DateTime date,
  }) {
    final safeAreaId = areaId
        .trim()
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'\s+'), '_');

    final datePart = formatDate(
      date,
    ).replaceAll('-', '_');

    return '${safeAreaId}_$datePart';
  }

  // ============================================================
  // GET EVENT FOR A DATE
  // ============================================================

  Future<CollectionEvent?> getEventForDate({
    required CollectionArea area,
    required DateTime date,
  }) async {
    final eventId = buildEventId(
      areaId: area.areaId,
      date: date,
    );

    final doc = await _eventsCollection
        .doc(eventId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return CollectionEvent.fromDocument(doc);
  }

  // ============================================================
  // GET TODAY EVENT
  // ============================================================

  Future<CollectionEvent?> getTodayEvent(
    CollectionArea area,
  ) async {
    return getEventForDate(
      area: area,
      date: DateTime.now(),
    );
  }

  // ============================================================
  // WATCH EVENT FOR A DATE
  // ============================================================

  Stream<CollectionEvent?> watchEventForDate({
    required CollectionArea area,
    required DateTime date,
  }) {
    final eventId = buildEventId(
      areaId: area.areaId,
      date: date,
    );

    return _eventsCollection
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }

      return CollectionEvent.fromDocument(doc);
    });
  }

  // ============================================================
  // WATCH TODAY EVENT
  //
  // User screen can listen to this.
  // ============================================================

  Stream<CollectionEvent?> watchTodayEvent(
    CollectionArea area,
  ) {
    return watchEventForDate(
      area: area,
      date: DateTime.now(),
    );
  }

  // ============================================================
  // START COLLECTION
  //
  // Collector presses:
  //
  // [ Start Collection ]
  //
  // Result:
  // status = in_progress
  // startedAt = server timestamp
  // ============================================================

  Future<void> startCollection({
    required CollectionArea area,
    required CollectionSchedule schedule,
  }) async {
    final user = _requireCurrentUser();

    final now = DateTime.now();

    // The collector should only start an area
    // scheduled for collection today.
    if (!schedule.collectsOnDay(now.weekday)) {
      throw StateError(
        '${area.areaName} is not scheduled for collection today.',
      );
    }

    final collectionDate = formatDate(now);

    final eventId = buildEventId(
      areaId: area.areaId,
      date: now,
    );

    final eventRef = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      // ========================================================
      // EVENT ALREADY EXISTS
      // ========================================================

      if (snapshot.exists) {
        final data =
            snapshot.data() ?? <String, dynamic>{};

        final currentStatus =
            data['status']?.toString() ?? 'pending';

        // Already running.
        if (currentStatus == 'in_progress') {
          return;
        }

        // Never restart an already completed event.
        if (currentStatus == 'collected') {
          throw StateError(
            '${area.areaName} has already been marked as collected today.',
          );
        }

        if (currentStatus == 'missed') {
          throw StateError(
            '${area.areaName} has already been marked as missed today.',
          );
        }

        transaction.update(
          eventRef,
          {
            'status': 'in_progress',
            'collectorId': user.uid,

            // Only fill startedAt if it does not already exist.
            if (data['startedAt'] == null)
              'startedAt': FieldValue.serverTimestamp(),

            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        return;
      }

      // ========================================================
      // CREATE NEW EVENT
      // ========================================================

      transaction.set(
        eventRef,
        {
          'areaId': area.areaId,
          'areaName': area.areaName,

          'scheduleId': schedule.scheduleId,

          'zoneId': area.zoneId,
          'zoneName': area.zoneName,

          'collectionDate': collectionDate,

          'status': 'in_progress',

          'collectorId': user.uid,

          'startedAt': FieldValue.serverTimestamp(),
          'collectedAt': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  // ============================================================
  // MARK AS COLLECTED
  //
  // Collector presses:
  //
  // [ Mark as Collected ]
  //
  // Result:
  // status = collected
  // collectedAt = actual server time
  // ============================================================

  Future<void> markAsCollected({
    required CollectionArea area,
  }) async {
    final user = _requireCurrentUser();

    final now = DateTime.now();

    final eventId = buildEventId(
      areaId: area.areaId,
      date: now,
    );

    final eventRef = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      if (!snapshot.exists) {
        throw StateError(
          'Start the collection for ${area.areaName} before marking it as collected.',
        );
      }

      final data =
          snapshot.data() ?? <String, dynamic>{};

      final currentStatus =
          data['status']?.toString() ?? 'pending';

      if (currentStatus == 'collected') {
        // Already completed.
        return;
      }

      if (currentStatus == 'missed') {
        throw StateError(
          '${area.areaName} has already been marked as missed.',
        );
      }

      if (currentStatus != 'in_progress') {
        throw StateError(
          'Start the collection before marking ${area.areaName} as collected.',
        );
      }

      transaction.update(
        eventRef,
        {
          'status': 'collected',

          'collectorId': user.uid,

          'collectedAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  // ============================================================
  // MARK AS MISSED
  //
  // Optional feature.
  //
  // Useful if a scheduled area could not be collected.
  // ============================================================

  Future<void> markAsMissed({
    required CollectionArea area,
    required CollectionSchedule schedule,
  }) async {
    final user = _requireCurrentUser();

    final now = DateTime.now();

    if (!schedule.collectsOnDay(now.weekday)) {
      throw StateError(
        '${area.areaName} is not scheduled for collection today.',
      );
    }

    final collectionDate = formatDate(now);

    final eventId = buildEventId(
      areaId: area.areaId,
      date: now,
    );

    final eventRef = _eventsCollection.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);

      // ========================================================
      // EXISTING EVENT
      // ========================================================

      if (snapshot.exists) {
        final data =
            snapshot.data() ?? <String, dynamic>{};

        final currentStatus =
            data['status']?.toString() ?? 'pending';

        if (currentStatus == 'collected') {
          throw StateError(
            '${area.areaName} has already been collected today.',
          );
        }

        if (currentStatus == 'missed') {
          return;
        }

        transaction.update(
          eventRef,
          {
            'status': 'missed',
            'collectorId': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        return;
      }

      // ========================================================
      // CREATE MISSED EVENT
      // ========================================================

      transaction.set(
        eventRef,
        {
          'areaId': area.areaId,
          'areaName': area.areaName,

          'scheduleId': schedule.scheduleId,

          'zoneId': area.zoneId,
          'zoneName': area.zoneName,

          'collectionDate': collectionDate,

          'status': 'missed',

          'collectorId': user.uid,

          'startedAt': null,
          'collectedAt': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  // ============================================================
  // GET TODAY'S EVENTS FOR CURRENT COLLECTOR
  //
  // This can later be used on Collector Dashboard.
  // ============================================================

  Stream<List<CollectionEvent>> watchMyTodayEvents() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<List<CollectionEvent>>.value(
        const [],
      );
    }

    final today = getTodayDateString();

    return _eventsCollection
        .where(
          'collectorId',
          isEqualTo: user.uid,
        )
        .where(
          'collectionDate',
          isEqualTo: today,
        )
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map(
            CollectionEvent.fromDocument,
          )
          .toList();

      events.sort(
        (a, b) => a.areaName
            .toLowerCase()
            .compareTo(
              b.areaName.toLowerCase(),
            ),
      );

      return events;
    });
  }

  // ============================================================
  // GET ALL TODAY EVENTS
  //
  // Useful later for admin monitoring.
  // ============================================================

  Stream<List<CollectionEvent>> watchAllTodayEvents() {
    final today = getTodayDateString();

    return _eventsCollection
        .where(
          'collectionDate',
          isEqualTo: today,
        )
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs
          .map(
            CollectionEvent.fromDocument,
          )
          .toList();

      events.sort(
        (a, b) => a.areaName
            .toLowerCase()
            .compareTo(
              b.areaName.toLowerCase(),
            ),
      );

      return events;
    });
  }
}