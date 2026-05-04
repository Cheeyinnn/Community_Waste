import 'dart:io';
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

  Future<void> _openGoogleMaps() async {
    final String query = Uri.encodeComponent(widget.report.location);

    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
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
          content: Text("Could not launch Google Maps"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showNavigationOptions() async {
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
                      await _openGoogleMaps();
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
                        if (widget.report.status == 'Assigned') {
                          await _firestoreService.startCollectorTask(
                            reportId: widget.report.id,
                            collectorRemark:
                                widget.report.collectorRemark.isNotEmpty
                                    ? widget.report.collectorRemark
                                    : 'Started via navigation',
                          );
                        }

                        await _openGoogleMaps();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.report.status == 'Assigned'
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
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Task & Navigate',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _showUpdateBottomSheet() async {
    String selectedStatus = widget.report.status;
    final TextEditingController remarkController =
        TextEditingController(text: widget.report.collectorRemark);

    File? completionImageFile;
    bool isSaving = false;

    final List<String> statuses = widget.report.status == 'Assigned'
        ? ['Assigned', 'In Progress', 'Resolved']
        : widget.report.status == 'In Progress'
            ? ['In Progress', 'Resolved']
            : ['Resolved'];

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
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setStateSheet) {
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
                      'Update Task Status',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: statuses.map((status) {
                        final bool isSelected = selectedStatus == status;
                        final Color color = _statusColor(status);

                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setStateSheet(() {
                                selectedStatus = status;
                              });
                            }
                          },
                          selectedColor: color,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide.none,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Collector Remark',
                        hintText: 'Enter task progress note...',
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
                    const SizedBox(height: 20),
                    if (selectedStatus == 'Resolved') ...[
                      const Text(
                        'Proof of Completion',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => pickCompletionImage(setStateSheet),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: completionImageFile == null &&
                                    widget.report.completionImageUrl.isEmpty
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
                              : widget.report.completionImageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        widget.report.completionImageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 40,
                                          color: Colors.orange.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to upload photo',
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
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (selectedStatus == 'Resolved' &&
                                    completionImageFile == null &&
                                    widget.report.completionImageUrl.isEmpty) {
                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please upload a completion image',
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
                                  if (selectedStatus == 'In Progress') {
                                    await _firestoreService.startCollectorTask(
                                      reportId: widget.report.id,
                                      collectorRemark:
                                          remarkController.text.trim(),
                                    );
                                  } else if (selectedStatus == 'Resolved') {
                                    String completionImageUrl =
                                        widget.report.completionImageUrl;

                                    if (completionImageFile != null) {
                                      completionImageUrl =
                                          await _storageService
                                              .uploadCompletionImage(
                                        completionImageFile!,
                                      );
                                    }

                                    await _firestoreService.completeCollectorTask(
                                      reportId: widget.report.id,
                                      collectorRemark:
                                          remarkController.text.trim(),
                                      completionImageUrl: completionImageUrl,
                                    );
                                  } else {
                                    await _firestoreService.updateReportStatus(
                                      reportId: widget.report.id,
                                      status: selectedStatus,
                                    );
                                  }

                                  if (!mounted) return;

                                  final messenger =
                                      ScaffoldMessenger.of(context);

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Task updated successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  if (Navigator.of(sheetContext).canPop()) {
                                    Navigator.of(sheetContext).pop();
                                  }

                                  Future.microtask(() {
                                    if (mounted &&
                                        Navigator.of(context).canPop()) {
                                      // true means previous task page can refresh if needed.
                                      Navigator.of(context).pop(true);
                                    }
                                  });
                                } catch (e) {
                                  if (!mounted) return;

                                  if (builderContext.mounted) {
                                    setStateSheet(() {
                                      isSaving = false;
                                    });
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
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
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
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

    Future.delayed(const Duration(milliseconds: 300), () {
      remarkController.dispose();
    });
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
            child: Icon(icon, color: Colors.orange),
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
                    decoration:
                        underline ? TextDecoration.underline : TextDecoration.none,
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

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final statusColor = _statusColor(report.status);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _goBackToTaskList,
          ),
          title: const Text(
            'Task Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.imageUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      report.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildInfoTile(
                icon: Icons.category_outlined,
                label: 'Waste Type',
                value: report.wasteType,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: report.location,
                valueColor: Colors.blue.shade700,
                underline: true,
                onTap: _showNavigationOptions,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.description_outlined,
                label: 'Description',
                value: report.description,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.person_outline,
                label: 'Reported By',
                value: report.userName,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.schedule_outlined,
                label: 'Created At',
                value: _formatDate(report.createdAt),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.update_outlined,
                label: 'Updated At',
                value: _formatDate(report.updatedAt),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.edit_note_outlined,
                label: 'Admin Remark',
                value: report.adminRemark,
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.assignment_turned_in_outlined,
                label: 'Collector Remark',
                value: report.collectorRemark,
              ),
              if (report.completionImageUrl.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Completion Proof',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      report.completionImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image_outlined,
                          size: 56,
                          color: Colors.grey.shade400,
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
                    child: OutlinedButton.icon(
                      onPressed: _showNavigationOptions,
                      icon: const Icon(Icons.near_me_outlined),
                      label: const Text(
                        'Navigate',
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: report.status == 'Resolved'
                          ? null
                          : _showUpdateBottomSheet,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(
                        'Update Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
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
            ],
          ),
        ),
      ),
    );
  }
}