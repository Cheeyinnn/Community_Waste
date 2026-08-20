import 'package:cloud_firestore/cloud_firestore.dart';

class WasteReport {
  final String id;
  final String userId;
  final String userName;
  final String title;
  final String description;
  final String location; // Full address for display/navigation
  final String area; // Grouped area for analytics/hotspot/priority
  final String wasteType;
  final String imageUrl;
  final String status;
  final String priority;
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
    required this.area,
    required this.wasteType,
    required this.imageUrl,
    required this.status,
    required this.priority,
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
    final dynamic rawLatitude = map['latitude'];
    final dynamic rawLongitude = map['longitude'];
    final dynamic rawCreatedAt = map['createdAt'];
    final dynamic rawUpdatedAt = map['updatedAt'];

    return WasteReport(
      id: docId,
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      area: (map['area'] ?? '').toString(),
      wasteType: (map['wasteType'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      status: (map['status'] ?? 'Pending').toString(),
      priority: (map['priority'] ?? 'Medium').toString(),
      collectorId: (map['collectorId'] ?? '').toString(),
      collectorName: (map['collectorName'] ?? '').toString(),
      adminRemark: (map['adminRemark'] ?? '').toString(),
      collectorRemark: (map['collectorRemark'] ?? '').toString(),
      completionImageUrl: (map['completionImageUrl'] ?? '').toString(),
      latitude: rawLatitude is num ? rawLatitude.toDouble() : 0.0,
      longitude: rawLongitude is num ? rawLongitude.toDouble() : 0.0,
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt : Timestamp.now(),
      updatedAt: rawUpdatedAt is Timestamp
          ? rawUpdatedAt
          : (rawCreatedAt is Timestamp ? rawCreatedAt : Timestamp.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'title': title,
      'description': description,
      'location': location,
      'area': area,
      'wasteType': wasteType,
      'imageUrl': imageUrl,
      'status': status,
      'priority': priority,
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

  WasteReport copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? description,
    String? location,
    String? area,
    String? wasteType,
    String? imageUrl,
    String? status,
    String? priority,
    String? collectorId,
    String? collectorName,
    String? adminRemark,
    String? collectorRemark,
    String? completionImageUrl,
    double? latitude,
    double? longitude,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return WasteReport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      area: area ?? this.area,
      wasteType: wasteType ?? this.wasteType,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      collectorId: collectorId ?? this.collectorId,
      collectorName: collectorName ?? this.collectorName,
      adminRemark: adminRemark ?? this.adminRemark,
      collectorRemark: collectorRemark ?? this.collectorRemark,
      completionImageUrl: completionImageUrl ?? this.completionImageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
