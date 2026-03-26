import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'admin_report_detail_screen.dart';

class AdminReportListScreen extends StatefulWidget {
  const AdminReportListScreen({super.key});

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  final FirestoreService firestoreService = FirestoreService();

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Reports'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
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
                  'Showing ${filteredReports.length} report(s)',
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
                              'No reports found for "$_selectedFilter"',
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
                          final date = DateFormat('dd MMM yyyy, hh:mm a')
                              .format(report.createdAt.toDate());

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminReportDetailScreen(report: report),
                                  ),
                                );

                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
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
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 80,
                                                  height: 80,
                                                  color: Colors.grey.shade300,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey.shade300,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            report.wasteType,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            report.location,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Reported by: ${report.userName.isNotEmpty ? report.userName : report.userId}',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            date,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (report.collectorName.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Collector: ${report.collectorName}',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _statusColor(
                                                    report.status,
                                                  ).withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  report.status,
                                                  style: TextStyle(
                                                    color: _statusColor(
                                                      report.status,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (report.adminRemark.isNotEmpty)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      20,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Has Remark',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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