import 'package:cloud_firestore/cloud_firestore.dart';

class WasteReport {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final String location;
  final String wasteType;
  final String imageUrl;
  final String status;
  final String collectorId;
  final String collectorName;
  final String adminRemark;
  final String collectorRemark;
  final String completionImageUrl;
  final double latitude;
  final double longitude;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  WasteReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.description,
    required this.location,
    required this.wasteType,
    required this.imageUrl,
    required this.status,
    required this.collectorId,
    required this.collectorName,
    required this.adminRemark,
    required this.collectorRemark,
    required this.completionImageUrl,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WasteReport.fromMap(Map<String, dynamic> map, String docId) {
    return WasteReport(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      wasteType: map['wasteType'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'Pending',
      collectorId: map['collectorId'] ?? '',
      collectorName: map['collectorName'] ?? '',
      adminRemark: map['adminRemark'] ?? '',
      collectorRemark: map['collectorRemark'] ?? '',
      completionImageUrl: map['completionImageUrl'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location,
      'wasteType': wasteType,
      'imageUrl': imageUrl,
      'status': status,
      'collectorId': collectorId,
      'collectorName': collectorName,
      'adminRemark': adminRemark,
      'collectorRemark': collectorRemark,
      'completionImageUrl': completionImageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}