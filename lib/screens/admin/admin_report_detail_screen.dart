import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final WasteReport report;

  const AdminReportDetailScreen({
    super.key,
    required this.report,
  });

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _adminRemarkController = TextEditingController();

  late String _selectedStatus;
  bool _isUpdating = false;

  String? _selectedCollectorId;
  String? _selectedCollectorName;

  final List<String> _statusOptions = [
    'Pending',
    'Assigned',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _adminRemarkController.text = widget.report.adminRemark;

    if (widget.report.collectorId.isNotEmpty) {
      _selectedCollectorId = widget.report.collectorId;
      _selectedCollectorName = widget.report.collectorName;
    }
  }

  @override
  void dispose() {
    _adminRemarkController.dispose();
    super.dispose();
  }

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

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
  }

  Future<void> _saveStatus() async {
    if (_selectedStatus == 'Assigned' && _selectedCollectorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a collector first')),
      );
      return;
    }

    if (_selectedStatus == 'Rejected' &&
        _adminRemarkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter admin remark for rejection')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      if (_selectedStatus == 'Rejected') {
        await _firestoreService.rejectReport(
          reportId: widget.report.id,
          adminRemark: _adminRemarkController.text.trim(),
        );
      } else if (_selectedStatus == 'Assigned') {
        await _firestoreService.assignCollector(
          reportId: widget.report.id,
          collectorId: _selectedCollectorId!,
          collectorName: _selectedCollectorName ?? 'Unnamed Collector',
          adminRemark: _adminRemarkController.text.trim(),
        );
      } else {
        await _firestoreService.updateReportStatus(
          reportId: widget.report.id,
          status: _selectedStatus,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _assignCollectorOnly() async {
    if (_selectedCollectorId == null || _selectedCollectorName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a collector')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _firestoreService.assignCollector(
        reportId: widget.report.id,
        collectorId: _selectedCollectorId!,
        collectorName: _selectedCollectorName!,
        adminRemark: _adminRemarkController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collector assigned successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign collector: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _removeCollector() async {
    setState(() => _isUpdating = true);

    try {
      await _firestoreService.removeCollector(
        reportId: widget.report.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collector removed successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove collector: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _infoSection(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
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

  Widget _buildImageBox(String imageUrl, {double height = 220}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported,
          size: 60,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: height,
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image,
              size: 60,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStatusColor = _statusColor(_selectedStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Report'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reported Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildImageBox(widget.report.imageUrl),
                const SizedBox(height: 20),

                _infoSection('Title', widget.report.title),
                _infoSection('Description', widget.report.description),
                _infoSection('Location', widget.report.location),
                _infoSection('Waste Type', widget.report.wasteType),
                _infoSection('Reported By', widget.report.userName),
                _infoSection('User ID', widget.report.userId),
                _infoSection(
                  'Submitted At',
                  _formatTimestamp(widget.report.createdAt),
                ),
                _infoSection(
                  'Last Updated',
                  _formatTimestamp(widget.report.updatedAt),
                ),
                _infoSection(
                  'Assigned Collector',
                  _selectedCollectorName ??
                      (widget.report.collectorName.isNotEmpty
                          ? widget.report.collectorName
                          : 'Not assigned'),
                ),
                _infoSection('Collector Remark', widget.report.collectorRemark),

                const Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: currentStatusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedStatus,
                    style: TextStyle(
                      color: currentStatusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _adminRemarkController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Admin Remark',
                    hintText: 'Enter verification or rejection remark',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _statusOptions.contains(_selectedStatus)
                      ? _selectedStatus
                      : 'Pending',
                  decoration: InputDecoration(
                    labelText: 'Update Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: _isUpdating
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          }
                        },
                ),

                const SizedBox(height: 20),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'collector')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load collectors: ${snapshot.error}',
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return const Text(
                        'No collector accounts found in Firestore.',
                        style: TextStyle(color: Colors.red),
                      );
                    }

                    final validCollectorIds = docs.map((doc) => doc.id).toList();

                    if (_selectedCollectorId != null &&
                        !validCollectorIds.contains(_selectedCollectorId)) {
                      _selectedCollectorId = null;
                      _selectedCollectorName = null;
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedCollectorId,
                      decoration: InputDecoration(
                        labelText: 'Assign Collector',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: docs.map((doc) {
                        final data = doc.data();
                        final name = data['name'] ?? 'Unnamed Collector';

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: _isUpdating
                          ? null
                          : (value) {
                              if (value != null) {
                                final selectedDoc =
                                    docs.firstWhere((doc) => doc.id == value);

                                setState(() {
                                  _selectedCollectorId = value;
                                  _selectedCollectorName =
                                      selectedDoc.data()['name'] ??
                                          'Unnamed Collector';

                                  if (_selectedStatus == 'Pending') {
                                    _selectedStatus = 'Assigned';
                                  }
                                });
                              }
                            },
                    );
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _saveStatus,
                    child: _isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _assignCollectorOnly,
                    child: _isUpdating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Assign Collector Only'),
                  ),
                ),

                const SizedBox(height: 12),

                if ((_selectedCollectorId ?? '').isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isUpdating ? null : _removeCollector,
                      child: const Text('Remove Collector'),
                    ),
                  ),

                if (widget.report.completionImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Completion Image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildImageBox(widget.report.completionImageUrl),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}