import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community_waste_app/models/app_user.dart';
import 'package:community_waste_app/models/waste_report.dart';

void main() {
  group('WasteReport model', () {
    test('creates and restores a normal pending report', () {
      final now = Timestamp.fromDate(
        DateTime(2026, 9, 7, 12, 0),
      );

      final report = WasteReport(
        id: 'report_1',
        userId: 'user_1',
        userName: 'Test User',
        title: 'Illegal dumping',
        description: 'Waste found near the roadside.',
        location: 'Kampar, Perak',
        area: 'Kampar',
        wasteType: 'Illegal Dumping',
        imageUrl: 'https://example.com/report.jpg',
        status: 'Pending',
        priority: 'Medium',
        collectorId: '',
        collectorName: '',
        adminRemark: '',
        collectorRemark: '',
        completionImageUrl: '',
        latitude: 4.3300,
        longitude: 101.1500,
        createdAt: now,
        updatedAt: now,
      );

      final restored = WasteReport.fromMap(
        report.toMap(),
        report.id,
      );

      expect(restored.id, 'report_1');
      expect(restored.userId, 'user_1');
      expect(restored.status, 'Pending');
      expect(restored.priority, 'Medium');
      expect(restored.isPending, isTrue);
      expect(restored.hasCollector, isFalse);
      expect(restored.hasCompletionEvidence, isFalse);
    });

    test('restores collector completion review fields', () {
      final submittedAt = Timestamp.fromDate(
        DateTime(2026, 9, 7, 13, 0),
      );

      final reviewedAt = Timestamp.fromDate(
        DateTime(2026, 9, 7, 14, 0),
      );

      final report = WasteReport.fromMap(
        {
          'userId': 'user_1',
          'userName': 'Test User',
          'title': 'Bulky waste',
          'description': 'Large waste item.',
          'location': 'Kampar, Perak',
          'area': 'Kampar',
          'wasteType': 'Bulky Waste',
          'imageUrl': 'https://example.com/report.jpg',
          'status': 'Resolved',
          'priority': 'High',
          'collectorId': 'collector_1',
          'collectorName': 'Collector',
          'adminRemark': '',
          'collectorRemark': 'Collected successfully.',
          'completionImageUrl':
              'https://example.com/completion.jpg',
          'completionVerificationStatus': 'approved',
          'completionRejectionReason': '',
          'completionReviewedBy': 'admin_1',
          'completionSubmittedAt': submittedAt,
          'completionReviewedAt': reviewedAt,
          'resolvedAt': reviewedAt,
          'latitude': 4.3300,
          'longitude': 101.1500,
          'createdAt': submittedAt,
          'updatedAt': reviewedAt,
        },
        'report_2',
      );

      expect(report.isResolved, isTrue);
      expect(report.hasCollector, isTrue);
      expect(report.hasCompletionEvidence, isTrue);
      expect(report.completionApproved, isTrue);
      expect(
        report.completionReviewedBy,
        'admin_1',
      );
      expect(
        report.completionSubmittedAt,
        submittedAt,
      );
      expect(
        report.completionReviewedAt,
        reviewedAt,
      );
    });
  });

  group('AppUser model', () {
    test('restores approved collector information', () {
      final approvedAt = Timestamp.fromDate(
        DateTime(2026, 9, 7, 10, 0),
      );

      final user = AppUser.fromMap(
        {
          'name': 'Collector Name',
          'displayName': 'Collector Name',
          'email': 'collector@example.com',
          'role': 'collector',
          'profileImageUrl':
              'https://example.com/profile.jpg',
          'emailVerificationRequired': true,
          'emailVerified': true,
          'collectorApplicationStatus': 'approved',
          'assignedCollectionZoneIds': [
            'kampar_zone_1',
            'kampar_zone_2',
          ],
          'collectorApprovedAt': approvedAt,
          'collectorApprovalAcknowledged': true,
          'collectorApprovalAcknowledgedAt': approvedAt,
        },
        'collector_1',
      );

      expect(user.uid, 'collector_1');
      expect(user.isCollector, isTrue);
      expect(user.isApprovedCollector, isTrue);
      expect(user.emailVerified, isTrue);
      expect(
        user.assignedCollectionZoneIds,
        contains('kampar_zone_1'),
      );
      expect(
        user.hasAssignedCollectionZones,
        isTrue,
      );
      expect(
        user.effectiveDisplayName,
        'Collector Name',
      );
    });

    test('falls back from displayName/profileImageUrl safely', () {
      final user = AppUser.fromMap(
        {
          'name': 'Normal User',
          'email': 'user@example.com',
          'role': 'user',
          'photoUrl': 'https://example.com/old-profile.jpg',
        },
        'user_1',
      );

      expect(
        user.effectiveDisplayName,
        'Normal User',
      );
      expect(
        user.effectiveProfileImageUrl,
        'https://example.com/old-profile.jpg',
      );
      expect(user.isUser, isTrue);
      expect(user.isApprovedCollector, isFalse);
    });
  });
}
