import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/collection_area.dart';
import '../../models/collection_event.dart';
import '../../models/collection_schedule.dart';
import '../../services/collection_event_service.dart';
import '../../services/collection_schedule_service.dart';

enum _CollectionRunFilter {
  active,
  completedToday,
  all,
}

class CollectorCollectionScreen extends StatefulWidget {
  const CollectorCollectionScreen({super.key});

  @override
  State<CollectorCollectionScreen> createState() =>
      _CollectorCollectionScreenState();
}

class _CollectorCollectionScreenState
    extends State<CollectorCollectionScreen>
    with AutomaticKeepAliveClientMixin<CollectorCollectionScreen> {
  final CollectionScheduleService _scheduleService =
      CollectionScheduleService();

  final CollectionEventService _eventService =
      CollectionEventService();

  final TextEditingController _searchController =
      TextEditingController();

  bool _isLoading = true;
  bool _isRefreshing = false;

  String _searchQuery = '';

  _CollectionRunFilter _selectedRunFilter =
      _CollectionRunFilter.active;

  List<_CollectionDuty> _duties = [];

  // Local snapshot of today's collection-event status by areaId.
  // Areas without an event are treated as Not Started.
  Map<String, String> _todayEventStatusByAreaId =
      <String, String>{};

  // Areas that this collector currently has in progress today.
  // These are always promoted to the top of the Collection Runs list.
  Set<String> _inProgressAreaNames = <String>{};

  /// Collector assignment loaded from:
  ///
  /// users/{uid}.assignedCollectionZoneIds
  ///
  /// Collection Runs are STRICTLY limited to these zones.
  /// There is no fallback that shows all Kampar duties.
  List<String> _assignedZoneIds = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTodayDuties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD TODAY'S COLLECTION DUTIES
  // ============================================================

  Future<void> _loadTodayDuties({
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;

    if (forceRefresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await _loadCollectorZoneAssignment();

      final areas = await _scheduleService.getAvailableAreas(
        forceRefresh: forceRefresh,
      );

      final scheduleIds = areas
          .map((area) => area.scheduleId)
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();

      final scheduleResults = await Future.wait(
        scheduleIds.map(
          (scheduleId) =>
              _scheduleService.getScheduleById(scheduleId),
        ),
      );

      final schedulesById = <String, CollectionSchedule>{};

      for (final schedule in scheduleResults) {
        if (schedule != null) {
          schedulesById[schedule.scheduleId] = schedule;
        }
      }

      final todayWeekday = DateTime.now().weekday;

      final duties = <_CollectionDuty>[];

      for (final area in areas) {
        // IMPORTANT:
        // A collector may only see duties from zones assigned by Admin.
        if (!_assignedZoneIds.contains(area.zoneId)) {
          continue;
        }

        final schedule = schedulesById[area.scheduleId];

        if (schedule == null) {
          continue;
        }

        if (!schedule.collectsOnDay(todayWeekday)) {
          continue;
        }

        duties.add(
          _CollectionDuty(
            area: area,
            schedule: schedule,
          ),
        );
      }

      await _loadInProgressAreasForToday();

      _sortDutiesByPriority(duties);

      if (!mounted) return;

      setState(() {
        _duties = duties;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load today\'s collection duties: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // COLLECTOR ZONE ASSIGNMENT
  // ============================================================

  Future<void> _loadCollectorZoneAssignment() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _assignedZoneIds = [];
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data == null) {
      _assignedZoneIds = [];
      return;
    }

    final raw = data['assignedCollectionZoneIds'];

    if (raw is! Iterable) {
      _assignedZoneIds = [];
      return;
    }

    _assignedZoneIds = raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String _zoneDisplayName(String zoneId) {
    switch (zoneId) {
      case 'kampar_zone_1':
        return 'Zone 1 • Kampar - Tronoh Mines';

      case 'kampar_zone_2':
        return 'Zone 2 • Kampar - Bandar Baru';

      case 'kampar_zone_3':
        return 'Zone 3 • Kampar Barat - Jeram';

      case 'kampar_zone_4':
        return 'Zone 4 • Gopeng';

      default:
        return zoneId;
    }
  }

  // ============================================================
  // ACTIVE COLLECTION PRIORITY
  // ============================================================

  Future<void> _loadInProgressAreasForToday() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _inProgressAreaNames = <String>{};
      _todayEventStatusByAreaId = <String, String>{};
      return;
    }

    try {
      final todayKey = DateFormat('yyyy-MM-dd').format(
        DateTime.now(),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('collection_events')
          .where(
            'collectionDate',
            isEqualTo: todayKey,
          )
          .get();

      final activeAreas = <String>{};
      final statusesByAreaId = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final collectorId =
            data['collectorId']?.toString().trim() ?? '';

        if (collectorId != user.uid) {
          continue;
        }

        final status =
            data['status']?.toString().trim().toLowerCase() ?? '';

        final areaId =
            data['areaId']?.toString().trim() ?? '';

        final areaName =
            data['areaName']?.toString().trim() ?? '';

        if (areaId.isNotEmpty && status.isNotEmpty) {
          statusesByAreaId[areaId] = status;
        }

        if (status == 'in_progress' &&
            areaName.isNotEmpty) {
          activeAreas.add(areaName);
        }
      }

      _inProgressAreaNames = activeAreas;
      _todayEventStatusByAreaId = statusesByAreaId;
    } catch (_) {
      // Keep the screen usable if the summary lookup fails.
      // Individual cards still listen to their event streams.
      _inProgressAreaNames = <String>{};
      _todayEventStatusByAreaId = <String, String>{};
    }
  }

  bool _isDutyInProgress(_CollectionDuty duty) {
    return _inProgressAreaNames.contains(
      duty.area.areaName.trim(),
    );
  }

  void _sortDutiesByPriority(
    List<_CollectionDuty> duties,
  ) {
    duties.sort((a, b) {
      final aInProgress = _isDutyInProgress(a);
      final bInProgress = _isDutyInProgress(b);

      // In-progress collection runs always appear first.
      if (aInProgress != bInProgress) {
        return aInProgress ? -1 : 1;
      }

      final zoneCompare = a.area.zoneId.compareTo(
        b.area.zoneId,
      );

      if (zoneCompare != 0) {
        return zoneCompare;
      }

      return a.area.areaName.toLowerCase().compareTo(
            b.area.areaName.toLowerCase(),
          );
    });
  }

  void _updateLocalDutyStatus(
    _CollectionDuty duty,
    String status,
  ) {
    if (!mounted) return;

    setState(() {
      final cleanStatus =
          status.trim().toLowerCase();

      _todayEventStatusByAreaId[
        duty.area.areaId
      ] = cleanStatus;

      if (cleanStatus == 'in_progress') {
        _inProgressAreaNames.add(
          duty.area.areaName.trim(),
        );
      } else {
        _inProgressAreaNames.remove(
          duty.area.areaName.trim(),
        );
      }

      _sortDutiesByPriority(_duties);
    });
  }

  String _localStatusForDuty(
    _CollectionDuty duty,
  ) {
    return _todayEventStatusByAreaId[
          duty.area.areaId
        ] ??
        'not_started';
  }

  String _runFilterLabel(
    _CollectionRunFilter filter,
  ) {
    switch (filter) {
      case _CollectionRunFilter.active:
        return 'Active';

      case _CollectionRunFilter.completedToday:
        return 'Completed Today';

      case _CollectionRunFilter.all:
        return 'All';
    }
  }

  IconData _runFilterIcon(
    _CollectionRunFilter filter,
  ) {
    switch (filter) {
      case _CollectionRunFilter.active:
        return Icons.pending_actions_rounded;

      case _CollectionRunFilter.completedToday:
        return Icons.check_circle_outline_rounded;

      case _CollectionRunFilter.all:
        return Icons.view_list_rounded;
    }
  }

  String _dutyCountLabel(
    int count,
  ) {
    switch (_selectedRunFilter) {
      case _CollectionRunFilter.active:
        return '$count active collection '
            '${count == 1 ? 'run' : 'runs'}';

      case _CollectionRunFilter.completedToday:
        return '$count completed '
            '${count == 1 ? 'area' : 'areas'} today';

      case _CollectionRunFilter.all:
        return '$count scheduled '
            '${count == 1 ? 'area' : 'areas'} today';
    }
  }

  // ============================================================
  // FILTER DUTIES
  // ============================================================

  List<_CollectionDuty> get _filteredDuties {
    final query = _searchQuery.trim().toLowerCase();

    return _duties.where((duty) {
      final status = _localStatusForDuty(duty);

      final bool matchesRunFilter;

      switch (_selectedRunFilter) {
        case _CollectionRunFilter.active:
          matchesRunFilter = status != 'collected';
          break;

        case _CollectionRunFilter.completedToday:
          matchesRunFilter = status == 'collected';
          break;

        case _CollectionRunFilter.all:
          matchesRunFilter = true;
          break;
      }

      if (!matchesRunFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final area = duty.area;

      final values = <String>[
        area.areaName,
        area.zoneName,
        area.zoneArea,
        area.district,
        ...area.aliases,
        ...area.landmarks,
        ...area.streetPatterns,
      ];

      return values.any(
        (value) => value.toLowerCase().contains(query),
      );
    }).toList();
  }

  // ============================================================
  // TIME HELPERS
  // ============================================================

  String _formatTime(
    int hour,
    int minute,
  ) {
    return TimeOfDay(
      hour: hour,
      minute: minute,
    ).format(context);
  }

  String _formatEventTime(
    DateTime? date,
  ) {
    if (date == null) {
      return '';
    }

    return DateFormat('hh:mm a').format(date);
  }

  String _formatTodayDate() {
    return DateFormat(
      'EEEE, d MMMM yyyy',
    ).format(DateTime.now());
  }

  // ============================================================
  // EVENT STATUS
  // ============================================================

  String _eventStatusLabel(
    CollectionEvent? event,
  ) {
    if (event == null) {
      return 'Not Started';
    }

    switch (event.status) {
      case 'in_progress':
        return 'In Progress';

      case 'collected':
        return 'Collected';

      case 'missed':
        return 'Missed';

      case 'pending':
        return 'Pending';

      default:
        return 'Unknown';
    }
  }

  Color _eventStatusColor(
    CollectionEvent? event,
  ) {
    if (event == null) {
      return Colors.grey;
    }

    switch (event.status) {
      case 'in_progress':
        return Colors.orange;

      case 'collected':
        return Colors.green;

      case 'missed':
        return Colors.red;

      case 'pending':
        return Colors.blueGrey;

      default:
        return Colors.grey;
    }
  }

  IconData _eventStatusIcon(
    CollectionEvent? event,
  ) {
    if (event == null) {
      return Icons.radio_button_unchecked_rounded;
    }

    switch (event.status) {
      case 'in_progress':
        return Icons.local_shipping_outlined;

      case 'collected':
        return Icons.check_circle_outline_rounded;

      case 'missed':
        return Icons.cancel_outlined;

      case 'pending':
        return Icons.schedule_rounded;

      default:
        return Icons.help_outline_rounded;
    }
  }

  // ============================================================
  // START COLLECTION
  // ============================================================

  Future<void> _startCollection(
    _CollectionDuty duty,
  ) async {
    final confirmed = await _confirmAction(
      title: 'Start Collection?',
      message:
          'Start collection for ${duty.area.areaName}? '
          'Residents will be able to see that collection is in progress.',
      confirmText: 'Start',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _eventService.startCollection(
        area: duty.area,
        schedule: duty.schedule,
      );

      if (!mounted) return;

      // Move the newly started collection to the top immediately.
      _updateLocalDutyStatus(
        duty,
        'in_progress',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Collection started for ${duty.area.areaName}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MARK COLLECTED
  // ============================================================

  Future<void> _markCollected(
    _CollectionDuty duty,
  ) async {
    final confirmed = await _confirmAction(
      title: 'Mark as Collected?',
      message:
          'Confirm that waste collection for ${duty.area.areaName} '
          'has been completed.',
      confirmText: 'Collected',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _eventService.markAsCollected(
        area: duty.area,
      );

      if (!mounted) return;

      // Completed work disappears from the default Active view,
      // but remains available under Completed Today and All.
      _updateLocalDutyStatus(
        duty,
        'collected',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${duty.area.areaName} marked as collected.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MARK MISSED
  // ============================================================

  Future<void> _markMissed(
    _CollectionDuty duty,
  ) async {
    final confirmed = await _confirmAction(
      title: 'Mark as Missed?',
      message:
          'Use this only if today\'s scheduled collection for '
          '${duty.area.areaName} could not be completed.',
      confirmText: 'Mark Missed',
      destructive: true,
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _eventService.markAsMissed(
        area: duty.area,
        schedule: duty.schedule,
      );

      if (!mounted) return;

      _updateLocalDutyStatus(
        duty,
        'missed',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${duty.area.areaName} marked as missed.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // CONFIRM DIALOG
  // ============================================================

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: destructive
                    ? Colors.red
                    : Colors.orange,
              ),
              child: Text(
                confirmText,
              ),
            ),
          ],
        );
      },
    );
  }

  String _cleanError(
    Object error,
  ) {
    final text = error.toString();

    if (text.startsWith('Bad state: ')) {
      return text.substring(
        'Bad state: '.length,
      );
    }

    return text;
  }

  // ============================================================
  // RUN FILTER BUTTON
  // ============================================================

  Widget _buildRunFilterButton() {
    final isDefault =
        _selectedRunFilter ==
            _CollectionRunFilter.active;

    return PopupMenuButton<_CollectionRunFilter>(
      tooltip: 'Filter collection runs',
      onSelected: (filter) {
        setState(() {
          _selectedRunFilter = filter;
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) {
        return _CollectionRunFilter.values.map(
          (filter) {
            final selected =
                _selectedRunFilter == filter;

            return PopupMenuItem<_CollectionRunFilter>(
              value: filter,
              child: Row(
                children: [
                  Icon(
                    _runFilterIcon(filter),
                    size: 20,
                    color: selected
                        ? Colors.orange.shade700
                        : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _runFilterLabel(filter),
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? Colors.orange.shade800
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: Colors.orange.shade700,
                    ),
                ],
              ),
            );
          },
        ).toList();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.filter_list_rounded,
              color: Colors.orange.shade700,
            ),
          ),
          if (!isDefault)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7F9FC),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Collection Runs',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildRunFilterButton(),
            ],
          ),

          const SizedBox(height: 5),

          Text(
            _formatTodayDate(),
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          if (_assignedZoneIds.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.shade100,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'No collection zone is currently assigned to this '
                      'collector account.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              _assignedZoneIds.length == 1
                  ? 'Assigned Collection Zone'
                  : 'Assigned Collection Zones',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _assignedZoneIds.map((zoneId) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange.shade100,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _zoneDisplayName(zoneId),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 7),

            Text(
              'Only collection runs from your assigned zone'
              '${_assignedZoneIds.length == 1 ? '' : 's'} are shown.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        2,
        16,
        10,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              'Search area, zone or landmark...',
          prefixIcon: const Icon(
            Icons.search_rounded,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.orange.shade400,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DUTY CARD
  // ============================================================

  Widget _buildDutyCard(
    _CollectionDuty duty,
  ) {
    return StreamBuilder<CollectionEvent?>(
      key: ValueKey(
        'collection_run_${duty.area.areaName}',
      ),
      stream: _eventService.watchTodayEvent(
        duty.area,
      ),
      builder: (
        context,
        snapshot,
      ) {
        final event = snapshot.data;

        final statusColor =
            _eventStatusColor(event);

        final statusLabel =
            _eventStatusLabel(event);

        final statusIcon =
            _eventStatusIcon(event);

        return Container(
          margin: const EdgeInsets.only(
            bottom: 14,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: event?.isInProgress == true
                  ? Colors.orange.shade200
                  : event?.isCollected == true
                  ? Colors.green.shade200
                  : event?.isMissed == true
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(
                  0.035,
                ),
                blurRadius: 10,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          Colors.orange.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .delete_outline_rounded,
                      color:
                          Colors.orange.shade700,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          duty.area.areaName,
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '${duty.area.zoneName} • '
                          '${duty.area.zoneArea}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withOpacity(0.10),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Icon(
                    Icons
                        .access_time_rounded,
                    size: 17,
                    color:
                        Colors.grey.shade600,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    '${_formatTime(
                      duty.schedule.startHour,
                      duty.schedule.startMinute,
                    )} - '
                    '${_formatTime(
                      duty.schedule.endHour,
                      duty.schedule.endMinute,
                    )}',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          Colors.grey.shade700,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),

              if (event?.startedAt != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 17,
                      color:
                          Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Started: '
                      '${_formatEventTime(
                        event!.startedAt,
                      )}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              if (event?.collectedAt != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline_rounded,
                      size: 17,
                      color:
                          Colors.green.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Collected: '
                      '${_formatEventTime(
                        event!.collectedAt,
                      )}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            Colors.green.shade700,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              Divider(
                height: 1,
                color:
                    Colors.grey.shade100,
              ),

              const SizedBox(height: 12),

              _buildDutyActions(
                duty,
                event,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DUTY ACTIONS
  // ============================================================

  Widget _buildDutyActions(
    _CollectionDuty duty,
    CollectionEvent? event,
  ) {
    // No event yet.
    if (event == null ||
        event.status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _markMissed(duty);
              },
              icon: const Icon(
                Icons.close_rounded,
              ),
              label: const Text(
                'Missed',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red.shade600,
                side: BorderSide(
                  color:
                      Colors.red.shade200,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                _startCollection(duty);
              },
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text(
                'Start Collection',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.orange,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (event.isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            _markCollected(duty);
          },
          icon: const Icon(
            Icons.check_rounded,
          ),
          label: const Text(
            'Mark as Collected',
          ),
          style: ElevatedButton.styleFrom(
            // Amber indicates an action that will complete the run.
            // Green is reserved for the final Collected state.
            backgroundColor:
                Colors.amber.shade700,
            foregroundColor:
                Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(
              vertical: 12,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
          ),
        ),
      );
    }

    if (event.isCollected) {
      return Row(
        children: [
          Icon(
            Icons
                .check_circle_rounded,
            color:
                Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.collectedAt == null
                  ? 'Collection completed.'
                  : 'Completed at '
                      '${_formatEventTime(event.collectedAt)}.',
              style: TextStyle(
                color:
                    Colors.green.shade700,
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (event.isMissed) {
      return Row(
        children: [
          Icon(
            Icons.cancel_rounded,
            color:
                Colors.red.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Collection marked as missed.',
              style: TextStyle(
                color:
                    Colors.red.shade700,
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final noAssignment =
        _assignedZoneIds.isEmpty;

    final completedFilter =
        _selectedRunFilter ==
            _CollectionRunFilter.completedToday;

    final allFilter =
        _selectedRunFilter ==
            _CollectionRunFilter.all;

    final String title;
    final String message;
    final IconData icon;
    final Color iconColor;

    if (noAssignment) {
      title = 'No Collection Zone Assigned';
      message =
          'An administrator must assign at least one collection '
          'zone before collection runs can be shown.';
      icon = Icons.location_off_outlined;
      iconColor = Colors.orange.shade200;
    } else if (completedFilter) {
      title = 'No Completed Work Yet';
      message =
          'Collections marked as completed today will appear here '
          'with their start and completion times.';
      icon = Icons.check_circle_outline_rounded;
      iconColor = Colors.green.shade200;
    } else if (allFilter) {
      title = 'No Collection Runs Today';
      message =
          'There are no scheduled collection areas in your '
          'assigned zone${_assignedZoneIds.length == 1 ? '' : 's'} today.';
      icon = Icons.local_shipping_outlined;
      iconColor = Colors.grey.shade300;
    } else {
      title = 'No Active Collection Runs';
      message =
          'All scheduled collection work shown for your assigned '
          'zone${_assignedZoneIds.length == 1 ? '' : 's'} is already completed.';
      icon = Icons.task_alt_rounded;
      iconColor = Colors.green.shade200;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 70,
              color: iconColor,
            ),

            const SizedBox(height: 15),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    super.build(context);

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Not logged in',
          ),
        ),
      );
    }

    final duties = _filteredDuties;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            _buildSearchBar(),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dutyCountLabel(
                        duties.length,
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors
                            .grey.shade500,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Refresh',
                    onPressed:
                        _isRefreshing
                            ? null
                            : () {
                                _loadTodayDuties(
                                  forceRefresh:
                                      true,
                                );
                              },
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange,
                            ),
                          )
                        : const Icon(
                            Icons
                                .refresh_rounded,
                          ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color: Colors.orange,
                      ),
                    )
                  : duties.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color:
                              Colors.orange,
                          onRefresh: () {
                            return _loadTodayDuties(
                              forceRefresh:
                                  true,
                            );
                          },
                          child:
                              ListView.builder(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              16,
                              4,
                              16,
                              110,
                            ),
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            itemCount:
                                duties.length,
                            itemBuilder: (
                              context,
                              index,
                            ) {
                              return _buildDutyCard(
                                duties[index],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TODAY DUTY MODEL
// ============================================================================

class _CollectionDuty {
  final CollectionArea area;
  final CollectionSchedule schedule;

  const _CollectionDuty({
    required this.area,
    required this.schedule,
  });
}
