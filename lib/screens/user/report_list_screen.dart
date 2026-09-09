import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/report_chat_service.dart';
import '../shared/report_chat_screen.dart';
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
  static const Color _primaryGreen = Color(0xFF35C76F);
  static const Color _pageBackground = Color(0xFFEFF8F6);

  final FirestoreService _firestoreService = FirestoreService();
  final ReportChatService _chatService = ReportChatService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final Stream<List<WasteReport>> _reportsStream;

  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  bool _showFilters = false;

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Under Verification',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    _reportsStream = user == null
        ? Stream<List<WasteReport>>.value(const <WasteReport>[])
        : _firestoreService.getUserReports(user.uid);

    _selectedStatusFilter = widget.initialStatusFilter ?? 'All';
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
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _goBackHome() {
    if (widget.onBack != null) {
      widget.onBack!.call();
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  String _firestoreStatusForFilter(String filter) {
    if (filter == 'Under Verification') {
      return 'Completion Submitted';
    }

    return filter;
  }

  String _displayStatus(String status) {
    if (status == 'Completion Submitted') {
      return 'Under Verification';
    }

    return status;
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
      case 'Under Verification':
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
    try {
      final date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return '-';
    }
  }

  bool _matchesSearch(WasteReport report) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final searchableText = <String>[
      report.title,
      report.location,
      report.area,
      report.wasteType,
      _displayStatus(report.status),
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  List<WasteReport> _applyFilters(List<WasteReport> allReports) {
    Iterable<WasteReport> reports = allReports.where(_matchesSearch);

    if (_selectedStatusFilter != 'All') {
      final selectedFirestoreStatus =
          _firestoreStatusForFilter(_selectedStatusFilter);

      reports = reports.where(
        (report) => report.status == selectedFirestoreStatus,
      );
    }

    return reports.toList();
  }

  int _countForFilter(
    String filter,
    List<WasteReport> allReports,
  ) {
    final searchMatched = allReports.where(_matchesSearch);

    if (filter == 'All') {
      return searchMatched.length;
    }

    final firestoreStatus = _firestoreStatusForFilter(filter);

    return searchMatched
        .where((report) => report.status == firestoreStatus)
        .length;
  }

  void _setStatusFilter(String filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });

    widget.onFilterChanged?.call(filter);
  }

  void _resetFilters() {
    setState(() {
      _selectedStatusFilter = 'All';
    });

    widget.onFilterChanged?.call('All');
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
      backgroundColor: _pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _goBackHome,
        ),
        title: const Text(
          'My Reports',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 23,
          ),
        ),
        backgroundColor: _pageBackground,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _primaryGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your reports.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final allReports = snapshot.data ?? <WasteReport>[];
          final reports = _applyFilters(allReports);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchSection(allReports),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                child: Text(
                  _resultLabel(reports.length),
                  style: TextStyle(
                    color: Colors.grey.shade600,
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
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          6,
                          20,
                          125,
                        ),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return _buildReportCard(
                            context,
                            reports[index],
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

  Widget _buildSearchSection(List<WasteReport> allReports) {
    final hasActiveFilter = _selectedStatusFilter != 'All';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search title, location or waste type',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _primaryGreen,
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
                          _searchFocusNode.requestFocus();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                      ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Filter reports',
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
                            color: _primaryGreen,
                          ),
                        ),
                        if (hasActiveFilter)
                          const Positioned(
                            right: 7,
                            top: 7,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: _primaryGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: _primaryGreen,
                    width: 1.8,
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(
              width: double.infinity,
              height: 0,
            ),
            secondChild: _buildFilterBox(allReports),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBox(List<WasteReport> allReports) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _primaryGreen.withOpacity(0.16),
        ),
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
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 20,
                color: _primaryGreen,
              ),
              const SizedBox(width: 8),
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
              if (_selectedStatusFilter != 'All')
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filters.map((filter) {
              final selected = _selectedStatusFilter == filter;
              final color = filter == 'All'
                  ? _primaryGreen
                  : _statusColor(filter);
              final count = _countForFilter(filter, allReports);

              return ChoiceChip(
                label: Text('$filter ($count)'),
                selected: selected,
                onSelected: (_) => _setStatusFilter(filter),
                selectedColor: color,
                backgroundColor: color.withOpacity(0.06),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected
                        ? Colors.transparent
                        : color.withOpacity(0.24),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _resultLabel(int count) {
    final query = _searchQuery.trim();
    final status = _selectedStatusFilter;

    if (query.isNotEmpty && status != 'All') {
      return '$count ${status.toLowerCase()} report${count == 1 ? '' : 's'} matching "$query"';
    }

    if (query.isNotEmpty) {
      return 'Found $count report${count == 1 ? '' : 's'} matching "$query"';
    }

    if (status != 'All') {
      return '$count ${status.toLowerCase()} report${count == 1 ? '' : 's'}';
    }

    return '$count report${count == 1 ? '' : 's'}';
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final hasFilter = _selectedStatusFilter != 'All';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryGreen.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 56,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No reports found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch || hasFilter
                  ? 'Try changing your search or report status filter.'
                  : 'When you submit a waste report, it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
            if (hasSearch || hasFilter) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedStatusFilter = 'All';
                  });
                  widget.onFilterChanged?.call('All');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryGreen,
                  side: const BorderSide(color: _primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Clear Search & Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canShowReportChat(WasteReport report) {
    if (report.collectorId.trim().isEmpty) return false;

    return report.status == 'Assigned' ||
        report.status == 'In Progress' ||
        report.status == 'Completion Submitted' ||
        report.status == 'Resolved';
  }

  void _openReportChat(WasteReport report) {
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
          currentRole: 'user',
        ),
      ),
    );
  }

  String _chatMessagePreview(dynamic message) {
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

  Widget _buildOutsideChatPreview(WasteReport report) {
    if (!_canShowReportChat(report)) {
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
            ? 'Chat with assigned Collector'
            : '${lastMessage.senderId == uid ? 'You' : 'Collector'}: '
                '${_chatMessagePreview(lastMessage)}';

        final accent = unreadCount > 0 ? _primaryGreen : Colors.grey.shade600;

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: InkWell(
            onTap: () => _openReportChat(report),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: unreadCount > 0
                    ? _primaryGreen.withOpacity(0.09)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: unreadCount > 0
                      ? _primaryGreen.withOpacity(0.25)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: accent,
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
                            color: unreadCount > 0
                                ? _primaryGreen
                                : Colors.black87,
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: unreadCount > 0
                        ? _primaryGreen
                        : Colors.grey.shade400,
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

  Widget _buildReportCard(BuildContext context, WasteReport report) {
    final displayStatus = _displayStatus(report.status);
    final statusColor = _statusColor(displayStatus);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(
                report: report,
                isAdmin: false,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.grey.shade100,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 88,
                  height: 88,
                  color: Colors.grey.shade100,
                  child: report.imageUrl.isNotEmpty
                      ? Image.network(
                          report.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            );
                          },
                        )
                      : const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.2,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          label: displayStatus,
                          color: statusColor,
                        ),
                        _buildBadge(
                          label: report.wasteType,
                          color: _primaryGreen,
                          muted: true,
                        ),
                      ],
                    ),
                    _buildOutsideChatPreview(report),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(muted ? 0.07 : 0.11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: muted ? color.withOpacity(0.85) : color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
