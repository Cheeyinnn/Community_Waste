import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/report_chat_message.dart';
import '../../models/waste_report.dart';
import '../../services/report_chat_service.dart';
import 'report_chat_screen.dart';

class ReportMessagesScreen extends StatefulWidget {
  /// Use "user", "collector", or "admin".
  final String currentRole;

  const ReportMessagesScreen({
    super.key,
    required this.currentRole,
  });

  @override
  State<ReportMessagesScreen> createState() => _ReportMessagesScreenState();
}

class _ReportMessagesScreenState extends State<ReportMessagesScreen> {
  static const Color _userPrimary = Color(0xFF35C76F);
  static const Color _collectorPrimary = Color(0xFFFFB547);
  static const Color _adminPrimary = Colors.blue;

  final ReportChatService _chatService = ReportChatService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _showFilters = false;
  bool _unreadOnly = false;

  String get _role => widget.currentRole.trim().toLowerCase();
  bool get _isCollector => _role == 'collector';
  bool get _isAdmin => _role == 'admin';

  Color get _primary {
    if (_isCollector) return _collectorPrimary;
    if (_isAdmin) return _adminPrimary;
    return _userPrimary;
  }

  Color get _background {
    if (_isCollector) return const Color(0xFFFFFAF4);
    if (_isAdmin) return const Color(0xFFEFF6FF);
    return const Color(0xFFEFF8F6);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayStatus(String status) {
    if (status == 'Completion Submitted') {
      if (_isCollector) return 'Under Admin Review';
      if (_isAdmin) return 'Completion Submitted';
      return 'Under Verification';
    }
    return status;
  }

  Color _statusColor(String status) {
    switch (status) {
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
        return Colors.grey;
    }
  }

  Color _channelColor(ReportChatChannel channel) {
    return channel == ReportChatChannel.adminCollector
        ? _adminPrimary
        : _userPrimary;
  }

  String _channelLabel(ReportChatChannel channel) {
    return channel == ReportChatChannel.adminCollector
        ? 'Admin ↔ Collector'
        : 'User ↔ Collector';
  }

  String _otherParticipant(ReportChatThread thread) {
    final report = thread.report;

    if (thread.channel == ReportChatChannel.adminCollector) {
      if (_isCollector) return 'Administrator';
      final name = report.collectorName.trim();
      return name.isEmpty ? 'Collector' : name;
    }

    if (_isCollector) {
      final name = report.userName.trim();
      return name.isEmpty ? 'User' : name;
    }

    final name = report.collectorName.trim();
    return name.isEmpty ? 'Collector' : name;
  }

  String _fallbackSenderLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'collector':
        return 'Collector';
      case 'user':
      default:
        return 'User';
    }
  }

  String _messagePreview(
    ReportChatThread thread,
    ReportChatMessage? message,
  ) {
    if (message == null) {
      return thread.channel == ReportChatChannel.adminCollector
          ? 'Start an operational conversation about this report'
          : 'Start a conversation about this report';
    }

    final prefix = message.senderRole == _role
        ? 'You: '
        : '${message.senderName.trim().isEmpty ? _fallbackSenderLabel(message.senderRole) : message.senderName}: ';

    switch (message.type) {
      case 'image':
        final caption = message.text.trim();
        return caption.isEmpty ? '${prefix}Photo' : '${prefix}Photo • $caption';
      case 'location':
        final label = message.locationLabel.trim();
        return label.isEmpty
            ? '${prefix}Location shared'
            : '${prefix}Location • $label';
      case 'text':
      default:
        return '$prefix${message.text.trim()}';
    }
  }

  String _formatThreadTime(ReportChatThread thread) {
    final timestamp = thread.lastMessage?.createdAt ?? thread.report.updatedAt;
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('hh:mm a').format(date);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    }

    return DateFormat('d MMM yyyy').format(date);
  }

  List<ReportChatThread> _filterThreads(List<ReportChatThread> threads) {
    final query = _searchQuery.trim().toLowerCase();

    return threads.where((thread) {
      if (_unreadOnly && thread.unreadCount <= 0) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final report = thread.report;
      final latest = thread.lastMessage;

      final values = <String>[
        report.title,
        report.location,
        report.area,
        report.wasteType,
        _displayStatus(report.status),
        _otherParticipant(thread),
        _channelLabel(thread.channel),
        latest?.text ?? '',
        latest?.locationLabel ?? '',
        latest?.senderName ?? '',
      ];

      return values.any(
        (value) => value.toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _openChat(ReportChatThread thread) async {
    final report = thread.report;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportChatScreen(
          reportId: report.id,
          reportTitle: report.title,
          reportLocation: report.location,
          reportLatitude: report.latitude,
          reportLongitude: report.longitude,
          currentRole: _role,
          channel: thread.channel,
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _primary : _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _primary : _primary.withOpacity(0.18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _primary,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search messages or reports...',
              prefixIcon: const Icon(Icons.search_rounded),
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
                        tooltip: 'Filter messages',
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                        icon: Icon(
                          _showFilters
                              ? Icons.tune_rounded
                              : Icons.filter_list_rounded,
                          color: _primary,
                        ),
                      ),
                      if (_unreadOnly)
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Message Filter',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_unreadOnly)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _unreadOnly = false;
                            });
                          },
                          style: TextButton.styleFrom(foregroundColor: _primary),
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip(
                        label: 'All',
                        selected: !_unreadOnly,
                        onTap: () {
                          setState(() {
                            _unreadOnly = false;
                          });
                        },
                      ),
                      _filterChip(
                        label: 'Unread',
                        selected: _unreadOnly,
                        onTap: () {
                          setState(() {
                            _unreadOnly = true;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadCard(ReportChatThread thread) {
    final report = thread.report;
    final unread = thread.unreadCount;
    final participant = _otherParticipant(thread);
    final statusColor = _statusColor(report.status);
    final channelColor = _channelColor(thread.channel);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _openChat(thread),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unread > 0
                  ? _primary.withOpacity(0.34)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: channelColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  thread.channel == ReportChatChannel.adminCollector
                      ? Icons.admin_panel_settings_outlined
                      : Icons.forum_outlined,
                  color: channelColor,
                ),
              ),
              const SizedBox(width: 12),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  unread > 0 ? FontWeight.w900 : FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatThreadTime(thread),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: unread > 0 ? _primary : Colors.grey.shade500,
                            fontWeight:
                                unread > 0 ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: channelColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _channelLabel(thread.channel),
                            style: TextStyle(
                              color: channelColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          participant,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _messagePreview(thread, thread.lastMessage),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight:
                                  unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _displayStatus(report.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool noThreads}) {
    String emptyText;

    if (_isAdmin) {
      emptyText = 'Assigned Collector conversations will appear here.';
    } else if (_isCollector) {
      emptyText = 'User and Admin conversations for your assigned reports will appear here.';
    } else {
      emptyText = 'Chats become available after a Collector is assigned to your report.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                noThreads
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.search_off_rounded,
                size: 38,
                color: _primary.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              noThreads ? 'No Conversations Yet' : 'No Matching Conversations',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              noThreads
                  ? emptyText
                  : 'Try another search or reset the message filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<ReportChatThread>>(
        stream: _chatService.watchThreads(currentRole: _role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load messages.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final allThreads = snapshot.data ?? <ReportChatThread>[];
          final threads = _filterThreads(allThreads);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilter(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 9),
                child: Text(
                  '${threads.length} conversation${threads.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Expanded(
                child: allThreads.isEmpty
                    ? _buildEmptyState(noThreads: true)
                    : threads.isEmpty
                        ? _buildEmptyState(noThreads: false)
                        : ListView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 34),
                            itemCount: threads.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildThreadCard(threads[index]),
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
