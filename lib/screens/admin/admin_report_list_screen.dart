import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'admin_report_detail_screen.dart';

class AdminReportListScreen extends StatefulWidget {
  final String initialFilter;
  final String initialAreaFilter;
  final bool initialHotspotWeeklyOnly;

  const AdminReportListScreen({
    super.key,
    this.initialFilter = 'All',
    this.initialAreaFilter = '',
    this.initialHotspotWeeklyOnly = false,
  });

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  final FirestoreService firestoreService = FirestoreService();

  late final Stream<List<WasteReport>> _reportsStream;
  final FocusNode _locationSearchFocusNode = FocusNode();

  late String _selectedFilter;
  late String _selectedAreaFilter;
  late bool _hotspotWeeklyOnly;
  String _selectedPriorityFilter = 'All';

  // Status + Priority live inside one compact filter panel.
  // The panel is hidden when Manage Reports first opens.
  bool _filtersExpanded = false;

  final TextEditingController _locationSearchController =
      TextEditingController();
  String _locationSearchQuery = '';

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Completion Submitted',
    'Resolved',
    'Rejected',
  ];

  final List<String> _priorityFilters = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _reportsStream = firestoreService.getAllReports();
    _selectedFilter = widget.initialFilter;
    _selectedAreaFilter = widget.initialAreaFilter;
    _hotspotWeeklyOnly = widget.initialHotspotWeeklyOnly;

    // When Manage Reports is opened from a hotspot, show the hotspot area
    // inside the search field as well. The Admin can edit it directly to
    // leave hotspot mode and search another area/location manually.
    _locationSearchQuery = widget.initialAreaFilter.trim();
    _locationSearchController.text = _locationSearchQuery;
  }

  @override
  void didUpdateWidget(covariant AdminReportListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter ||
        oldWidget.initialAreaFilter != widget.initialAreaFilter ||
        oldWidget.initialHotspotWeeklyOnly !=
            widget.initialHotspotWeeklyOnly) {
      setState(() {
        _selectedFilter = widget.initialFilter;
        _selectedAreaFilter = widget.initialAreaFilter;
        _hotspotWeeklyOnly = widget.initialHotspotWeeklyOnly;
        _selectedPriorityFilter = 'All';
        _filtersExpanded = false;
        _locationSearchQuery = widget.initialAreaFilter.trim();
        _locationSearchController.text = _locationSearchQuery;
      });
    }
  }

  @override
  void dispose() {
    _locationSearchController.dispose();
    _locationSearchFocusNode.dispose();
    super.dispose();
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

  bool _matchesLocationSearch(WasteReport report) {
    final query = _locationSearchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final area = report.area.trim().toLowerCase();
    final location = report.location.trim().toLowerCase();

    return area.contains(query) || location.contains(query);
  }

  void _handleLocationSearchChanged(String value) {
    final cleanValue = value.trim();

    setState(() {
      // A hotspot drill-down uses an exact area + last-7-days filter.
      // As soon as Admin edits that area text, switch back to normal
      // Manage Reports search so another location can be searched directly.
      if (_selectedAreaFilter.trim().isNotEmpty &&
          cleanValue.toLowerCase() !=
              _selectedAreaFilter.trim().toLowerCase()) {
        _selectedAreaFilter = '';
        _hotspotWeeklyOnly = false;
        _selectedPriorityFilter = 'All';
      }

      _locationSearchQuery = cleanValue;
    });
  }

  void _clearLocationSearch() {
    setState(() {
      _selectedAreaFilter = '';
      _hotspotWeeklyOnly = false;
      _selectedPriorityFilter = 'All';
      _locationSearchQuery = '';
      _locationSearchController.clear();
    });
  }

  bool _isWithinLast7Days(WasteReport report) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final createdAt = report.createdAt.toDate();
    return !createdAt.isBefore(cutoff);
  }

  bool _isActiveHotspotReport(WasteReport report) {
    return report.status != 'Resolved' && report.status != 'Rejected';
  }

  String _autoPriorityFromCount(int count) {
    if (count >= 3) return 'High';
    if (count == 2) return 'Medium';
    return 'Low';
  }

  int _countForSelectedArea(List<WasteReport> allReports) {
    if (_selectedAreaFilter.trim().isEmpty) {
      return 0;
    }

    return allReports.where((report) {
      final areaMatch =
          report.area.trim() == _selectedAreaFilter.trim();

      if (!areaMatch) {
        return false;
      }

      if (_hotspotWeeklyOnly) {
        return _isWithinLast7Days(report);
      }

      return _isActiveHotspotReport(report);
    }).length;
  }

  String _areaPriorityFromSelectedArea(List<WasteReport> allReports) {
    final count = _countForSelectedArea(allReports);
    return _autoPriorityFromCount(count);
  }

  String _displayPriorityForReport(
    WasteReport report,
    List<WasteReport> allReports,
  ) {
    if (_selectedAreaFilter.trim().isEmpty) {
      return report.priority;
    }

    return _areaPriorityFromSelectedArea(allReports);
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

    final areaCount = _hotspotWeeklyOnly
        ? areaReports.length
        : areaReports.where(_isActiveHotspotReport).length;
    final areaPriority = _autoPriorityFromCount(areaCount);

    if (filter == 'All') {
      return areaCount;
    }

    return areaPriority == filter ? areaCount : 0;
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd MMM, hh:mm a').format(dateTime);
  }

  Widget _buildLocationSearchBar() {
    final hasActiveFilters =
        _selectedFilter != 'All' || _selectedPriorityFilter != 'All';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
      child: TextField(
        controller: _locationSearchController,
        focusNode: _locationSearchFocusNode,
        onChanged: _handleLocationSearchChanged,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search area or report location...',
          prefixIcon: const Icon(
            Icons.location_searching_rounded,
            color: Colors.blue,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 50,
            minHeight: 48,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _filtersExpanded ? 'Hide filters' : 'Show filters',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _filtersExpanded = !_filtersExpanded;
                  });
                },
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _filtersExpanded || hasActiveFilters
                        ? Colors.blue.shade50
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.tune_rounded,
                          color: _filtersExpanded || hasActiveFilters
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                          size: 21,
                        ),
                      ),
                      if (hasActiveFilters)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_locationSearchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Clear location search',
                  onPressed: _clearLocationSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Colors.blue,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaFilterBanner({required List<WasteReport> areaReports}) {
    if (_selectedAreaFilter.isEmpty) {
      return const SizedBox.shrink();
    }

    final areaCount = _hotspotWeeklyOnly
        ? areaReports.length
        : areaReports.where(_isActiveHotspotReport).length;
    final areaPriority = _autoPriorityFromCount(areaCount);
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
              '${_hotspotWeeklyOnly ? 'Last 7 days' : 'Active reports'}: '
              '$areaCount • $areaPriority Area',
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
            onPressed: _clearLocationSearch,
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
        stream: _reportsStream,
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
            final searchMatch = _matchesLocationSearch(report);

            final areaMatch = _selectedAreaFilter.trim().isEmpty ||
                report.area.trim() == _selectedAreaFilter.trim();

            final dateMatch = !_hotspotWeeklyOnly ||
                _selectedAreaFilter.trim().isEmpty ||
                _isWithinLast7Days(report);

            return searchMatch && areaMatch && dateMatch;
          }).toList();

          final filteredReports =
              reports.where((report) {
                final statusMatch =
                    _selectedFilter == 'All' ||
                    report.status == _selectedFilter;

                final searchMatch = _matchesLocationSearch(report);

                final areaMatch =
                    _selectedAreaFilter.trim().isEmpty ||
                    report.area.trim() == _selectedAreaFilter.trim();

                final dateMatch = !_hotspotWeeklyOnly ||
                    _selectedAreaFilter.trim().isEmpty ||
                    _isWithinLast7Days(report);

                final priorityMatch = _matchSelectedPriority(report, reports);

                return statusMatch &&
                    searchMatch &&
                    areaMatch &&
                    dateMatch &&
                    priorityMatch;
              }).toList()..sort((a, b) {
                return b.createdAt.compareTo(a.createdAt);
              });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationSearchBar(),
              _buildAreaFilterBanner(areaReports: areaFilteredReports),
              _buildCombinedFilterPanel(areaFilteredReports),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  _hotspotWeeklyOnly && _selectedAreaFilter.isNotEmpty
                      ? 'Found ${filteredReports.length} reports in the last 7 days'
                      : _locationSearchQuery.isNotEmpty
                          ? 'Found ${filteredReports.length} reports matching "$_locationSearchQuery"'
                          : 'Found ${filteredReports.length} results',
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
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          115 + MediaQuery.of(context).padding.bottom,
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

  Widget _buildCombinedFilterPanel(List<WasteReport> reports) {
    if (!_filtersExpanded) {
      return const SizedBox.shrink();
    }

    final priorityTitle = _selectedAreaFilter.isEmpty
        ? 'Priority'
        : _hotspotWeeklyOnly
            ? 'Weekly Hotspot Priority'
            : 'Area Priority';

    final hasActiveFilters =
        _selectedFilter != 'All' || _selectedPriorityFilter != 'All';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 3, 20, 7),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'All';
                        _selectedPriorityFilter = 'All';
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedFilter != 'All')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(_selectedFilter).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedFilter,
                      style: TextStyle(
                        color: _statusColor(_selectedFilter),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildStatusFilterBar(reports),
          Divider(
            height: 18,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  priorityTitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedPriorityFilter != 'All')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(_selectedPriorityFilter)
                          .withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedPriorityFilter,
                      style: TextStyle(
                        color: _priorityColor(_selectedPriorityFilter),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildPriorityFilterBar(reports),
        ],
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
                  ? _hotspotWeeklyOnly
                      ? 'Reports ($count)'
                      : 'Active ($count)'
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
