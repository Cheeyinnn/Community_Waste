import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class CollectorReportDetailScreen extends StatefulWidget {
  final WasteReport report;

  const CollectorReportDetailScreen({
    super.key,
    required this.report,
  });

  @override
  State<CollectorReportDetailScreen> createState() =>
      _CollectorReportDetailScreenState();
}

class _CollectorReportDetailScreenState
    extends State<CollectorReportDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  void _goBackToTaskList() {
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    _goBackToTaskList();
    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.blue;
      case 'Completion Submitted':
        return Colors.amber.shade800;
      case 'Submit Completion':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No date';

    try {
      final date = timestamp.toDate();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return 'No date';
    }
  }

  Future<void> _openGoogleMaps(WasteReport report) async {
    final String query = Uri.encodeComponent(report.location);

    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showNavigationOptions(WasteReport report) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Navigation Options',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to proceed with this task.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _openGoogleMaps(report);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      'View Location Only',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();

                      try {
                        if (report.status == 'Assigned') {
                          await _firestoreService.startCollectorTask(
                            reportId: report.id,
                            collectorRemark:
                                report.collectorRemark.isNotEmpty
                                    ? report.collectorRemark
                                    : 'Started via navigation',
                          );
                        }

                        await _openGoogleMaps(report);

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              report.status == 'Assigned'
                                  ? 'Task started and navigating...'
                                  : 'Navigating to location...',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      report.status == 'Assigned'
                          ? Icons.play_arrow_rounded
                          : Icons.navigation_rounded,
                    ),
                    label: Text(
                      report.status == 'Assigned'
                          ? 'Start Task & Navigate'
                          : 'Navigate to Location',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showUpdateBottomSheet(
    WasteReport report,
  ) async {
    if (report.status == 'Completion Submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completion evidence is waiting for Admin review.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (report.status == 'Resolved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This report has already been resolved.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    String selectedAction =
        report.status == 'Assigned' ? 'Assigned' : 'In Progress';

    final TextEditingController remarkController =
        TextEditingController(
      text: report.collectorRemark,
    );

    File? completionImageFile;
    bool isSaving = false;

    final List<String> actions = report.status == 'Assigned'
        ? ['Assigned', 'In Progress']
        : ['In Progress', 'Submit Completion'];

    Future<void> pickCompletionImage(
      StateSetter setStateSheet,
    ) async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (picked != null) {
        setStateSheet(() {
          completionImageFile = File(picked.path);
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setStateSheet) {
            final bool isSubmittingCompletion =
                selectedAction == 'Submit Completion';

            final Color selectedColor =
                _statusColor(selectedAction);

            return Container(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Update Report Task',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your progress or submit completion evidence '
                      'for Admin verification.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Action',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: actions.map((action) {
                        final bool isSelected =
                            selectedAction == action;
                        final Color color =
                            _statusColor(action);

                        return ChoiceChip(
                          label: Text(action),
                          selected: isSelected,
                          onSelected: (val) {
                            if (!val) return;

                            setStateSheet(() {
                              selectedAction = action;

                              if (action != 'Submit Completion') {
                                completionImageFile = null;
                              }
                            });
                          },
                          selectedColor: color,
                          backgroundColor:
                              Colors.grey.shade100,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                    if (isSubmittingCompletion) ...[
                      const SizedBox(height: 14),
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
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              color: Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Submitting completion does not immediately '
                                'resolve the report. Admin will review your '
                                'photo and remark first.',
                                style: TextStyle(
                                  color:
                                      Colors.amber.shade900,
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Collector Remark',
                        hintText: isSubmittingCompletion
                            ? 'Describe the completed work...'
                            : 'Enter task progress note...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.orange.shade400,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    if (isSubmittingCompletion) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Completion Evidence',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Upload a new photo showing the completed work.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () =>
                            pickCompletionImage(setStateSheet),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius:
                                BorderRadius.circular(16),
                            border:
                                completionImageFile == null
                                    ? Border.all(
                                        color:
                                            Colors.orange.shade300,
                                        width: 2,
                                      )
                                    : null,
                          ),
                          child: completionImageFile != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  child: Image.file(
                                    completionImageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_rounded,
                                      size: 42,
                                      color:
                                          Colors.orange.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to upload new proof photo',
                                      style: TextStyle(
                                        color:
                                            Colors.orange.shade700,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (isSubmittingCompletion &&
                                    completionImageFile == null) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please upload a new completion image',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setStateSheet(() {
                                  isSaving = true;
                                });

                                try {
                                  if (selectedAction ==
                                      'In Progress') {
                                    await _firestoreService
                                        .startCollectorTask(
                                      reportId: report.id,
                                      collectorRemark:
                                          remarkController.text
                                              .trim(),
                                    );
                                  } else if (selectedAction ==
                                      'Submit Completion') {
                                    final completionImageUrl =
                                        await _storageService
                                            .uploadCompletionImage(
                                      completionImageFile!,
                                    );

                                    await _firestoreService
                                        .submitCollectorCompletion(
                                      reportId: report.id,
                                      collectorRemark:
                                          remarkController.text
                                              .trim(),
                                      completionImageUrl:
                                          completionImageUrl,
                                    );
                                  } else {
                                    await _firestoreService
                                        .updateReportStatus(
                                      reportId: report.id,
                                      status: selectedAction,
                                    );
                                  }

                                  if (!mounted) return;

                                  if (Navigator.of(sheetContext)
                                      .canPop()) {
                                    Navigator.of(sheetContext).pop();
                                  }

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isSubmittingCompletion
                                            ? 'Completion submitted for Admin review.'
                                            : 'Task updated successfully!',
                                      ),
                                      backgroundColor:
                                          isSubmittingCompletion
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;

                                  if (builderContext.mounted) {
                                    setStateSheet(() {
                                      isSaving = false;
                                    });
                                  }

                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isSubmittingCompletion
                                    ? 'Submit for Review'
                                    : 'Save Changes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    FocusScope.of(context).unfocus();

    Future.delayed(
      const Duration(milliseconds: 300),
      () {
        remarkController.dispose();
      },
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    bool underline = false,
  }) {
    final tile = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                    decoration: underline
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildReviewMessage({
    required String status,
    required String verificationStatus,
    required String rejectionReason,
  }) {
    if (status == 'Completion Submitted') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.amber.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: Colors.amber.shade900,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for Admin Review',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your completion photo and remark have been submitted. '
                    'This task is locked until Admin approves or rejects it.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'In Progress' &&
        verificationStatus == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.red.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cancel_outlined,
              color: Colors.red.shade700,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completion Rejected',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rejectionReason.isEmpty
                        ? 'Admin rejected the completion evidence. '
                            'Please correct the issue and submit a new proof photo.'
                        : 'Admin feedback: $rejectionReason',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A new completion photo is required for resubmission.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'Resolved') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: Colors.green.shade700,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Completion approved by Admin. This report is resolved.',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _completionProofTitle({
    required String status,
    required String verificationStatus,
  }) {
    if (status == 'Resolved') {
      return 'Approved Completion Proof';
    }

    if (status == 'Completion Submitted') {
      return 'Completion Proof Under Review';
    }

    if (status == 'In Progress' &&
        verificationStatus == 'rejected') {
      return 'Previous Completion Proof (Rejected)';
    }

    return 'Completion Proof';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .snapshots(),
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();

        final WasteReport report = liveData != null
            ? WasteReport.fromMap(
                liveData,
                widget.report.id,
              )
            : widget.report;

        final verificationStatus =
            liveData?['completionVerificationStatus']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final rejectionReason =
            liveData?['completionRejectionReason']
                    ?.toString()
                    .trim() ??
                '';

        final bool isWaitingForReview =
            report.status == 'Completion Submitted';

        final bool isResolved =
            report.status == 'Resolved';

        final bool wasCompletionRejected =
            report.status == 'In Progress' &&
            verificationStatus == 'rejected';

        final statusColor =
            _statusColor(report.status);

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            backgroundColor:
                const Color(0xFFF7F9FC),
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                ),
                onPressed: _goBackToTaskList,
              ),
              title: const Text(
                'Task Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black87,
            ),
            body: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (snapshot.hasError)
                    Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Colors.orange.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Text(
                        'Could not refresh the latest report data. '
                        'Showing the previously loaded task details.',
                        style: TextStyle(
                          color:
                              Colors.orange.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (report.imageUrl.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),
                        color:
                            Colors.grey.shade200,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),
                        child: Image.network(
                          report.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Icon(
                              Icons
                                  .broken_image_outlined,
                              size: 56,
                              color:
                                  Colors.grey.shade400,
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style:
                              const TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: statusColor
                              .withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        child: Text(
                          report.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isWaitingForReview ||
                      wasCompletionRejected ||
                      isResolved) ...[
                    _buildReviewMessage(
                      status: report.status,
                      verificationStatus:
                          verificationStatus,
                      rejectionReason:
                          rejectionReason,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoTile(
                    icon:
                        Icons.category_outlined,
                    label: 'Waste Type',
                    value: report.wasteType,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon:
                        Icons.location_on_outlined,
                    label: 'Location',
                    value: report.location,
                    valueColor:
                        Colors.blue.shade700,
                    underline: true,
                    onTap: () =>
                        _showNavigationOptions(
                      report,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon:
                        Icons.description_outlined,
                    label: 'Description',
                    value:
                        report.description,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons.person_outline,
                    label: 'Reported By',
                    value: report.userName,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon:
                        Icons.schedule_outlined,
                    label: 'Created At',
                    value: _formatDate(
                      report.createdAt,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon:
                        Icons.update_outlined,
                    label: 'Updated At',
                    value: _formatDate(
                      report.updatedAt,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon:
                        Icons.edit_note_outlined,
                    label: 'Admin Remark',
                    value:
                        report.adminRemark,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    icon: Icons
                        .assignment_turned_in_outlined,
                    label:
                        'Collector Remark',
                    value:
                        report.collectorRemark,
                  ),
                  if (report
                      .completionImageUrl
                      .isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      _completionProofTitle(
                        status: report.status,
                        verificationStatus:
                            verificationStatus,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),
                        color:
                            Colors.grey.shade200,
                        border:
                            wasCompletionRejected
                                ? Border.all(
                                    color:
                                        Colors.red.shade200,
                                    width: 2,
                                  )
                                : null,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          22,
                        ),
                        child: Image.network(
                          report
                              .completionImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Icon(
                              Icons
                                  .broken_image_outlined,
                              size: 56,
                              color:
                                  Colors.grey.shade400,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed: () =>
                              _showNavigationOptions(
                            report,
                          ),
                          icon: const Icon(
                            Icons
                                .near_me_outlined,
                          ),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          style:
                              OutlinedButton
                                  .styleFrom(
                            foregroundColor:
                                Colors.blueGrey,
                            side: BorderSide(
                              color: Colors
                                  .grey.shade300,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              isWaitingForReview ||
                                      isResolved
                                  ? null
                                  : () =>
                                      _showUpdateBottomSheet(
                                        report,
                                      ),
                          icon: Icon(
                            isWaitingForReview
                                ? Icons
                                    .hourglass_top_rounded
                                : isResolved
                                    ? Icons
                                        .verified_rounded
                                    : wasCompletionRejected
                                        ? Icons
                                            .refresh_rounded
                                        : Icons
                                            .edit_outlined,
                          ),
                          label: Text(
                            isWaitingForReview
                                ? 'Waiting for Review'
                                : isResolved
                                    ? 'Resolved'
                                    : wasCompletionRejected
                                        ? 'Resubmit Proof'
                                        : 'Update Status',
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                wasCompletionRejected
                                    ? Colors.red
                                    : statusColor,
                            foregroundColor:
                                Colors.white,
                            disabledBackgroundColor:
                                isResolved
                                    ? Colors
                                        .green.shade100
                                    : Colors
                                        .amber.shade100,
                            disabledForegroundColor:
                                isResolved
                                    ? Colors
                                        .green.shade800
                                    : Colors
                                        .amber.shade900,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
