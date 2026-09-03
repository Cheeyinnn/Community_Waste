import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/collection_schedule_service.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final WasteReport report;
  final String? initialPriorityOverride;

  const AdminReportDetailScreen({
    super.key,
    required this.report,
    this.initialPriorityOverride,
  });

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final CollectionScheduleService _scheduleService =
      CollectionScheduleService();
  final TextEditingController _adminRemarkController = TextEditingController();

  late String _selectedStatus;
  late String _selectedPriority;

  bool _isUpdating = false;
  String? _selectedCollectorId;
  String? _selectedCollectorName;

  bool _isLoadingReportZone = true;
  String _reportZoneId = '';
  String _reportZoneName = '';
  String _reportZoneArea = '';

  final List<String> _statusOptions = ['Pending', 'Assigned', 'Rejected'];

  final List<String> _priorityOptions = ['High', 'Medium', 'Low'];

  bool get _isCollectorManagedReport {
    return _selectedStatus == 'In Progress' ||
        _selectedStatus == 'Completion Submitted' ||
        _selectedStatus == 'Resolved';
  }

  bool get _isCompletionAwaitingReview {
    return _selectedStatus == 'Completion Submitted';
  }

  @override
  void initState() {
    super.initState();

    _selectedStatus = widget.report.status;
    _selectedPriority =
        widget.initialPriorityOverride ?? widget.report.priority;
    _adminRemarkController.text = widget.report.adminRemark;

    if (widget.report.collectorId.isNotEmpty) {
      _selectedCollectorId = widget.report.collectorId;
      _selectedCollectorName = widget.report.collectorName;
    }

    _loadReportZone();
  }

  @override
  void dispose() {
    _adminRemarkController.dispose();
    super.dispose();
  }

  void _goBack() {
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    _goBack();
    return false;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.blue;
      case 'Completion Submitted':
        return Colors.amber.shade800;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadReportZone() async {
    String zoneId = '';
    String zoneName = '';
    String zoneArea = '';

    try {
      // ----------------------------------------------------------
      // 1. Prefer zone metadata already saved on the report.
      // ----------------------------------------------------------
      final reportDoc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .get();

      final reportData =
          reportDoc.data() ?? <String, dynamic>{};

      zoneId =
          reportData['zoneId']?.toString().trim() ?? '';
      zoneName =
          reportData['zoneName']?.toString().trim() ?? '';
      zoneArea =
          reportData['zoneArea']?.toString().trim() ?? '';

      // ----------------------------------------------------------
      // 2. If the report has areaId, resolve its CollectionArea.
      // ----------------------------------------------------------
      if (zoneId.isEmpty) {
        final areaId =
            reportData['areaId']?.toString().trim() ?? '';

        if (areaId.isNotEmpty) {
          final area =
              await _scheduleService.getAreaById(areaId);

          if (area != null) {
            zoneId = area.zoneId.trim();
            zoneName = area.zoneName.trim();
            zoneArea = area.zoneArea.trim();
          }
        }
      }

      // ----------------------------------------------------------
      // 3. Legacy report fallback:
      //    match the report's actual area/location against the
      //    collection-area metadata already used by the app.
      // ----------------------------------------------------------
      if (zoneId.isEmpty) {
        final reportArea =
            widget.report.area.trim();
        final reportLocation =
            widget.report.location.trim();

        final matchedArea =
            await _scheduleService.findCollectionAreaFromLocation(
          <String>[
            if (reportArea.isNotEmpty) reportArea,
            if (reportLocation.isNotEmpty) reportLocation,
          ],
        );

        if (matchedArea != null) {
          zoneId = matchedArea.zoneId.trim();
          zoneName = matchedArea.zoneName.trim();
          zoneArea = matchedArea.zoneArea.trim();
        }
      }
    } catch (_) {
      // A zone warning will be shown below. Do not fall back to
      // showing every collector because that could assign a report
      // to a collector from the wrong zone.
    }

    if (!mounted) return;

    setState(() {
      _reportZoneId = zoneId;
      _reportZoneName = zoneName;
      _reportZoneArea = zoneArea;
      _isLoadingReportZone = false;
    });
  }

  String get _reportZoneDisplay {
    if (_reportZoneId.isEmpty) {
      return 'Zone not identified';
    }

    final parts = <String>[];

    if (_reportZoneName.isNotEmpty) {
      parts.add(_reportZoneName);
    }

    if (_reportZoneArea.isNotEmpty &&
        !_reportZoneName
            .toLowerCase()
            .contains(_reportZoneArea.toLowerCase())) {
      parts.add(_reportZoneArea);
    }

    if (parts.isEmpty) {
      return _reportZoneId;
    }

    return parts.join(' • ');
  }

  bool _collectorMatchesReportZone(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (_reportZoneId.isEmpty) {
      return false;
    }

    final rawZones =
        doc.data()['assignedCollectionZoneIds'];

    if (rawZones is! Iterable) {
      return false;
    }

    final collectorZones = rawZones
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    return collectorZones.contains(_reportZoneId);
  }

  Widget _buildReportZoneCard() {
    if (_isLoadingReportZone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identifying report collection zone...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final zoneFound = _reportZoneId.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zoneFound
            ? Colors.blue.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: zoneFound
              ? Colors.blue.shade100
              : Colors.orange.shade100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            zoneFound
                ? Icons.location_on_outlined
                : Icons.warning_amber_rounded,
            color: zoneFound
                ? Colors.blue.shade700
                : Colors.orange.shade700,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  zoneFound
                      ? 'Report Collection Zone'
                      : 'Collection Zone Not Identified',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: zoneFound
                        ? Colors.blue.shade800
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  zoneFound
                      ? _reportZoneDisplay
                      : 'Collector assignment is disabled until this '
                          'report can be matched to a Kampar collection zone.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: zoneFound
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: zoneFound
                        ? Colors.blue.shade900
                        : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    if (_isCollectorManagedReport) {
      _showError(
        'This report is already being handled by the collector '
        'and can no longer be changed from Admin Actions.',
      );
      return;
    }

    if (_selectedStatus == 'Assigned' &&
        _reportZoneId.isEmpty) {
      _showError(
        'Unable to identify this report\'s collection zone. '
        'Collector assignment is disabled.',
      );
      return;
    }

    if (_selectedStatus == 'Assigned' && _selectedCollectorId == null) {
      _showError('Please select a collector from the report zone first');
      return;
    }

    if (_selectedStatus == 'Rejected' &&
        _adminRemarkController.text.trim().isEmpty) {
      _showError('Please enter a reason for rejection');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_selectedStatus == 'Rejected') {
        await _firestoreService.rejectReport(
          reportId: widget.report.id,
          adminRemark: _adminRemarkController.text.trim(),
          priority: _selectedPriority,
        );
      } else if (_selectedStatus == 'Assigned') {
        await _firestoreService.assignCollector(
          reportId: widget.report.id,
          collectorId: _selectedCollectorId!,
          collectorName: _selectedCollectorName ?? 'Unnamed Collector',
          adminRemark: _adminRemarkController.text.trim(),
          priority: _selectedPriority,
        );
      } else {
        await _firestoreService.updateReportStatus(
          reportId: widget.report.id,
          status: _selectedStatus,
        );

        await _firestoreService.updateReportPriority(
          reportId: widget.report.id,
          priority: _selectedPriority,
        );
      }

      if (!mounted) return;

      // true means previous admin page should refresh.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError('Update failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _showCompletionImagePreview(String imageUrl) async {
    if (!mounted || imageUrl.trim().isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: MediaQuery.of(dialogContext).size.height * 0.72,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 52,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Unable to load completion image',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatFirestoreTimestamp(dynamic value) {
    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(value.toDate());
    }

    return '-';
  }

  Future<void> _approveCompletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Approve Completion?'),
              ),
            ],
          ),
          content: const Text(
            'Confirm that the collector completion evidence is acceptable. '
            'The report will be marked as Resolved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve & Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _firestoreService.approveCollectorCompletion(
        reportId: widget.report.id,
      );

      if (!mounted) return;

      setState(() {
        _selectedStatus = 'Resolved';
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completion approved. The report is now Resolved.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      _showError('Failed to approve completion: $e');
    }
  }

  Future<void> _rejectCompletion() async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        bool canSubmit = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Reject Completion'),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tell the collector why the completion evidence '
                    'cannot be accepted.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    autofocus: true,
                    maxLines: 3,
                    onChanged: (value) {
                      setDialogState(() {
                        canSubmit = value.trim().isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason',
                      hintText:
                          'Example: The photo does not clearly show the waste was removed.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(dialogContext).pop(
                            reasonController.text.trim(),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject & Return'),
                ),
              ],
            );
          },
        );
      },
    );

    // The dialog route is still completing its closing animation here.
    // Disposing the controller immediately can trigger Flutter's
    // `_dependents.isEmpty` assertion while TextField is unmounting.
    Future.delayed(const Duration(milliseconds: 400), () {
      reasonController.dispose();
    });

    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _firestoreService.rejectCollectorCompletion(
        reportId: widget.report.id,
        rejectionReason: reason,
      );

      if (!mounted) return;

      setState(() {
        _selectedStatus = 'In Progress';
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completion rejected. The task was returned to the collector.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });

      _showError('Failed to reject completion: $e');
    }
  }

  Widget _buildCompletionReviewSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final liveStatus =
            data['status']?.toString().trim() ?? _selectedStatus;

        final completionUrl =
            data['completionImageUrl']?.toString().trim() ?? '';

        final collectorName =
            data['collectorName']?.toString().trim() ?? '';

        final collectorRemark =
            data['collectorRemark']?.toString().trim() ?? '';

        final verificationStatus =
            data['completionVerificationStatus']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final rejectionReason =
            data['completionRejectionReason']?.toString().trim() ?? '';

        final submittedAt = data['completionSubmittedAt'];

        final reviewedAt = data['completionReviewedAt'];

        final bool awaitingReview =
            liveStatus == 'Completion Submitted' &&
            verificationStatus == 'pending';

        final bool approved =
            liveStatus == 'Resolved' &&
            (verificationStatus == 'approved' ||
                completionUrl.isNotEmpty);

        final bool rejected =
            liveStatus == 'In Progress' &&
            verificationStatus == 'rejected';

        if (completionUrl.isEmpty &&
            !awaitingReview &&
            !approved &&
            !rejected) {
          return const SizedBox.shrink();
        }

        final Color accentColor = awaitingReview
            ? Colors.amber.shade800
            : approved
                ? Colors.green
                : rejected
                    ? Colors.red
                    : Colors.blue;

        String stateTitle = 'Completion Evidence';

        if (awaitingReview) {
          stateTitle = 'Waiting for Admin Verification';
        } else if (approved) {
          stateTitle = 'Completion Approved';
        } else if (rejected) {
          stateTitle = 'Completion Rejected';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      awaitingReview
                          ? Icons.fact_check_outlined
                          : approved
                              ? Icons.verified_rounded
                              : rejected
                                  ? Icons.cancel_outlined
                                  : Icons.photo_camera_back_outlined,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Collector Completion Proof',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stateTitle,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (completionUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () =>
                      _showCompletionImagePreview(completionUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        completionUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 46,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Center(
                  child: Text(
                    'Tap photo to view larger',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _completionInfoRow(
                Icons.person_outline_rounded,
                'Submitted by',
                collectorName.isEmpty
                    ? 'Assigned collector'
                    : collectorName,
              ),
              _completionInfoRow(
                Icons.schedule_rounded,
                'Submitted at',
                _formatFirestoreTimestamp(submittedAt),
              ),
              if (reviewedAt != null)
                _completionInfoRow(
                  Icons.fact_check_outlined,
                  approved ? 'Approved at' : 'Reviewed at',
                  _formatFirestoreTimestamp(reviewedAt),
                ),
              if (collectorRemark.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Collector Remark',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        collectorRemark,
                        style: const TextStyle(
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (rejected && rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.red.shade100,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Rejection Reason',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        rejectionReason,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (awaitingReview) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.shade200,
                    ),
                  ),
                  child: Text(
                    'Compare this completion photo with the original report '
                    'evidence above. Approve it only when the submitted '
                    'evidence reasonably shows the reported issue was handled.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      height: 1.4,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isUpdating ? null : _rejectCompletion,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text(
                          'Reject Completion',
                          textAlign: TextAlign.center,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isUpdating ? null : _approveCompletion,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'Approve & Resolve',
                          textAlign: TextAlign.center,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _completionInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 9),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
              fontSize: 12.5,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap() async {
    final String query = Uri.encodeComponent(widget.report.location);
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      _showError("Could not launch Google Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatusColor = _getStatusColor(_selectedStatus);
    final currentPriorityColor = _getPriorityColor(_selectedPriority);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF6FF),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _goBack,
          ),
          title: const Text(
            "Report Details",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Evidence"),
              _buildImageContainer(widget.report.imageUrl),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildSectionTitle("Completion Review"),
              _buildCompletionReviewSection(),
              const SizedBox(height: 24),
              _buildSectionTitle("Admin Actions"),
              _buildActionCard(currentStatusColor, currentPriorityColor),
            ],
          ),
        ),
        bottomSheet: _buildBottomActionBar(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildImageContainer(String url) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  );
                },
              )
            : const Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.title, "Title", widget.report.title),
          _infoRow(Icons.eco_outlined, "Type", widget.report.wasteType),
          _infoRow(
            Icons.description_outlined,
            "Description",
            widget.report.description.isEmpty ? '-' : widget.report.description,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Location: ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _openMap,
                    child: Text(
                      widget.report.location,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _infoRow(
            Icons.map_outlined,
            "Area",
            widget.report.area.trim().isEmpty
                ? '-'
                : widget.report.area,
          ),
          _infoRow(
            Icons.route_outlined,
            "Zone",
            _isLoadingReportZone
                ? 'Identifying...'
                : _reportZoneDisplay,
          ),
          _infoRow(
            Icons.person_outline,
            "Reporter",
            widget.report.userName.isNotEmpty
                ? widget.report.userName
                : "Unknown User",
          ),
          _infoRow(
            Icons.calendar_today_outlined,
            "Date",
            DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(widget.report.createdAt.toDate()),
          ),
          _infoRow(
            Icons.assignment_ind_outlined,
            "Collector",
            widget.report.collectorName.isEmpty
                ? '-'
                : widget.report.collectorName,
          ),
          _infoRow(
            Icons.note_alt_outlined,
            "Admin Remark",
            widget.report.adminRemark.isEmpty ? '-' : widget.report.adminRemark,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    Color currentStatusColor,
    Color currentPriorityColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          if (_isCollectorManagedReport)
            TextFormField(
              initialValue: _selectedStatus,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: "Current Status",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  _selectedStatus == 'Resolved'
                      ? Icons.check_circle_rounded
                      : _selectedStatus == 'Completion Submitted'
                          ? Icons.fact_check_outlined
                          : Icons.timelapse_rounded,
                  color: currentStatusColor,
                ),
                filled: true,
                fillColor: currentStatusColor.withOpacity(0.06),
              ),
              style: TextStyle(
                color: currentStatusColor,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _statusOptions.contains(_selectedStatus)
                  ? _selectedStatus
                  : 'Pending',
              decoration: InputDecoration(
                labelText: "Set Status",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  Icons.flag_rounded,
                  color: currentStatusColor,
                ),
              ),
              items: _statusOptions.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;

                setState(() {
                  _selectedStatus = val;
                });
              },
            ),
          if (_isCollectorManagedReport) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedStatus == 'Resolved'
                    ? Colors.green.shade50
                    : _selectedStatus == 'Completion Submitted'
                        ? Colors.amber.shade50
                        : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedStatus == 'Resolved'
                      ? Colors.green.shade100
                      : _selectedStatus == 'Completion Submitted'
                          ? Colors.amber.shade200
                          : Colors.blue.shade100,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: _selectedStatus == 'Resolved'
                        ? Colors.green.shade700
                        : _selectedStatus == 'Completion Submitted'
                            ? Colors.amber.shade900
                            : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedStatus == 'Resolved'
                          ? 'This report has been resolved after completion '
                              'verification. Admin assignment controls are '
                              'locked to protect the completed record.'
                          : _selectedStatus == 'Completion Submitted'
                              ? 'The collector has submitted completion '
                                  'evidence. Review the proof above and '
                                  'approve or reject it before making any '
                                  'further assignment changes.'
                              : 'This report is currently in progress. The '
                                  'assigned collector is handling the task, '
                                  'so Admin assignment controls are locked.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: _selectedStatus == 'Resolved'
                            ? Colors.green.shade900
                            : _selectedStatus == 'Completion Submitted'
                                ? Colors.amber.shade900
                                : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priorityOptions.contains(_selectedPriority)
                ? _selectedPriority
                : 'Medium',
            decoration: InputDecoration(
              labelText: "Set Priority",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Icon(
                Icons.priority_high_rounded,
                color: currentPriorityColor,
              ),
            ),
            items: _priorityOptions.map((p) {
              return DropdownMenuItem(value: p, child: Text(p));
            }).toList(),
            onChanged: _isCollectorManagedReport
                ? null
                : (val) {
                    if (val == null) return;

                    setState(() {
                      _selectedPriority = val;
                    });
                  },
          ),
          const SizedBox(height: 16),
          _buildReportZoneCard(),
          const SizedBox(height: 12),
          if (_isCollectorManagedReport)
            TextFormField(
              initialValue: widget.report.collectorName.trim().isEmpty
                  ? 'Assigned collector'
                  : widget.report.collectorName,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: "Assigned Collector",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(
                  Icons.assignment_ind_outlined,
                  color: Colors.blue,
                ),
                filled: true,
                fillColor: Colors.blue.shade50.withOpacity(0.45),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            )
          else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'collector')
                .snapshots(),
            builder: (context, snapshot) {
              if (_isLoadingReportZone ||
                  snapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  ),
                );
              }

              final allCollectorDocs =
                  snapshot.data?.docs ?? [];

              final docs = allCollectorDocs
                  .where(_collectorMatchesReportZone)
                  .toList();

              final bool isValidCollector = docs.any(
                (doc) => doc.id == _selectedCollectorId,
              );

              if (!isValidCollector) {
                _selectedCollectorId = null;
                _selectedCollectorName = null;
              }

              if (_reportZoneId.isEmpty) {
                return DropdownButtonFormField<String>(
                  value: null,
                  decoration: InputDecoration(
                    labelText: "Assign Collector",
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.delivery_dining_rounded,
                      color: Colors.grey,
                    ),
                  ),
                  hint: const Text(
                    'Report zone must be identified first',
                  ),
                  items: const [],
                  onChanged: null,
                );
              }

              if (docs.isEmpty) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: null,
                      decoration: InputDecoration(
                        labelText: "Assign Collector",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.grey,
                        ),
                      ),
                      hint: const Text(
                        'No collector available for this zone',
                      ),
                      items: const [],
                      onChanged: null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No approved collector is assigned to '
                      '$_reportZoneDisplay.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }

              return DropdownButtonFormField<String>(
                value: _selectedCollectorId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: "Assign Collector",
                  helperText:
                      'Only collectors assigned to $_reportZoneDisplay are shown.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.blue,
                  ),
                ),
                hint: const Text(
                  'Select a collector',
                ),
                items: docs.map((doc) {
                  final data = doc.data();

                  final name =
                      data['name']?.toString().trim();

                  final email =
                      data['email']?.toString().trim();

                  final displayName =
                      name != null && name.isNotEmpty
                          ? name
                          : 'Unknown Collector';

                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(
                      email != null && email.isNotEmpty
                          ? '$displayName • $email'
                          : displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;

                  final matchedDoc =
                      docs.firstWhere(
                    (d) => d.id == val,
                  );

                  final data = matchedDoc.data();

                  final name =
                      data['name']?.toString().trim();

                  setState(() {
                    _selectedCollectorId = val;
                    _selectedCollectorName =
                        name != null && name.isNotEmpty
                            ? name
                            : 'Unknown Collector';

                    if (_selectedStatus == 'Pending') {
                      _selectedStatus = 'Assigned';
                    }
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminRemarkController,
            maxLines: 3,
            enabled: !_isCollectorManagedReport,
            decoration: InputDecoration(
              labelText: "Admin Remark",
              hintText: "Add notes or rejection reason...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_isCollectorManagedReport) {
      final bool isResolved = _selectedStatus == 'Resolved';
      final bool isAwaitingReview =
          _selectedStatus == 'Completion Submitted';

      final Color barColor = isResolved
          ? Colors.green
          : isAwaitingReview
              ? Colors.amber.shade800
              : Colors.blue;

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isResolved
                      ? Icons.verified_rounded
                      : isAwaitingReview
                          ? Icons.fact_check_outlined
                          : Icons.timelapse_rounded,
                  color: barColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isResolved
                        ? 'Resolved Report • Read Only'
                        : isAwaitingReview
                            ? 'Completion Submitted • Review Required'
                            : 'Report Task In Progress • Read Only',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _handleUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save Updates",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
