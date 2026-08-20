import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'admin_report_detail_screen.dart';

class AdminReportListScreen extends StatefulWidget {
  final String initialFilter;
  final String initialAreaFilter;

  const AdminReportListScreen({
    super.key,
    this.initialFilter = 'All',
    this.initialAreaFilter = '',
  });

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  final FirestoreService firestoreService = FirestoreService();

  late String _selectedFilter;
  late String _selectedAreaFilter;
  String _selectedPriorityFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  final List<String> _priorityFilters = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _selectedAreaFilter = widget.initialAreaFilter;
  }

  @override
  void didUpdateWidget(covariant AdminReportListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter ||
        oldWidget.initialAreaFilter != widget.initialAreaFilter) {
      setState(() {
        _selectedFilter = widget.initialFilter;
        _selectedAreaFilter = widget.initialAreaFilter;
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
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  bool _isActiveHotspotReport(WasteReport report) {
    return report.status != 'Resolved' && report.status != 'Rejected';
  }

  String _autoPriorityFromCount(int count) {
    if (count >= 3) return 'High';
    if (count == 2) return 'Medium';
    return 'Low';
  }

  int _activeCountForSelectedArea(List<WasteReport> allReports) {
    if (_selectedAreaFilter.trim().isEmpty) {
      return 0;
    }

    return allReports.where((report) {
      return report.area.trim() == _selectedAreaFilter.trim() &&
          _isActiveHotspotReport(report);
    }).length;
  }

  String _areaPriorityFromActiveReports(List<WasteReport> allReports) {
    final activeCount = _activeCountForSelectedArea(allReports);
    return _autoPriorityFromCount(activeCount);
  }

  String _displayPriorityForReport(
    WasteReport report,
    List<WasteReport> allReports,
  ) {
    if (_selectedAreaFilter.trim().isEmpty) {
      return report.priority;
    }

    return _areaPriorityFromActiveReports(allReports);
  }

  bool _matchSelectedPriority(
    WasteReport report,
    List<WasteReport> allReports,
  ) {
    if (_selectedPriorityFilter == 'All') {
      return true;
    }

    final displayPriority = _displayPriorityForReport(report, allReports);
    return displayPriority == _selectedPriorityFilter;
  }

  int _countPriorityReports(List<WasteReport> areaReports, String filter) {
    if (_selectedAreaFilter.trim().isEmpty) {
      if (filter == 'All') {
        return areaReports.length;
      }

      return areaReports.where((report) {
        return report.priority == filter;
      }).length;
    }

    final activeCount = areaReports.where(_isActiveHotspotReport).length;
    final areaPriority = _autoPriorityFromCount(activeCount);

    if (filter == 'All') {
      return activeCount;
    }

    return areaPriority == filter ? activeCount : 0;
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd MMM, hh:mm a').format(dateTime);
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildAreaFilterBanner({required List<WasteReport> areaReports}) {
    if (_selectedAreaFilter.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeCount = areaReports.where(_isActiveHotspotReport).length;
    final areaPriority = _autoPriorityFromCount(activeCount);
    final priorityColor = _priorityColor(areaPriority);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing reports from: $_selectedAreaFilter\n'
              'Active reports: $activeCount • $areaPriority Area',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: priorityColor,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedAreaFilter = '';
                _selectedPriorityFilter = 'All';
              });
            },
            child: const Text(
              'Clear',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Manage Reports',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          final areaFilteredReports = reports.where((report) {
            return _selectedAreaFilter.trim().isEmpty ||
                report.area.trim() == _selectedAreaFilter.trim();
          }).toList();

          final filteredReports =
              reports.where((report) {
                final statusMatch =
                    _selectedFilter == 'All' ||
                    report.status == _selectedFilter;

                final areaMatch =
                    _selectedAreaFilter.trim().isEmpty ||
                    report.area.trim() == _selectedAreaFilter.trim();

                final priorityMatch = _matchSelectedPriority(report, reports);

                return statusMatch && areaMatch && priorityMatch;
              }).toList()..sort((a, b) {
                return b.createdAt.compareTo(a.createdAt);
              });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('Status'),
              _buildStatusFilterBar(areaFilteredReports),
              _buildSectionLabel(
                _selectedAreaFilter.isEmpty ? 'Priority' : 'Area Priority',
              ),
              _buildPriorityFilterBar(areaFilteredReports),
              _buildAreaFilterBanner(areaReports: areaFilteredReports),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Found ${filteredReports.length} results',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: filteredReports.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        physics: const ClampingScrollPhysics(),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          return _buildModernReportCard(
                            context,
                            filteredReports[index],
                            reports,
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

  Widget _buildStatusFilterBar(List<WasteReport> reports) {
    return SizedBox(
      height: 55,
      child: ListView.builder(
        key: const PageStorageKey<String>('status_filter_key'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          final baseColor = filter == 'All'
              ? Colors.blueGrey
              : _statusColor(filter);

          final count = filter == 'All'
              ? reports.length
              : reports.where((r) => r.status == filter).length;

          return Padding(
            padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
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
    );
  }

  Widget _buildPriorityFilterBar(List<WasteReport> reports) {
    return SizedBox(
      height: 55,
      child: ListView.builder(
        key: const PageStorageKey<String>('priority_filter_key'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _priorityFilters.length,
        itemBuilder: (context, index) {
          final filter = _priorityFilters[index];
          final isSelected = _selectedPriorityFilter == filter;
          final baseColor = filter == 'All'
              ? Colors.blueGrey
              : _priorityColor(filter);

          final count = _countPriorityReports(reports, filter);

          final label = _selectedAreaFilter.isEmpty
              ? '$filter ($count)'
              : filter == 'All'
              ? 'Active ($count)'
              : '$filter Area ($count)';

          return Padding(
            padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedPriorityFilter = filter;
                });
              },
              selectedColor: baseColor,
              backgroundColor: Colors.white,
              showCheckmark: false,
              elevation: isSelected ? 4 : 0,
              shadowColor: baseColor.withOpacity(0.35),
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
    );
  }

  Widget _buildModernReportCard(
    BuildContext context,
    WasteReport report,
    List<WasteReport> allReports,
  ) {
    final statusColor = _statusColor(report.status);
    final displayPriority = _displayPriorityForReport(report, allReports);
    final priorityColor = _priorityColor(displayPriority);
    final date = _formatDate(report.createdAt.toDate());

    final priorityText = _selectedAreaFilter.trim().isEmpty
        ? displayPriority
        : '$displayPriority Area';

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminReportDetailScreen(
                    report: report,
                    initialPriorityOverride: _selectedAreaFilter.trim().isEmpty
                        ? null
                        : displayPriority,
                  ),
                ),
              );

              if (changed == true && mounted) {
                setState(() {});
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Hero(
                    tag: report.id,
                    child: Container(
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
                                errorBuilder: (context, error, stackTrace) {
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                priorityText,
                                style: TextStyle(
                                  color: priorityColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.location,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Area: ${report.area.isEmpty ? '-' : report.area}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By: ${report.userName}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message =
        _selectedFilter == 'All' &&
            _selectedPriorityFilter == 'All' &&
            _selectedAreaFilter.isEmpty
        ? 'No reports found'
        : 'No matching reports found';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
