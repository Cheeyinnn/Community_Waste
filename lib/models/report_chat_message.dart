import 'package:cloud_firestore/cloud_firestore.dart';

class ReportChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String type;
  final String text;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String locationLabel;
  final Timestamp createdAt;
  final List<String> readBy;

  const ReportChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.type,
    required this.text,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
    required this.createdAt,
    required this.readBy,
  });

  factory ReportChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawReadBy = data['readBy'];

    return ReportChatMessage(
      id: doc.id,
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? '',
      senderRole: data['senderRole']?.toString() ?? '',
      type: data['type']?.toString() ?? 'text',
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      latitude: data['latitude'] is num
          ? (data['latitude'] as num).toDouble()
          : 0.0,
      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : 0.0,
      locationLabel: data['locationLabel']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      readBy: rawReadBy is Iterable
          ? rawReadBy.map((item) => item.toString()).toList()
          : <String>[],
    );
  }

  bool isMine(String uid) => senderId == uid;

  bool isReadBy(String uid) => readBy.contains(uid);
}
