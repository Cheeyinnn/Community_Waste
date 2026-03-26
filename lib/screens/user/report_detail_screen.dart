import 'package:flutter/material.dart';
import '../../models/waste_report.dart';

class ReportDetailScreen extends StatelessWidget {
  final WasteReport report;
  final bool isAdmin;
  final Function(String)? onStatusChanged;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.isAdmin = false,
    this.onStatusChanged,
  });

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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showStatusDialog(BuildContext context) async {
    String selectedStatus = report.status;
    final statuses = ['Pending', 'Assigned', 'In Progress', 'Resolved', 'Rejected'];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Status'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: statuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedStatus = value;
                    });
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onStatusChanged != null) {
                  onStatusChanged!(selectedStatus);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required String imageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 60),
                      ),
                    );
                  },
                )
              : Container(
                  height: 220,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 60),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(report.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => _showStatusDialog(context),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(
              title: 'Reported Image',
              imageUrl: report.imageUrl,
            ),
            const SizedBox(height: 20),
            Text(
              report.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildInfoTile('Reported By', report.userName),
            _buildInfoTile('Waste Type', report.wasteType),
            _buildInfoTile('Location', report.location),
            _buildInfoTile('Description', report.description),
            _buildInfoTile('Assigned Collector', report.collectorName),
            _buildInfoTile('Admin Remark', report.adminRemark),
            _buildInfoTile('Collector Remark', report.collectorRemark),
            _buildInfoTile('Created At', _formatTimestamp(report.createdAt)),
            _buildInfoTile('Updated At', _formatTimestamp(report.updatedAt)),

            if (report.completionImageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildImageSection(
                title: 'Completion Image',
                imageUrl: report.completionImageUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}