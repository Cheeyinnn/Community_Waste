import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'collector_report_detail_screen.dart';

class CollectorTaskScreen extends StatefulWidget {
  final String initialFilter;

  const CollectorTaskScreen({super.key, this.initialFilter = 'All'});

  @override
  State<CollectorTaskScreen> createState() => _CollectorTaskScreenState();
}

class _CollectorTaskScreenState extends State<CollectorTaskScreen> {
  late String _selectedFilter;

  final List<String> _filters = [
    'All',
    'Assigned',
    'In Progress',
    'Completion Submitted',
    'Resolved',
  ];

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant CollectorTaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _selectedFilter = widget.initialFilter;
      });
    }
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
    final date = timestamp.toDate();
    return DateFormat('dd MMM, hh:mm a').format(date);
  }

  Future<void> _openGoogleMaps(BuildContext context, WasteReport report) async {
    final String query = Uri.encodeComponent(report.location);

    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch Google Maps")),
      );
    }
  }

  Future<void> _showNavigationOptions(
    BuildContext context,
    WasteReport report,
    FirestoreService firestoreService,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to proceed with this task.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _openGoogleMaps(context, report);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      'View Location Only',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                          await firestoreService.startCollectorTask(
                            reportId: report.id,
                            collectorRemark: report.collectorRemark.isNotEmpty
                                ? report.collectorRemark
                                : 'Started via navigation',
                          );
                        }

                        await _openGoogleMaps(context, report);

                        if (!context.mounted) return;

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
                        if (!context.mounted) return;

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
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
    BuildContext screenContext,
    WasteReport report,
    FirestoreService firestoreService,
  ) async {
    if (report.status == 'Completion Submitted' ||
        report.status == 'Resolved') {
      return;
    }

    String selectedAction =
        report.status == 'Assigned' ? 'Assigned' : 'In Progress';

    final TextEditingController remarkController = TextEditingController(
      text: report.collectorRemark,
    );

    File? completionImageFile;
    bool isSaving = false;

    final List<String> actions = report.status == 'Assigned'
        ? ['Assigned', 'In Progress']
        : ['In Progress', 'Submit Completion'];

    Future<void> pickCompletionImage(StateSetter setStateSheet) async {
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
      context: screenContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setStateSheet) {
            final bool isSubmittingCompletion =
                selectedAction == 'Submit Completion';

            final Color selectedColor = _statusColor(selectedAction);

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                      'Update your progress or submit completion evidence for '
                      'Admin verification.',
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
                        final Color color = _statusColor(action);

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
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color:
                                isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: Colors.amber.shade900,
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
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(16),
                            border: completionImageFile == null
                                ? Border.all(
                                    color: Colors.orange.shade300,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: completionImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
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
                                      color: Colors.orange.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to upload new proof photo',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (isSubmittingCompletion &&
                                    completionImageFile == null) {
                                  if (!screenContext.mounted) return;

                                  ScaffoldMessenger.of(
                                    screenContext,
                                  ).showSnackBar(
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
                                    await firestoreService
                                        .startCollectorTask(
                                      reportId: report.id,
                                      collectorRemark:
                                          remarkController.text.trim(),
                                    );
                                  } else if (selectedAction ==
                                      'Submit Completion') {
                                    final completionImageUrl =
                                        await _storageService
                                            .uploadCompletionImage(
                                      completionImageFile!,
                                    );

                                    await firestoreService
                                        .submitCollectorCompletion(
                                      reportId: report.id,
                                      collectorRemark:
                                          remarkController.text.trim(),
                                      completionImageUrl:
                                          completionImageUrl,
                                    );
                                  } else {
                                    await firestoreService
                                        .updateReportStatus(
                                      reportId: report.id,
                                      status: selectedAction,
                                    );
                                  }

                                  if (!screenContext.mounted) return;

                                  Navigator.of(sheetContext).pop();

                                  ScaffoldMessenger.of(
                                    screenContext,
                                  ).showSnackBar(
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
                                  if (!screenContext.mounted) return;

                                  if (builderContext.mounted) {
                                    setStateSheet(() {
                                      isSaving = false;
                                    });
                                  }

                                  ScaffoldMessenger.of(
                                    screenContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                isSubmittingCompletion
                                    ? 'Submit for Admin Review'
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

    FocusScope.of(screenContext).unfocus();

    Future.delayed(const Duration(milliseconds: 300), () {
      remarkController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report Tasks',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Waste reports assigned to you by Admin',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getCollectorReports(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];
          final filteredReports = _selectedFilter == 'All'
              ? reports
              : reports.where((r) => r.status == _selectedFilter).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 55,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  key: const PageStorageKey<String>(
                    'collector_status_filter_key',
                  ),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;

                    final baseColor = filter == 'All'
                        ? const Color(0xFF222222)
                        : _statusColor(filter);

                    final count = filter == 'All'
                        ? reports.length
                        : reports.where((r) => r.status == filter).length;

                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 10,
                        top: 4,
                        bottom: 4,
                      ),
                      child: ChoiceChip(
                        label: Text('$filter ($count)'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        selectedColor: baseColor,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        elevation: isSelected ? 4 : 0,
                        shadowColor: baseColor.withOpacity(0.4),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : baseColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : baseColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Found ${filteredReports.length} report task${filteredReports.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'All'
                                  ? 'No report tasks right now'
                                  : 'No $_selectedFilter report tasks right now',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        key: const PageStorageKey<String>(
                          'collector_task_list_key',
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        physics: const ClampingScrollPhysics(),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          return _buildModernTaskCard(
                            context,
                            filteredReports[index],
                            firestoreService,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernTaskCard(
    BuildContext context,
    WasteReport report,
    FirestoreService firestoreService,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .snapshots(),
      builder: (context, reviewSnapshot) {
        final reviewData =
            reviewSnapshot.data?.data() ?? <String, dynamic>{};

        final verificationStatus =
            reviewData['completionVerificationStatus']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final rejectionReason =
            reviewData['completionRejectionReason']
                    ?.toString()
                    .trim() ??
                '';

        final bool isWaitingForReview =
            report.status == 'Completion Submitted';

        final bool isResolved = report.status == 'Resolved';

        final bool wasCompletionRejected =
            report.status == 'In Progress' &&
            verificationStatus == 'rejected';

        final statusColor = _statusColor(report.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CollectorReportDetailScreen(report: report),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: report.imageUrl.isNotEmpty
                                ? Image.network(
                                    report.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) {
                                      return Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey.shade400,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        report.status,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(report.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _showNavigationOptions(
                                  context,
                                  report,
                                  firestoreService,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.near_me_rounded,
                                        size: 16,
                                        color: Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          report.location,
                                          style: TextStyle(
                                            color:
                                                Colors.blue.shade700,
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w600,
                                            decoration:
                                                TextDecoration
                                                    .underline,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isWaitingForReview) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
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
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Waiting for Admin Review',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Your completion evidence has been '
                                    'submitted. This task is locked until '
                                    'Admin approves or rejects it.',
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (wasCompletionRejected) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.shade100,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Completion Rejected',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    rejectionReason.isEmpty
                                        ? 'Admin rejected the completion '
                                            'evidence. Please submit a new '
                                            'proof photo.'
                                        : 'Admin feedback: $rejectionReason',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please correct the issue and submit '
                                    'new completion evidence.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isResolved) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.shade100,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Completion approved by Admin. '
                                'This report is resolved.',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 11.8,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Divider(
                      color: Colors.grey.shade100,
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CollectorReportDetailScreen(
                                    report: report,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                isWaitingForReview || isResolved
                                    ? null
                                    : () => _showUpdateBottomSheet(
                                          context,
                                          report,
                                          firestoreService,
                                        ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  isResolved
                                      ? Colors.green.shade100
                                      : Colors.amber.shade100,
                              disabledForegroundColor:
                                  isResolved
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              isWaitingForReview
                                  ? 'Waiting for Review'
                                  : isResolved
                                      ? 'Resolved'
                                      : wasCompletionRejected
                                          ? 'Resubmit Proof'
                                          : 'Update Status',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
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
          ),
        );
      },
    );
  }

}
