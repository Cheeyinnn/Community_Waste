import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/report_chat_service.dart';
import '../shared/report_chat_screen.dart';
import 'collector_report_detail_screen.dart';

class CollectorTaskScreen extends StatefulWidget {
  final String initialFilter;

  const CollectorTaskScreen({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<CollectorTaskScreen> createState() => _CollectorTaskScreenState();
}

class _CollectorTaskScreenState extends State<CollectorTaskScreen> {
  static const Color _collectorPrimary = Color(0xFFFFB547);

  final FirestoreService _firestoreService = FirestoreService();
  final ReportChatService _chatService = ReportChatService();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<WasteReport>> _reportsStream;
  late String _selectedFilter;

  String _searchQuery = '';
  bool _showFilters = false;

  final List<String> _filters = const [
    'All',
    'Assigned',
    'In Progress',
    'Under Review',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = _normalizeFilter(widget.initialFilter);

    final user = FirebaseAuth.instance.currentUser;
    _reportsStream = user == null
        ? Stream<List<WasteReport>>.value(const <WasteReport>[])
        : _firestoreService.getCollectorReports(user.uid);
  }

  @override
  void didUpdateWidget(covariant CollectorTaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter) {
      final nextFilter = _normalizeFilter(widget.initialFilter);
      if (nextFilter != _selectedFilter) {
        setState(() {
          _selectedFilter = nextFilter;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeFilter(String filter) {
    if (filter == 'Completion Submitted') return 'Under Review';
    return _filters.contains(filter) ? filter : 'All';
  }

  String _firestoreStatusForFilter(String filter) {
    if (filter == 'Under Review') return 'Completion Submitted';
    return filter;
  }

  String _displayStatus(String status) {
    if (status == 'Completion Submitted') return 'Under Review';
    return status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.blue;
      case 'Completion Submitted':
      case 'Under Review':
        return Colors.amber.shade800;
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
      return DateFormat('dd MMM, hh:mm a').format(date);
    } catch (_) {
      return 'No date';
    }
  }

  bool _matchesSearch(WasteReport report) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    return report.title.toLowerCase().contains(query) ||
        report.location.toLowerCase().contains(query) ||
        report.area.toLowerCase().contains(query) ||
        report.wasteType.toLowerCase().contains(query) ||
        _displayStatus(report.status).toLowerCase().contains(query);
  }

  bool _matchesStatus(WasteReport report) {
    if (_selectedFilter == 'All') return true;
    return report.status == _firestoreStatusForFilter(_selectedFilter);
  }

  Future<void> _openGoogleMaps(
    BuildContext context,
    WasteReport report,
  ) async {
    final query = Uri.encodeComponent(report.location);
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not launch Google Maps'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showNavigationOptions(
    BuildContext context,
    WasteReport report,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final canStart = report.status == 'Assigned';

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Icon(
                  Icons.navigation_rounded,
                  color: _collectorPrimary,
                  size: 32,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Navigation',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  canStart
                      ? 'You can view the location only, or start the task and navigate.'
                      : 'Open the report location in Google Maps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _openGoogleMaps(context, report);
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View Location Only'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _collectorPrimary,
                      side: const BorderSide(color: _collectorPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (canStart) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();

                        try {
                          await _firestoreService.startCollectorTask(
                            reportId: report.id,
                            collectorRemark: report.collectorRemark.isNotEmpty
                                ? report.collectorRemark
                                : 'Started via navigation',
                          );

                          await _openGoogleMaps(context, report);

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task started and navigating...'),
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
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Task & Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _collectorPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTaskDetails(WasteReport report) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectorReportDetailScreen(report: report),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    final hasActiveFilter = _selectedFilter != 'All';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search title, location or waste type...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _collectorPrimary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Filter tasks',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      _showFilters
                          ? Icons.filter_alt_rounded
                          : Icons.filter_alt_outlined,
                      color: _collectorPrimary,
                    ),
                  ),
                  if (hasActiveFilter)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: _collectorPrimary,
                      ),
                    ),
                ],
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
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.orange.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: _collectorPrimary,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBox(List<WasteReport> reports) {
    if (!_showFilters) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_selectedFilter != 'All')
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFilter = 'All';
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _collectorPrimary,
                  ),
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              final firestoreStatus = _firestoreStatusForFilter(filter);
              final count = filter == 'All'
                  ? reports.length
                  : reports.where((r) => r.status == firestoreStatus).length;

              return ChoiceChip(
                label: Text('$filter ($count)'),
                selected: isSelected,
                showCheckmark: false,
                selectedColor: _collectorPrimary,
                backgroundColor: Colors.orange.shade50,
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.orange.shade200,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.orange.shade900,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF4),
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report Tasks',
              style: TextStyle(
                fontWeight: FontWeight.w800,
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
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _collectorPrimary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load report tasks.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final allReports = snapshot.data ?? const <WasteReport>[];
          final filteredReports = allReports.where((report) {
            return _matchesSearch(report) && _matchesStatus(report);
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilterBar(),
              _buildFilterBox(allReports),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Found ${filteredReports.length} report task${filteredReports.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: filteredReports.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        key: const PageStorageKey<String>(
                          'collector_task_list_key',
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                        physics: const ClampingScrollPhysics(),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          return _buildTaskCard(
                            context,
                            filteredReports[index],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_turned_in_outlined,
                size: 54,
                color: _collectorPrimary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No report tasks found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'All'
                  ? 'Try changing your search or status filter.'
                  : 'Assigned report tasks will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canShowTaskChat(WasteReport report) {
    return report.status == 'Assigned' ||
        report.status == 'In Progress' ||
        report.status == 'Completion Submitted' ||
        report.status == 'Resolved';
  }

  void _openTaskChat(WasteReport report) {
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportChatScreen(
          reportId: report.id,
          reportTitle: report.title,
          reportLocation: report.location,
          reportLatitude: report.latitude,
          reportLongitude: report.longitude,
          currentRole: 'collector',
        ),
      ),
    );
  }

  String _taskChatPreview(dynamic message) {
    switch (message.type) {
      case 'image':
        final caption = message.text.toString().trim();
        return caption.isEmpty ? 'Photo' : 'Photo: $caption';
      case 'location':
        return 'Shared report location';
      default:
        final text = message.text.toString().trim();
        return text.isEmpty ? 'New message' : text;
    }
  }

  Widget _buildOutsideTaskChatPreview(WasteReport report) {
    if (!_canShowTaskChat(report)) {
      return const SizedBox.shrink();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder(
      stream: _chatService.watchMessages(report.id),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const [];
        final unreadCount = messages.where((message) {
          return uid.isNotEmpty &&
              message.senderId != uid &&
              !message.readBy.contains(uid);
        }).length;

        final hasMessages = messages.isNotEmpty;
        final lastMessage = hasMessages ? messages.first : null;
        final preview = lastMessage == null
            ? 'Chat with reporting User'
            : '${lastMessage.senderId == uid ? 'You' : 'User'}: '
                '${_taskChatPreview(lastMessage)}';

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: InkWell(
            onTap: () => _openTaskChat(report),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: unreadCount > 0
                    ? _collectorPrimary.withOpacity(0.12)
                    : Colors.orange.shade50.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unreadCount > 0
                      ? _collectorPrimary.withOpacity(0.45)
                      : Colors.orange.shade100,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: _collectorPrimary,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unreadCount > 0
                              ? '$unreadCount new ${unreadCount == 1 ? 'message' : 'messages'}'
                              : 'Report Chat',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _collectorPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    WasteReport report,
  ) {
    final displayStatus = _displayStatus(report.status);
    final statusColor = _statusColor(report.status);
    final proofRejected = report.status == 'In Progress' &&
        report.completionVerificationStatus.toLowerCase() == 'rejected';

    String actionLabel;
    IconData actionIcon;
    Color actionColor = _collectorPrimary;

    if (proofRejected) {
      actionLabel = 'Resubmit Proof';
      actionIcon = Icons.refresh_rounded;
      actionColor = Colors.red;
    } else if (report.status == 'Assigned') {
      actionLabel = 'Manage Task';
      actionIcon = Icons.play_circle_outline_rounded;
    } else if (report.status == 'In Progress') {
      actionLabel = 'Continue Task';
      actionIcon = Icons.task_alt_rounded;
    } else if (report.status == 'Completion Submitted') {
      actionLabel = 'View Review';
      actionIcon = Icons.fact_check_outlined;
      actionColor = Colors.amber.shade800;
    } else if (report.status == 'Resolved') {
      actionLabel = 'View Result';
      actionIcon = Icons.verified_outlined;
      actionColor = Colors.green;
    } else {
      actionLabel = 'View Details';
      actionIcon = Icons.open_in_new_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTaskDetails(report),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
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
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            : Icon(
                                Icons.image_outlined,
                                color: Colors.grey.shade400,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.11),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  displayStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (proofRejected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Proof Rejected',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            report.wasteType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _formatDate(report.createdAt),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11.5,
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
                const SizedBox(height: 13),
                InkWell(
                  onTap: () => _showNavigationOptions(context, report),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.near_me_rounded,
                          size: 17,
                          color: _collectorPrimary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            report.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.orange.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildOutsideTaskChatPreview(report),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showNavigationOptions(
                          context,
                          report,
                        ),
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Navigate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _collectorPrimary,
                          side: const BorderSide(color: _collectorPrimary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTaskDetails(report),
                        icon: Icon(actionIcon, size: 18),
                        label: Text(
                          actionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
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
  }
}
