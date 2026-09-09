import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/report_chat_message.dart';
import '../models/waste_report.dart';

enum ReportChatChannel {
  userCollector,
  adminCollector,
}

class ReportChatThread {
  final WasteReport report;
  final ReportChatMessage? lastMessage;
  final int unreadCount;
  final ReportChatChannel channel;

  const ReportChatThread({
    required this.report,
    required this.lastMessage,
    required this.unreadCount,
    this.channel = ReportChatChannel.userCollector,
  });
}

class ReportChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const Set<String> _openStatuses = {
    'Assigned',
    'In Progress',
    'Completion Submitted',
  };

  CollectionReference<Map<String, dynamic>> _messagesRef(
    String reportId, {
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) {
    final collectionName = channel == ReportChatChannel.adminCollector
        ? 'admin_collector_messages'
        : 'messages';

    return _firestore
        .collection('reports')
        .doc(reportId)
        .collection(collectionName);
  }

  DocumentReference<Map<String, dynamic>> _typingRef(
    String reportId, {
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) {
    final collectionName = channel == ReportChatChannel.adminCollector
        ? 'admin_collector_chat_state'
        : 'chat_state';

    return _firestore
        .collection('reports')
        .doc(reportId)
        .collection(collectionName)
        .doc('presence');
  }

  Stream<List<ReportChatMessage>> watchMessages(
    String reportId, {
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) {
    return _messagesRef(reportId, channel: channel)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ReportChatMessage.fromDocument)
              .toList(),
        );
  }

  Stream<int> watchUnreadCount(
    String reportId, {
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) {
    final uid = _auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return Stream<int>.value(0);
    }

    return watchMessages(reportId, channel: channel).map((messages) {
      return messages.where((message) {
        return message.senderId != uid && !message.readBy.contains(uid);
      }).length;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTypingState(
    String reportId, {
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) {
    return _typingRef(reportId, channel: channel).snapshots();
  }

  Future<String> _currentAccountRole() async {
    final user = _auth.currentUser;

    if (user == null) {
      return '';
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role']?.toString().trim().toLowerCase() ?? '';
  }

  Future<Map<String, dynamic>> _loadReportForWrite(
    String reportId, {
    required ReportChatChannel channel,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to use report chat.');
    }

    final reportDoc = await _firestore.collection('reports').doc(reportId).get();

    if (!reportDoc.exists) {
      throw Exception('Report not found.');
    }

    final data = reportDoc.data() ?? <String, dynamic>{};
    final ownerId = data['userId']?.toString().trim() ?? '';
    final collectorId = data['collectorId']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? '';
    final accountRole = await _currentAccountRole();

    final bool isParticipant;

    if (channel == ReportChatChannel.adminCollector) {
      isParticipant = collectorId.isNotEmpty &&
          (user.uid == collectorId || accountRole == 'admin');
    } else {
      isParticipant = user.uid == ownerId || user.uid == collectorId;
    }

    if (!isParticipant) {
      throw Exception('You are not a participant in this conversation.');
    }

    if (!_openStatuses.contains(status)) {
      throw Exception(
        status == 'Resolved'
            ? 'This report has been resolved. The conversation is read-only.'
            : 'Messaging is not available for this report status.',
      );
    }

    return data;
  }

  Future<String> _senderRoleFromReport(
    Map<String, dynamic> report,
    String uid, {
    required ReportChatChannel channel,
  }) async {
    if (report['collectorId']?.toString() == uid) {
      return 'collector';
    }

    if (channel == ReportChatChannel.adminCollector) {
      final role = await _currentAccountRole();
      if (role == 'admin') {
        return 'admin';
      }
    }

    return 'user';
  }

  Future<String> _senderNameFromReport(
    Map<String, dynamic> report,
    String uid, {
    required ReportChatChannel channel,
  }) async {
    final user = _auth.currentUser;
    final role = await _senderRoleFromReport(
      report,
      uid,
      channel: channel,
    );

    if (role == 'collector') {
      final collectorName = report['collectorName']?.toString().trim() ?? '';
      if (collectorName.isNotEmpty) {
        return collectorName;
      }
      return user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'Collector';
    }

    if (role == 'admin') {
      return user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'Administrator';
    }

    final reportUserName = report['userName']?.toString().trim() ?? '';
    if (reportUserName.isNotEmpty) {
      return reportUserName;
    }

    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }

    return 'User';
  }

  Future<void> sendText({
    required String reportId,
    required String text,
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    if (cleanText.length > 1000) {
      throw Exception('Message must be 1000 characters or fewer.');
    }

    final report = await _loadReportForWrite(reportId, channel: channel);
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to send a message.');
    }

    final senderRole = await _senderRoleFromReport(
      report,
      user.uid,
      channel: channel,
    );
    final senderName = await _senderNameFromReport(
      report,
      user.uid,
      channel: channel,
    );

    await _messagesRef(reportId, channel: channel).add({
      'senderId': user.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'type': 'text',
      'text': cleanText,
      'imageUrl': '',
      'latitude': 0.0,
      'longitude': 0.0,
      'locationLabel': '',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });
  }

  Future<String> uploadChatImage({
    required String reportId,
    required File imageFile,
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to upload a chat image.');
    }

    await _loadReportForWrite(reportId, channel: channel);

    if (!await imageFile.exists()) {
      throw Exception('Selected image does not exist.');
    }

    final length = await imageFile.length();

    if (length <= 0) {
      throw Exception('Selected image is empty.');
    }

    if (length > 10 * 1024 * 1024) {
      throw Exception('Chat image must be 10 MB or smaller.');
    }

    final lowerPath = imageFile.path.toLowerCase();
    String extension = 'jpg';
    String contentType = 'image/jpeg';

    if (lowerPath.endsWith('.png')) {
      extension = 'png';
      contentType = 'image/png';
    } else if (lowerPath.endsWith('.webp')) {
      extension = 'webp';
      contentType = 'image/webp';
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final rootFolder = channel == ReportChatChannel.adminCollector
        ? 'admin_collector_chat_images'
        : 'chat_images';

    final ref = _storage.ref().child(
          '$rootFolder/$reportId/${user.uid}/chat_$timestamp.$extension',
        );

    final task = await ref.putFile(
      imageFile,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=3600',
      ),
    );

    return task.ref.getDownloadURL();
  }

  Future<void> sendImage({
    required String reportId,
    required File imageFile,
    String caption = '',
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final report = await _loadReportForWrite(reportId, channel: channel);
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to send a chat image.');
    }

    final imageUrl = await uploadChatImage(
      reportId: reportId,
      imageFile: imageFile,
      channel: channel,
    );

    final cleanCaption = caption.trim();

    if (cleanCaption.length > 1000) {
      throw Exception('Image caption must be 1000 characters or fewer.');
    }

    final senderRole = await _senderRoleFromReport(
      report,
      user.uid,
      channel: channel,
    );
    final senderName = await _senderNameFromReport(
      report,
      user.uid,
      channel: channel,
    );

    await _messagesRef(reportId, channel: channel).add({
      'senderId': user.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'type': 'image',
      'text': cleanCaption,
      'imageUrl': imageUrl,
      'latitude': 0.0,
      'longitude': 0.0,
      'locationLabel': '',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });
  }

  Future<void> sendReportLocation({
    required String reportId,
    required String locationLabel,
    required double latitude,
    required double longitude,
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final report = await _loadReportForWrite(reportId, channel: channel);
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to share a location.');
    }

    final senderRole = await _senderRoleFromReport(
      report,
      user.uid,
      channel: channel,
    );
    final senderName = await _senderNameFromReport(
      report,
      user.uid,
      channel: channel,
    );

    await _messagesRef(reportId, channel: channel).add({
      'senderId': user.uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'type': 'location',
      'text': '',
      'imageUrl': '',
      'latitude': latitude,
      'longitude': longitude,
      'locationLabel': locationLabel.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
    });
  }

  Future<void> markMessagesRead({
    required String reportId,
    required List<ReportChatMessage> messages,
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final unread = messages.where((message) {
      return message.senderId != user.uid && !message.readBy.contains(user.uid);
    }).take(400).toList();

    if (unread.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final message in unread) {
      batch.update(
        _messagesRef(reportId, channel: channel).doc(message.id),
        {
          'readBy': FieldValue.arrayUnion([user.uid]),
        },
      );
    }

    await batch.commit();
  }

  Future<void> setTyping({
    required String reportId,
    required String role,
    required bool isTyping,
    ReportChatChannel channel = ReportChatChannel.userCollector,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    String cleanRole;

    if (channel == ReportChatChannel.adminCollector) {
      cleanRole = role == 'admin' ? 'admin' : 'collector';
    } else {
      cleanRole = role == 'collector' ? 'collector' : 'user';
    }

    try {
      await _typingRef(reportId, channel: channel).set(
        {
          '${cleanRole}Typing': isTyping,
          '${cleanRole}TypingAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Typing presence is a convenience only and should never block chat.
    }
  }

  bool _isThreadEligible(
    WasteReport report,
    String currentRole,
  ) {
    if (report.collectorId.trim().isEmpty) {
      return false;
    }

    if (currentRole == 'user') {
      return report.status != 'Pending';
    }

    return true;
  }

  List<ReportChatChannel> _channelsForRole(String currentRole) {
    switch (currentRole) {
      case 'admin':
        return const [ReportChatChannel.adminCollector];
      case 'collector':
        return const [
          ReportChatChannel.userCollector,
          ReportChatChannel.adminCollector,
        ];
      case 'user':
      default:
        return const [ReportChatChannel.userCollector];
    }
  }

  Stream<List<ReportChatThread>> watchThreads({
    required String currentRole,
  }) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<List<ReportChatThread>>.value(
        const <ReportChatThread>[],
      );
    }

    final cleanRole = currentRole.trim().toLowerCase();
    final channels = _channelsForRole(cleanRole);
    final controller = StreamController<List<ReportChatThread>>();

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        reportsSubscription;

    final messageSubscriptions =
        <String, StreamSubscription<List<ReportChatMessage>>>{};

    final reports = <String, WasteReport>{};
    final latestMessages = <String, ReportChatMessage?>{};
    final unreadCounts = <String, int>{};

    int generation = 0;
    bool cancelled = false;

    String threadKey(String reportId, ReportChatChannel channel) {
      return '$reportId:${channel.name}';
    }

    void emit() {
      if (cancelled || controller.isClosed) {
        return;
      }

      final threads = <ReportChatThread>[];

      for (final report in reports.values) {
        for (final channel in channels) {
          final key = threadKey(report.id, channel);
          threads.add(
            ReportChatThread(
              report: report,
              lastMessage: latestMessages[key],
              unreadCount: unreadCounts[key] ?? 0,
              channel: channel,
            ),
          );
        }
      }

      threads.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.report.updatedAt;
        final bTime = b.lastMessage?.createdAt ?? b.report.updatedAt;

        final timeCompare = bTime.compareTo(aTime);
        if (timeCompare != 0) {
          return timeCompare;
        }

        return a.report.title
            .toLowerCase()
            .compareTo(b.report.title.toLowerCase());
      });

      controller.add(threads);
    }

    Future<void> replaceReports(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      generation += 1;
      final localGeneration = generation;

      final oldSubscriptions = messageSubscriptions.values.toList();
      messageSubscriptions.clear();

      for (final subscription in oldSubscriptions) {
        await subscription.cancel();
      }

      if (cancelled || localGeneration != generation) {
        return;
      }

      reports.clear();
      latestMessages.clear();
      unreadCounts.clear();

      for (final doc in snapshot.docs) {
        final report = WasteReport.fromMap(doc.data(), doc.id);

        if (!_isThreadEligible(report, cleanRole)) {
          continue;
        }

        reports[report.id] = report;

        for (final channel in channels) {
          final key = threadKey(report.id, channel);
          latestMessages[key] = null;
          unreadCounts[key] = 0;

          messageSubscriptions[key] = watchMessages(
            report.id,
            channel: channel,
          ).listen(
            (messages) {
              if (cancelled || localGeneration != generation) {
                return;
              }

              latestMessages[key] = messages.isEmpty ? null : messages.first;

              unreadCounts[key] = messages.where((message) {
                return message.senderId != user.uid &&
                    !message.readBy.contains(user.uid);
              }).length;

              emit();
            },
            onError: (_) {
              emit();
            },
          );
        }
      }

      emit();
    }

    Query<Map<String, dynamic>> reportQuery =
        _firestore.collection('reports');

    if (cleanRole == 'collector') {
      reportQuery = reportQuery.where(
        'collectorId',
        isEqualTo: user.uid,
      );
    } else if (cleanRole == 'user') {
      reportQuery = reportQuery.where(
        'userId',
        isEqualTo: user.uid,
      );
    }

    reportsSubscription = reportQuery.snapshots().listen(
      (snapshot) {
        replaceReports(snapshot);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!cancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
    );

    controller.onCancel = () async {
      cancelled = true;
      generation += 1;

      await reportsSubscription?.cancel();

      final subscriptions = messageSubscriptions.values.toList();
      messageSubscriptions.clear();

      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Stream<int> watchGlobalUnreadCount({
    required String currentRole,
  }) {
    return watchThreads(currentRole: currentRole).map(
      (threads) => threads.fold<int>(
        0,
        (total, thread) => total + thread.unreadCount,
      ),
    );
  }
}
