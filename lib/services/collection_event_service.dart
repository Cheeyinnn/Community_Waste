import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/collection_area.dart';
import '../models/collection_event.dart';
import '../models/collection_schedule.dart';

class CollectionEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      _firestore.collection('collection_events');

  CollectionReference<Map<String, dynamic>> get _areasCollection =>
      _firestore.collection('collection_areas');

  CollectionReference<Map<String, dynamic>> get _schedulesCollection =>
      _firestore.collection('collection_schedules');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ============================================================
  // CURRENT COLLECTOR / AUTHORIZATION
  // ============================================================

  Future<User> _requireCollectorAccessForArea(
    CollectionArea area,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Collector must be logged in before updating collection status.',
      );
    }

    final userDoc = await _usersCollection.doc(user.uid).get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw StateError(
        'Collector account was not found.',
      );
    }

    final data = userDoc.data()!;

    final role =
        data['role']?.toString().trim().toLowerCase() ?? '';

    final applicationStatus =
        data['collectorApplicationStatus']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    if (role != 'collector' || applicationStatus != 'approved') {
      throw StateError(
        'Only an approved Collector account can update collection runs.',
      );
    }

    final rawZoneIds = data['assignedCollectionZoneIds'];

    final assignedZoneIds = rawZoneIds is Iterable
        ? rawZoneIds
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
        : <String>{};

    final zoneId = area.zoneId.trim();

    if (zoneId.isEmpty) {
      throw StateError(
        'This collection area does not have a valid collection zone.',
      );
    }

    if (!assignedZoneIds.contains(zoneId)) {
      throw StateError(
        'This collection area is not assigned to the current collector.',
      );
    }

    if (!area.isActive) {
      throw StateError(
        '${area.areaName} is currently inactive.',
      );
    }

    // Re-check the area against the current Firestore record.
    // This prevents stale UI data from authorizing an old zone or
    // an area that has since been disabled by Admin.
    final areaDoc = await _areasCollection.doc(area.id).get();

    if (!areaDoc.exists || areaDoc.data() == null) {
      throw StateError(
        'The collection area no longer exists.',
      );
    }

    final liveArea = CollectionArea.fromDocument(areaDoc);

    if (!liveArea.isActive) {
      throw StateError(
        '${liveArea.areaName} is currently inactive.',
      );
    }

    if (liveArea.zoneId.trim() != zoneId) {
      throw StateError(
        'The collection area information has changed. Please refresh and try again.',
      );
    }

    if (!assignedZoneIds.contains(liveArea.zoneId.trim())) {
      throw StateError(
        'This collection area is no longer assigned to the current collector.',
      );
    }

    return user;
  }

  // ============================================================
  // AREA / SCHEDULE VALIDATION
  // ============================================================

  Future<void> _validateAreaAndSchedule({
    required CollectionArea area,
    required CollectionSchedule schedule,
  }) async {
    if (!area.isActive) {
      throw StateError(
        '${area.areaName} is currently inactive.',
      );
    }

    if (!schedule.isActive) {
      throw StateError(
        'The collection schedule for ${area.areaName} is currently inactive.',
      );
    }

    if (area.scheduleId.trim().isEmpty ||
        schedule.scheduleId.trim().isEmpty ||
        area.scheduleId.trim() != schedule.scheduleId.trim()) {
      throw StateError(
        'The selected collection schedule does not match ${area.areaName}.',
      );
    }

    if (area.zoneId.trim().isEmpty ||
        schedule.zoneId.trim().isEmpty ||
        area.zoneId.trim() != schedule.zoneId.trim()) {
      throw StateError(
        'The selected collection schedule does not match the collection zone.',
      );
    }

    // Re-check the schedule from Firestore so an old/stale local
    // schedule cannot be used after Admin changes the configuration.
    final scheduleDoc =
        await _schedulesCollection.doc(schedule.id).get();

    if (!scheduleDoc.exists || scheduleDoc.data() == null) {
      throw StateError(
        'The collection schedule no longer exists.',
      );
    }

    final liveSchedule =
        CollectionSchedule.fromDocument(scheduleDoc);

    if (!liveSchedule.isActive) {
      throw StateError(
        'The collection schedule for ${area.areaName} is currently inactive.',
      );
    }

    if (liveSchedule.scheduleId.trim() != area.scheduleId.trim() ||
        liveSchedule.zoneId.trim() != area.zoneId.trim()) {
      throw StateError(
        'The collection schedule has changed. Please refresh and try again.',
      );
    }
  }

  void _requireEventOwnership({
    required Map<String, dynamic> data,
    required String collectorUid,
    required String areaName,
  }) {
    final eventCollectorId =
        data['collectorId']?.toString().trim() ?? '';

    if (eventCollectorId.isNotEmpty &&
        eventCollectorId != collectorUid) {
      throw StateError(
        '$areaName is already assigned to another collector for today.',
      );
    }
  }

  void _requireEventMatchesArea({
    required Map<String, dynamic> data,
    required CollectionArea area,
  }) {
    final eventAreaId =
        data['areaId']?.toString().trim() ?? '';
    final eventZoneId =
        data['zoneId']?.toString().trim() ?? '';

    if (eventAreaId != area.areaId.trim() ||
        eventZoneId != area.zoneId.trim()) {
      throw StateError(
        'The collection event does not match the selected area.',
      );
    }
  }

  // ============================================================
  // DATE / EVENT ID HELPERS
  // ============================================================

  String getTodayDateString() {
    return formatDate(DateTime.now());
  }

  String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String buildEventId({
    required String areaId,
    required DateTime date,
  }) {
    final cleanAreaId = areaId.trim();

    if (cleanAreaId.isEmpty) {
      throw ArgumentError(
        'Collection area ID cannot be empty.',
      );
    }

    final safeAreaId = cleanAreaId
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'\s+'), '_');

    final datePart =
        formatDate(date).replaceAll('-', '_');

    return '${safeAreaId}_$datePart';
  }

  // ============================================================
  // READ EVENT
  // ============================================================

  Future<CollectionEvent?> getEventForDate({
    required CollectionArea area,
    required DateTime date,
  }) async {
    final eventId = buildEventId(
      areaId: area.areaId,
      date: date,
    );

    final doc =
        await _eventsCollection.doc(eventId).get();

    if (!doc.exists) {
      return null;
    }

    return CollectionEvent.fromDocument(doc);
  }

  Future<CollectionEvent?> getTodayEvent(
    CollectionArea area,
  ) {
    return getEventForDate(
      area: area,
      date: DateTime.now(),
    );
  }

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
  // ============================================================

  Future<void> startCollection({
    required CollectionArea area,
    required CollectionSchedule schedule,
  }) async {
    final user =
        await _requireCollectorAccessForArea(area);

    await _validateAreaAndSchedule(
      area: area,
      schedule: schedule,
    );

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

    final eventRef =
        _eventsCollection.doc(eventId);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(eventRef);

        if (snapshot.exists) {
          final data =
              snapshot.data() ?? <String, dynamic>{};

          _requireEventOwnership(
            data: data,
            collectorUid: user.uid,
            areaName: area.areaName,
          );

          _requireEventMatchesArea(
            data: data,
            area: area,
          );

          final currentStatus =
              data['status']?.toString().trim() ??
                  'pending';

          if (currentStatus == 'in_progress') {
            return;
          }

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

          if (currentStatus != 'pending') {
            throw StateError(
              'This collection event has an invalid status and cannot be started.',
            );
          }

          transaction.update(
            eventRef,
            {
              'status': 'in_progress',
              'collectorId': user.uid,
              if (data['startedAt'] == null)
                'startedAt':
                    FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );

          return;
        }

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
      },
    );
  }

  // ============================================================
  // MARK AS COLLECTED
  // ============================================================

  Future<void> markAsCollected({
    required CollectionArea area,
  }) async {
    final user =
        await _requireCollectorAccessForArea(area);

    final now = DateTime.now();

    final eventId = buildEventId(
      areaId: area.areaId,
      date: now,
    );

    final eventRef =
        _eventsCollection.doc(eventId);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(eventRef);

        if (!snapshot.exists ||
            snapshot.data() == null) {
          throw StateError(
            'Start the collection for ${area.areaName} before marking it as collected.',
          );
        }

        final data = snapshot.data()!;

        _requireEventOwnership(
          data: data,
          collectorUid: user.uid,
          areaName: area.areaName,
        );

        _requireEventMatchesArea(
          data: data,
          area: area,
        );

        final eventDate =
            data['collectionDate']?.toString().trim() ??
                '';

        if (eventDate != formatDate(now)) {
          throw StateError(
            'Only today\'s collection event can be updated.',
          );
        }

        final currentStatus =
            data['status']?.toString().trim() ??
                'pending';

        if (currentStatus == 'collected') {
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
            'collectedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  // ============================================================
  // MARK AS MISSED
  // ============================================================

  Future<void> markAsMissed({
    required CollectionArea area,
    required CollectionSchedule schedule,
  }) async {
    final user =
        await _requireCollectorAccessForArea(area);

    await _validateAreaAndSchedule(
      area: area,
      schedule: schedule,
    );

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

    final eventRef =
        _eventsCollection.doc(eventId);

    await _firestore.runTransaction(
      (transaction) async {
        final snapshot =
            await transaction.get(eventRef);

        if (snapshot.exists) {
          final data =
              snapshot.data() ?? <String, dynamic>{};

          _requireEventOwnership(
            data: data,
            collectorUid: user.uid,
            areaName: area.areaName,
          );

          _requireEventMatchesArea(
            data: data,
            area: area,
          );

          final currentStatus =
              data['status']?.toString().trim() ??
                  'pending';

          if (currentStatus == 'collected') {
            throw StateError(
              '${area.areaName} has already been collected today.',
            );
          }

          if (currentStatus == 'missed') {
            return;
          }

          if (currentStatus != 'pending' &&
              currentStatus != 'in_progress') {
            throw StateError(
              'This collection event has an invalid status and cannot be marked as missed.',
            );
          }

          transaction.update(
            eventRef,
            {
              'status': 'missed',
              'collectorId': user.uid,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );

          return;
        }

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
      },
    );
  }

  // ============================================================
  // CURRENT COLLECTOR EVENTS
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
          .map(CollectionEvent.fromDocument)
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
  // ALL TODAY EVENTS
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
          .map(CollectionEvent.fromDocument)
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
