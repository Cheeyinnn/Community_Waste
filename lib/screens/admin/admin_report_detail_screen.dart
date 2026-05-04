import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';

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
  final TextEditingController _adminRemarkController = TextEditingController();

  late String _selectedStatus;
  late String _selectedPriority;

  bool _isUpdating = false;
  String? _selectedCollectorId;
  String? _selectedCollectorName;

  final List<String> _statusOptions = [
    'Pending',
    'Assigned',
    'Rejected',
  ];

  final List<String> _priorityOptions = [
    'High',
    'Medium',
    'Low',
  ];

  @override
  void initState() {
    super.initState();

    _selectedStatus = widget.report.status;
    _selectedPriority = widget.initialPriorityOverride ?? widget.report.priority;
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

  Future<void> _handleUpdate() async {
    if (_selectedStatus == 'Assigned' && _selectedCollectorId == null) {
      _showError('Please select a collector first');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _openMap() async {
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
          ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.title, "Title", widget.report.title),
          _infoRow(Icons.eco_outlined, "Type", widget.report.wasteType),
          _infoRow(
            Icons.description_outlined,
            "Description",
            widget.report.description.isEmpty
                ? '-'
                : widget.report.description,
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
            Icons.person_outline,
            "Reporter",
            widget.report.userName.isNotEmpty
                ? widget.report.userName
                : "Unknown User",
          ),
          _infoRow(
            Icons.calendar_today_outlined,
            "Date",
            DateFormat('dd MMM yyyy, hh:mm a').format(
              widget.report.createdAt.toDate(),
            ),
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
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
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
              return DropdownMenuItem(
                value: p,
                child: Text(p),
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;

              setState(() {
                _selectedPriority = val;
              });
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'collector')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              final bool isValidCollector = docs.any(
                (doc) => doc.id == _selectedCollectorId,
              );

              if (!isValidCollector) {
                _selectedCollectorId = null;
              }

              return DropdownButtonFormField<String>(
                value: _selectedCollectorId,
                decoration: InputDecoration(
                  labelText: "Assign Collector",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Colors.blue,
                  ),
                ),
                hint: const Text('Select a collector'),
                items: docs.map((doc) {
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(doc.data()['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;

                  final matchedDoc = docs.firstWhere((d) => d.id == val);
                  final name = matchedDoc.data()['name'] ?? 'Unknown';

                  setState(() {
                    _selectedCollectorId = val;
                    _selectedCollectorName = name;

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
            decoration: InputDecoration(
              labelText: "Admin Remark",
              hintText: "Add notes or rejection reason...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blue,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
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