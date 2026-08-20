import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionSchedule {
  final String id;
  final String area;
  final String district;
  final String state;

  final int dayOfWeek;

  final int startHour;
  final int startMinute;

  final int endHour;
  final int endMinute;

  final String wasteType;
  final bool isActive;
  final String routeName;
  final String collectorId;

  CollectionSchedule({
    required this.id,
    required this.area,
    required this.district,
    required this.state,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.wasteType,
    required this.isActive,
    required this.routeName,
    required this.collectorId,
  });

  factory CollectionSchedule.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return CollectionSchedule(
      id: doc.id,
      area: data['area']?.toString() ?? '',
      district: data['district']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      dayOfWeek: (data['dayOfWeek'] as num?)?.toInt() ?? 1,
      startHour: (data['startHour'] as num?)?.toInt() ?? 8,
      startMinute: (data['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (data['endHour'] as num?)?.toInt() ?? 12,
      endMinute: (data['endMinute'] as num?)?.toInt() ?? 0,
      wasteType: data['wasteType']?.toString() ?? 'General Waste',
      isActive: data['isActive'] as bool? ?? true,
      routeName: data['routeName']?.toString() ?? '',
      collectorId: data['collectorId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'area': area,
      'district': district,
      'state': state,
      'dayOfWeek': dayOfWeek,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'wasteType': wasteType,
      'isActive': isActive,
      'routeName': routeName,
      'collectorId': collectorId,
    };
  }
}
