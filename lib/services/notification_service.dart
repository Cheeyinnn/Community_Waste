import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('notifications');

  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> markAsRead(String id) async {
    await _ref.doc(id).update({'isRead': true});
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String reportId,
  }) async {
    await _ref.add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'reportId': reportId,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }
}
