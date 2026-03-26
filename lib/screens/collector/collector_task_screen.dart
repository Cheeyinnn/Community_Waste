import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../user/report_detail_screen.dart';

class CollectorTaskScreen extends StatefulWidget {
  const CollectorTaskScreen({super.key});

  @override
  State<CollectorTaskScreen> createState() => _CollectorTaskScreenState();
}

class _CollectorTaskScreenState extends State<CollectorTaskScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Assigned',
    'In Progress',
    'Resolved',
  ];

  final StorageService _storageService = StorageService();

  Color _statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'No date';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Future<void> _showUpdateStatusDialog(
    BuildContext context,
    WasteReport report,
    FirestoreService firestoreService,
  ) async {
    String selectedStatus = report.status;
    final TextEditingController remarkController = TextEditingController(
      text: report.collectorRemark,
    );
    File? completionImageFile;

    final statuses = report.status == 'Assigned'
        ? ['Assigned', 'In Progress', 'Resolved']
        : report.status == 'In Progress'
            ? ['In Progress', 'Resolved']
            : ['Resolved'];

    Future<void> pickCompletionImage(StateSetter setStateDialog) async {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (picked != null) {
        setStateDialog(() {
          completionImageFile = File(picked.path);
        });
      }
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Update Task Status'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: statuses.contains(selectedStatus)
                          ? selectedStatus
                          : statuses.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: statuses.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: remarkController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Collector Remark',
                        hintText: 'Enter task progress or completion remark',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (selectedStatus == 'Resolved') ...[
                      const SizedBox(height: 16),
                      completionImageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                completionImageFile!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text('No completion image selected'),
                              ),
                            ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => pickCompletionImage(setStateDialog),
                          icon: const Icon(Icons.image),
                          label: const Text('Pick Completion Image'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                remarkController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStatus == 'Resolved' &&
                    completionImageFile == null &&
                    report.completionImageUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please upload a completion image'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  if (selectedStatus == 'In Progress') {
                    await firestoreService.startCollectorTask(
                      reportId: report.id,
                      collectorRemark: remarkController.text.trim(),
                    );
                  } else if (selectedStatus == 'Resolved') {
                    String completionImageUrl = report.completionImageUrl;

                    if (completionImageFile != null) {
                      completionImageUrl = await _storageService
                          .uploadReportImage(completionImageFile!);
                    }

                    await firestoreService.completeCollectorTask(
                      reportId: report.id,
                      collectorRemark: remarkController.text.trim(),
                      completionImageUrl: completionImageUrl,
                    );
                  } else {
                    await firestoreService.updateReportStatus(
                      reportId: report.id,
                      status: selectedStatus,
                    );
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task updated successfully'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update task: $e'),
                    ),
                  );
                } finally {
                  remarkController.dispose();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = label;
          });
        },
        selectedColor: Colors.green.shade200,
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.green.shade900 : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    WasteReport report,
    FirestoreService firestoreService,
  ) {
    final statusColor = _statusColor(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: report.imageUrl.isNotEmpty
                      ? Image.network(
                          report.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(report.wasteType),
                      const SizedBox(height: 2),
                      Text(report.location),
                      const SizedBox(height: 4),
                      Text(
                        'Submitted: ${_formatDate(report.createdAt)}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      if (report.collectorName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Collector: ${report.collectorName}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (report.collectorRemark.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Remark: ${report.collectorRemark}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          report.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(report: report),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: report.status == 'Resolved'
                        ? null
                        : () {
                            _showUpdateStatusDialog(
                              context,
                              report,
                              firestoreService,
                            );
                          },
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Status'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Collector not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getCollectorReports(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          final filteredReports = _selectedFilter == 'All'
              ? reports
              : reports.where((r) => r.status == _selectedFilter).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map(_buildFilterChip).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Showing ${filteredReports.length} task(s)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 50,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No tasks found for "$_selectedFilter"',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return _buildTaskCard(
                            context,
                            report,
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
}