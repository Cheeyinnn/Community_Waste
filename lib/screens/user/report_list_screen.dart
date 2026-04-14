import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'report_detail_screen.dart';

class ReportListScreen extends StatefulWidget {
  final String? initialStatusFilter;
  final Function(String filter)? onFilterChanged;
  final VoidCallback? onBack;

  const ReportListScreen({
    super.key,
    this.initialStatusFilter,
    this.onFilterChanged,
    this.onBack,
  });

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _filterScrollController = ScrollController();

  String _selectedStatusFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter ?? 'All';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedFilter();
    });
  }

  @override
  void didUpdateWidget(covariant ReportListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialStatusFilter != widget.initialStatusFilter &&
        widget.initialStatusFilter != null &&
        widget.initialStatusFilter != _selectedStatusFilter) {
      setState(() {
        _selectedStatusFilter = widget.initialStatusFilter!;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedFilter();
      });
    }
  }

  @override
  void dispose() {
    _filterScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedFilter() {
    if (!_filterScrollController.hasClients) return;

    final index = _filters.indexOf(_selectedStatusFilter);
    if (index == -1) return;

    const double itemWidth = 115;
    double targetOffset = index * itemWidth;

    final maxScroll = _filterScrollController.position.maxScrollExtent;
    if (targetOffset > maxScroll) {
      targetOffset = maxScroll;
    }

    if (targetOffset < 0) {
      targetOffset = 0;
    }

    _filterScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
    try {
      final date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            widget.onBack?.call();
          },
        ),
        title: const Text(
          'My Reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: _firestoreService.getUserReports(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allReports = snapshot.data ?? [];

          final reports = _selectedStatusFilter == 'All'
              ? allReports
              : allReports
                  .where((r) => r.status == _selectedStatusFilter)
                  .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 55,
                child: ListView.builder(
                  key: const PageStorageKey<String>('user_report_filter_bar'),
                  controller: _filterScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedStatusFilter == filter;
                    final baseColor =
                        filter == 'All' ? Colors.green : _statusColor(filter);

                    final count = filter == 'All'
                        ? allReports.length
                        : allReports.where((r) => r.status == filter).length;

                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 10, top: 4, bottom: 4),
                      child: ChoiceChip(
                        label: Text('$filter ($count)'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedStatusFilter = filter;
                          });

                          widget.onFilterChanged?.call(filter);

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToSelectedFilter();
                          });
                        },
                        selectedColor: baseColor,
                        backgroundColor: Colors.white,
                        showCheckmark: false,
                        elevation: isSelected ? 4 : 0,
                        shadowColor: baseColor.withOpacity(0.3),
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
                                : baseColor.withOpacity(0.4),
                            width: 1.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Found ${reports.length} reports',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: reports.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        key: const PageStorageKey<String>(
                          'user_reports_list_key',
                        ),
                        padding: const EdgeInsets.all(20),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _buildReportCard(context, reports[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 60,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No reports found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedStatusFilter == 'All'
                ? "When you report waste,\nit will show up here."
                : "No $_selectedStatusFilter reports yet.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, WasteReport report) {
    final statusColor = _statusColor(report.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(report: report),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 85,
                height: 85,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: report.imageUrl.isNotEmpty
                      ? Image.network(
                          report.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            );
                          },
                        )
                      : const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          _formatDate(report.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            report.wasteType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}