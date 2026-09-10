import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/collection_area.dart';
import '../../models/collection_event.dart';
import '../../models/collection_schedule.dart';
import '../../services/collection_event_service.dart';
import '../../services/collection_schedule_service.dart';

class CollectionScheduleScreen extends StatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  State<CollectionScheduleScreen> createState() =>
      _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState
    extends State<CollectionScheduleScreen>
    with AutomaticKeepAliveClientMixin<CollectionScheduleScreen> {
  final CollectionScheduleService _scheduleService =
      CollectionScheduleService();

  final CollectionEventService _eventService =
      CollectionEventService();

  List<CollectionArea> _areas = [];
  CollectionArea? _selectedArea;

  bool _isLoadingAreas = true;
  bool _isDetectingLocation = false;

  String _locationMessage = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  // ============================================================
  // LOAD AREAS + SAVED USER AREA
  // ============================================================

  Future<void> _loadAreas() async {
    try {
      final areas = await _scheduleService.getAvailableAreas(forceRefresh: true);
      final savedArea = await _scheduleService.getSavedPreferredArea();

      if (!mounted) return;

      CollectionArea? selectedArea;

      if (savedArea != null) {
        for (final area in areas) {
          if (area.areaId == savedArea.areaId) {
            selectedArea = area;
            break;
          }
        }
      }

      setState(() {
        _areas = areas;
        _selectedArea = selectedArea;
        _isLoadingAreas = false;

        if (selectedArea != null) {
          _locationMessage =
              'Using saved area: ${selectedArea.areaName}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAreas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load collection areas: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SELECT + SAVE AREA
  // ============================================================

  Future<void> _selectArea(
    CollectionArea area, {
    String? message,
  }) async {
    if (!mounted) return;

    setState(() {
      _selectedArea = area;
      _locationMessage =
          message ?? 'Selected area: ${area.areaName}';
    });

    try {
      await _scheduleService.savePreferredArea(area);
    } catch (_) {
      // Saving the preference is optional.
      // The schedule still works even if this write fails.
    }
  }

  // ============================================================
  // SEARCHABLE AREA PICKER
  // ============================================================

  Future<void> _openAreaPicker() async {
    if (_areas.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<CollectionArea>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AreaPickerSheet(
          areas: _areas,
          currentAreaId: _selectedArea?.areaId,
          scheduleService: _scheduleService,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    await _selectArea(
      selected,
      message: 'Area set to ${selected.areaName}',
    );
  }

  // ============================================================
  // GPS
  // ============================================================

  Future<void> _detectAndSelectArea() async {
    if (_isDetectingLocation) {
      return;
    }

    setState(() {
      _isDetectingLocation = true;
      _locationMessage = 'Detecting your location...';
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location services are disabled. Please enable GPS.';
        });

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location permission was denied. Search your area manually.';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location permission is permanently denied. Enable it in phone settings.';
        });

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'GPS was found, but the address could not be identified.';
        });

        return;
      }

      // Only Perak is supported.
      final stateNames = placemarks
          .map(
            (place) =>
                (place.administrativeArea ?? '').trim(),
          )
          .where((value) => value.isNotEmpty)
          .toList();

      if (stateNames.isNotEmpty &&
          !stateNames.any(
            (value) =>
                value.toLowerCase().contains('perak'),
          )) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Your current location appears to be outside Perak.';
        });

        return;
      }

      final detectedNames =
          _buildDetectedSearchNames(placemarks);

      final matchedArea =
          await _scheduleService.findCollectionAreaFromLocation(
        detectedNames,
      );

      if (!mounted) return;

      final readableAddress =
          _buildReadableDetectedAddress(placemarks);

      if (matchedArea != null) {
        await _selectArea(
          matchedArea,
          message: readableAddress.isEmpty
              ? 'Location matched to ${matchedArea.areaName}'
              : '$readableAddress → ${matchedArea.areaName}',
        );

        return;
      }

      setState(() {
        if (readableAddress.isEmpty) {
          _locationMessage =
              'GPS could not identify your exact collection area. Search manually.';
        } else {
          _locationMessage =
              '$readableAddress • exact collection area not found';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationMessage =
            'Unable to identify the exact collection area from GPS.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // GPS SEARCH DATA
  //
  // House numbers are not used for matching.
  // Street / taman / landmark names are used instead.
  // ============================================================

  List<String> _buildDetectedSearchNames(
    List<Placemark> placemarks,
  ) {
    final names = <String>{};

    for (final place in placemarks) {
      final values = <String?>[
        place.name,
        place.street,
        place.thoroughfare,
        place.subThoroughfare,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ];

      for (final value in values) {
        if (value == null) {
          continue;
        }

        final text = value.trim();

        if (_isUsefulTextForAreaMatching(text)) {
          names.add(text);
        }
      }

      final street = _firstUsefulText(
        [
          place.street,
          place.thoroughfare,
        ],
        allowKampar: false,
      );

      final subLocality = _firstUsefulText(
        [place.subLocality],
        allowKampar: false,
      );

      final locality = _firstUsefulText(
        [place.locality],
        allowKampar: true,
      );

      if (street.isNotEmpty && subLocality.isNotEmpty) {
        names.add('$street $subLocality');
      }

      if (street.isNotEmpty && locality.isNotEmpty) {
        names.add('$street $locality');
      }

      if (subLocality.isNotEmpty && locality.isNotEmpty) {
        names.add('$subLocality $locality');
      }
    }

    return names.toList();
  }

  bool _isUsefulTextForAreaMatching(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return false;
    }

    // Ignore house numbers / numeric-only values.
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return false;
    }

    const ignored = <String>{
      'malaysia',
      'perak',
      'perak darul ridzuan',
      'kampar',
      'daerah kampar',
      'kampar district',
      'ipoh',
      'kinta',
      'daerah kinta',
      'kinta district',
    };

    return !ignored.contains(text.toLowerCase());
  }

  // ============================================================
  // READABLE ADDRESS
  //
  // A house number may be shown to the user, but only together
  // with useful street / locality information.
  // ============================================================

  String _buildReadableDetectedAddress(
    List<Placemark> placemarks,
  ) {
    for (final place in placemarks) {
      final parts = <String>[];

      final rawName = (place.name ?? '').trim();

      final street = _firstUsefulText(
        [
          place.street,
          place.thoroughfare,
        ],
        allowKampar: false,
      );

      final subLocality = _firstUsefulText(
        [place.subLocality],
        allowKampar: false,
      );

      final locality = _firstUsefulText(
        [
          place.locality,
          place.subAdministrativeArea,
        ],
        allowKampar: true,
      );

      final state = _firstUsefulText(
        [place.administrativeArea],
        allowKampar: true,
      );

      if (_looksLikeHouseNumber(rawName) &&
          street.isNotEmpty) {
        parts.add(rawName);
      } else if (_isUsefulReadableText(rawName) &&
          !_sameText(rawName, street) &&
          !_sameText(rawName, subLocality) &&
          !_sameText(rawName, locality)) {
        parts.add(rawName);
      }

      if (street.isNotEmpty) {
        parts.add(street);
      }

      if (subLocality.isNotEmpty &&
          !_containsSamePart(parts, subLocality)) {
        parts.add(subLocality);
      }

      if (locality.isNotEmpty &&
          !_containsSamePart(parts, locality)) {
        parts.add(locality);
      }

      if (state.isNotEmpty &&
          !_containsSamePart(parts, state)) {
        parts.add(state);
      }

      final cleaned = _uniqueParts(parts);

      if (cleaned.isNotEmpty) {
        return cleaned.join(', ');
      }
    }

    return '';
  }

  String _firstUsefulText(
    List<String?> values, {
    required bool allowKampar,
  }) {
    for (final value in values) {
      final text = value?.trim() ?? '';

      if (text.isEmpty) {
        continue;
      }

      if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
        continue;
      }

      final lower = text.toLowerCase();

      if (lower == 'malaysia' ||
          lower == 'perak darul ridzuan') {
        continue;
      }

      if (!allowKampar &&
          (lower == 'kampar' ||
              lower == 'daerah kampar' ||
              lower == 'kampar district' ||
              lower == 'ipoh' ||
              lower == 'kinta' ||
              lower == 'daerah kinta' ||
              lower == 'kinta district')) {
        continue;
      }

      return text;
    }

    return '';
  }

  bool _isUsefulReadableText(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return false;
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return false;
    }

    const ignored = <String>{
      'malaysia',
      'perak darul ridzuan',
      'kampar district',
      'daerah kampar',
    };

    return !ignored.contains(text.toLowerCase());
  }

  bool _looksLikeHouseNumber(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return false;
    }

    return RegExp(
      r'^\d+[A-Za-z]?(?:[-/]\d+[A-Za-z]?)?$',
    ).hasMatch(text);
  }

  bool _sameText(String a, String b) {
    return a.trim().toLowerCase() ==
        b.trim().toLowerCase();
  }

  bool _containsSamePart(
    List<String> parts,
    String value,
  ) {
    final lower = value.trim().toLowerCase();

    return parts.any(
      (part) => part.trim().toLowerCase() == lower,
    );
  }

  List<String> _uniqueParts(List<String> parts) {
    final result = <String>[];
    final seen = <String>{};

    for (final part in parts) {
      final text = part.trim();

      if (text.isEmpty) {
        continue;
      }

      if (seen.add(text.toLowerCase())) {
        result.add(text);
      }
    }

    return result;
  }

  // ============================================================
  // DATE / TIME
  // ============================================================

  String _getDayName(int day) {
    switch (day) {
      case DateTime.monday:
        return 'Monday';

      case DateTime.tuesday:
        return 'Tuesday';

      case DateTime.wednesday:
        return 'Wednesday';

      case DateTime.thursday:
        return 'Thursday';

      case DateTime.friday:
        return 'Friday';

      case DateTime.saturday:
        return 'Saturday';

      case DateTime.sunday:
        return 'Sunday';

      default:
        return 'Unknown';
    }
  }

  String _formatTime(
    int hour,
    int minute,
  ) {
    return TimeOfDay(
      hour: hour,
      minute: minute,
    ).format(context);
  }

  DateTime _createCollectionStart(
    CollectionSchedule schedule,
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      schedule.startHour,
      schedule.startMinute,
    );
  }

  DateTime _getCollectionEnd(
    CollectionSchedule schedule,
    DateTime start,
  ) {
    DateTime end = DateTime(
      start.year,
      start.month,
      start.day,
      schedule.endHour,
      schedule.endMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(
        const Duration(days: 1),
      );
    }

    return end;
  }

  bool _isCollectionInProgress(
    CollectionSchedule schedule,
  ) {
    final now = DateTime.now();

    if (!schedule.collectsOnDay(now.weekday)) {
      return false;
    }

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    );

    final end = _getCollectionEnd(
      schedule,
      start,
    );

    return !now.isBefore(start) &&
        !now.isAfter(end);
  }

  DateTime? _getNextCollectionStart(
    CollectionSchedule schedule, {
    CollectionEvent? todayEvent,
  }) {
    if (schedule.daysOfWeek.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // If today's real collection has already reached a final state,
    // today's schedule is no longer the "next" collection.
    final todayFinished =
        todayEvent?.isCollected == true ||
        todayEvent?.isMissed == true;

    for (int offset = 0; offset <= 7; offset++) {
      final date = today.add(
        Duration(days: offset),
      );

      if (!schedule.collectsOnDay(date.weekday)) {
        continue;
      }

      if (offset == 0 && todayFinished) {
        continue;
      }

      final start = _createCollectionStart(
        schedule,
        date,
      );

      final end = _getCollectionEnd(
        schedule,
        start,
      );

      // If today's official collection window has already ended,
      // move to the next scheduled collection day.
      if (offset == 0 && now.isAfter(end)) {
        continue;
      }

      return start;
    }

    return null;
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${_getDayName(date.weekday)}, '
        '${date.day} ${months[date.month - 1]}';
  }

  String _formatSourceDate(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value);

      const months = <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${date.day} '
          '${months[date.month - 1]} '
          '${date.year}';
    } catch (_) {
      return value;
    }
  }

  String _formatEventTime(DateTime? date) {
    if (date == null) {
      return '';
    }

    return TimeOfDay.fromDateTime(
      date.toLocal(),
    ).format(context);
  }

  bool _isSameCalendarDay(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _getCollectionLabel(
    CollectionSchedule schedule,
    DateTime collectionDate,
  ) {
    final now = DateTime.now();

    if (_isSameCalendarDay(
          collectionDate,
          now,
        ) &&
        _isCollectionInProgress(schedule)) {
      return 'Collection window active';
    }

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final collectionDay = DateTime(
      collectionDate.year,
      collectionDate.month,
      collectionDate.day,
    );

    final difference =
        collectionDay.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Tomorrow';
    }

    return 'In $difference days';
  }

  // ============================================================
  // TODAY STATUS
  //
  // Priority:
  // 1. Actual collector event from Firestore
  // 2. Official schedule window as fallback
  // ============================================================

  _TodayCollectionStatus _getTodayCollectionStatus(
    CollectionSchedule schedule,
    CollectionEvent? event,
  ) {
    final now = DateTime.now();

    // ==========================================================
    // ACTUAL COLLECTOR STATUS TAKES PRIORITY
    // ==========================================================

    if (event != null) {
      if (event.isCollected) {
        final collectedTime =
            _formatEventTime(event.collectedAt);

        return _TodayCollectionStatus(
          type: _TodayCollectionStatusType.collected,
          title: 'Collected today',
          message: collectedTime.isEmpty
              ? 'Today\'s waste collection has been completed.'
              : 'Collection completed at $collectedTime.',
          icon: Icons.check_circle_outline_rounded,
        );
      }

      if (event.isInProgress) {
        final startedTime =
            _formatEventTime(event.startedAt);

        final start = DateTime(
          now.year,
          now.month,
          now.day,
          schedule.startHour,
          schedule.startMinute,
        );

        final end = _getCollectionEnd(
          schedule,
          start,
        );

        final windowEnded = now.isAfter(end);

        String message;

        if (windowEnded) {
          message = startedTime.isEmpty
              ? 'The scheduled window has ended, but collection is still marked as in progress.'
              : 'Started at $startedTime. The scheduled window has ended, but collection is still in progress.';
        } else {
          message = startedTime.isEmpty
              ? 'The collection vehicle is currently servicing this area.'
              : 'Started at $startedTime. The collection vehicle is currently servicing this area.';
        }

        return _TodayCollectionStatus(
          type: _TodayCollectionStatusType.inProgress,
          title: 'Collection in progress',
          message: message,
          icon: Icons.local_shipping_outlined,
        );
      }

      if (event.isMissed) {
        return const _TodayCollectionStatus(
          type: _TodayCollectionStatusType.missed,
          title: 'Collection missed today',
          message:
              'The collector marked today\'s scheduled collection as missed.',
          icon: Icons.error_outline_rounded,
        );
      }

      // A pending event still falls back to the official schedule.
    }

    // ==========================================================
    // OFFICIAL SCHEDULE FALLBACK
    // ==========================================================

    if (!schedule.collectsOnDay(now.weekday)) {
      return const _TodayCollectionStatus(
        type: _TodayCollectionStatusType.notScheduled,
        title: 'No collection scheduled today',
        message: 'See the next scheduled collection above.',
        icon: Icons.event_busy_outlined,
      );
    }

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    );

    final end = _getCollectionEnd(
      schedule,
      start,
    );

    if (now.isBefore(start)) {
      return _TodayCollectionStatus(
        type: _TodayCollectionStatusType.upcoming,
        title: 'Scheduled later today',
        message:
            'Collection window starts at '
            '${_formatTime(schedule.startHour, schedule.startMinute)}.',
        icon: Icons.schedule_rounded,
      );
    }

    if (!now.isAfter(end)) {
      return _TodayCollectionStatus(
        type: _TodayCollectionStatusType.active,
        title: 'Collection window is active',
        message:
            'Vehicle may arrive any time before '
            '${_formatTime(schedule.endHour, schedule.endMinute)}.',
        icon: Icons.local_shipping_outlined,
      );
    }

    return _TodayCollectionStatus(
      type: _TodayCollectionStatusType.ended,
      title: 'Today\'s window has ended',
      message:
          'Window ended at '
          '${_formatTime(schedule.endHour, schedule.endMinute)}. '
          'No completed collection has been confirmed yet.',
      icon: Icons.history_rounded,
    );
  }

  // ============================================================
  // AREA SELECTOR
  // ============================================================

  String _areaSelectorMeta(CollectionArea area) {
    if (area.localAuthorityId == 'mbi_ipoh') {
      return 'MBI service zone • ${area.district}, ${area.state}';
    }

    return '${area.zoneName} • ${area.district}, ${area.state}';
  }

  String _areaRouteLabel(CollectionArea area) {
    if (area.localAuthorityId == 'mbi_ipoh') {
      return 'MBI • ${area.zoneArea}';
    }

    return '${area.zoneName} • ${area.zoneArea}';
  }

  Widget _buildAreaSelector() {
    final area = _selectedArea;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _openAreaPicker,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 76,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  area == null
                      ? Icons.search_rounded
                      : Icons.location_on_outlined,
                  color: Colors.green.shade700,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: area == null
                    ? Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search collection area',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Search a taman, housing area or landmark',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            area.areaName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _areaSelectorMeta(area),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 28,
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseMyLocationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDetectingLocation
            ? null
            : _detectAndSelectArea,
        icon: _isDetectingLocation
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.my_location_rounded,
              ),
        label: Text(
          _isDetectingLocation
              ? 'Detecting Location...'
              : 'Use My Location',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green.shade700,
          side: BorderSide(
            color: Colors.green.shade200,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // COMPACT LOCATION RESULT
  // ============================================================

  Widget _buildLocationMessage() {
    if (_locationMessage.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lower = _locationMessage.toLowerCase();

    final warning =
        lower.contains('outside') ||
        lower.contains('denied') ||
        lower.contains('disabled') ||
        lower.contains('not found') ||
        lower.contains('unable') ||
        lower.contains('could not');

    final color = warning
        ? Colors.orange.shade700
        : Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        10,
        4,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: color,
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Text(
              _locationMessage,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PUBLISHED FREQUENCY ONLY
  //
  // Used for an authority such as MBI where the public source confirms the
  // service frequency but does not publish which recurring weekday pattern
  // applies to every locality. We show the verified information without
  // inventing an exact next-collection date.
  // ============================================================

  Widget _buildPublishedFrequencyCard(
    CollectionArea area,
    CollectionSchedule schedule,
  ) {
    final note = schedule.scheduleNote.trim().isNotEmpty
        ? schedule.scheduleNote.trim()
        : 'The collection frequency for this area is available, while the '
            'exact locality weekday pattern is still being confirmed.';

    final isVariableThreeTimes =
        schedule.scheduleType.toLowerCase() ==
            'three_times_weekly_variable';

    final startTime = _formatTime(
      schedule.startHour,
      schedule.startMinute,
    );
    final endTime = _formatTime(
      schedule.endHour,
      schedule.endMinute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use the SAME hero-card visual language as the exact Kampar schedule.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF35C76F),
                Color(0xFF26A65B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.18),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 9),
                  Text(
                    'Collection Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const Text(
                'Collection frequency',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                isVariableThreeTimes
                    ? '3 times weekly'
                    : schedule.scheduleDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 13),

              _buildMainCardInfoRow(
                icon: Icons.access_time_rounded,
                text: '$startTime - $endTime',
              ),

              const SizedBox(height: 8),

              _buildMainCardInfoRow(
                icon: Icons.event_repeat_rounded,
                text: isVariableThreeTimes
                    ? '3 times weekly'
                    : schedule.scheduleDisplayName,
              ),

              const SizedBox(height: 16),

              Divider(
                color: Colors.white.withOpacity(0.25),
                height: 1,
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Status',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Collection pattern available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          note,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _buildAreaRouteLabel(area),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isVariableThreeTimes) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: 19,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This area is using an older schedule record. Refresh the collection-area data to load the assigned recurring days.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPatternChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD2EFDD),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF168447),
        ),
      ),
    );
  }

  Widget _buildServiceCapability({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFE1F1E7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF1D9F55),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF31443A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.3,
              height: 1.15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPossiblePatternCard({
    required String title,
    required String subtitle,
    required List<String> days,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9F0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFF1D9F55),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: days
                .map(
                  (day) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF178447),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _buildAreaRouteLabel(CollectionArea area) {
    final parts = <String>[
      area.zoneName,
      area.district,
      area.zoneArea,
    ].where((value) => value.trim().isNotEmpty).toList();

    return parts.join(' • ');
  }

  // ============================================================
  // MAIN CARD
  //
  // Next collection + today's status + zone are consolidated here.
  // ============================================================

  Widget _buildMainCollectionCard(
    CollectionArea area,
    CollectionSchedule schedule,
    CollectionEvent? todayEvent,
  ) {
    final startDate =
        _getNextCollectionStart(
      schedule,
      todayEvent: todayEvent,
    );

    if (startDate == null) {
      return const SizedBox.shrink();
    }

    final endDate = _getCollectionEnd(
      schedule,
      startDate,
    );

    final todayStatus =
        _getTodayCollectionStatus(
      schedule,
      todayEvent,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF35C76F),
            Color(0xFF26A65B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.18),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 9),
              Text(
                'Next Collection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            _getCollectionLabel(
              schedule,
              startDate,
            ),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _formatDate(startDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 13),

          _buildMainCardInfoRow(
            icon: Icons.access_time_rounded,
            text:
                '${_formatTime(startDate.hour, startDate.minute)}'
                ' - '
                '${_formatTime(endDate.hour, endDate.minute)}',
          ),

          const SizedBox(height: 8),

          _buildMainCardInfoRow(
            icon: Icons.event_repeat_rounded,
            text: schedule.scheduleDisplayName,
          ),

          const SizedBox(height: 16),

          Divider(
            color: Colors.white.withOpacity(0.25),
            height: 1,
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  todayStatus.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      todayStatus.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      todayStatus.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  color: Colors.white,
                  size: 16,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    _areaRouteLabel(area),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCardInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ONE WEEKLY SCHEDULE CARD
  // ============================================================

  Widget _buildWeeklyScheduleSection(
    CollectionSchedule schedule,
  ) {
    final days =
        List<int>.from(schedule.daysOfWeek)..sort();

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Schedule',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int index = 0;
                  index < days.length;
                  index++) ...[
                _buildWeeklyDayRow(
                  schedule: schedule,
                  dayOfWeek: days[index],
                  isToday: days[index] == now.weekday,
                ),
                if (index != days.length - 1)
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDayRow({
    required CollectionSchedule schedule,
    required int dayOfWeek,
    required bool isToday,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 13,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isToday
                  ? Colors.green.shade100
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: Colors.green.shade700,
              size: 18,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getDayName(dayOfWeek),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    if (isToday) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                Text(
                  '${_formatTime(schedule.startHour, schedule.startMinute)}'
                  ' - '
                  '${_formatTime(schedule.endHour, schedule.endMinute)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIMPLE FOOTER - NO EXTRA CARD
  // ============================================================

  Widget _buildScheduleFooter(
    CollectionArea area,
    CollectionSchedule schedule,
  ) {
    final sourceDate =
        _formatSourceDate(schedule.sourceUpdatedDate);

    final officialFrequency =
        schedule.officialServiceFrequency.trim().isNotEmpty
            ? schedule.officialServiceFrequency.trim()
            : schedule.scheduleDisplayName;

    final basisColor = Colors.green.shade700;
    final basisBackground = const Color(0xFFF0FAF4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.green.shade700,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Schedule Information',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _buildScheduleDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Area / zone',
            value: '${area.areaName} • ${area.zoneName}',
          ),
          _buildScheduleDetailRow(
            icon: Icons.account_balance_outlined,
            label: 'Local authority',
            value: schedule.localAuthorityName,
          ),
          _buildScheduleDetailRow(
            icon: Icons.delete_outline_rounded,
            label: 'Service',
            value: schedule.serviceType,
          ),
          _buildScheduleDetailRow(
            icon: Icons.event_repeat_rounded,
            label: 'Collection days',
            value: schedule.scheduleDisplayName,
          ),
          _buildScheduleDetailRow(
            icon: Icons.access_time_rounded,
            label: 'Operating hours',
            value:
                '${_formatTime(schedule.startHour, schedule.startMinute)} - '
                '${_formatTime(schedule.endHour, schedule.endMinute)}',
          ),
          _buildScheduleDetailRow(
            icon: Icons.fact_check_outlined,
            label: 'Collection frequency',
            value: officialFrequency,
          ),

          const SizedBox(height: 4),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: basisBackground,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: basisColor.withOpacity(0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: basisColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collection service',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: basisColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Waste collection for this area follows the recurring days and operating hours shown above. Please keep waste ready before the collection period begins.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (sourceDate.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.update_rounded,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Service information updated: $sourceDate',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  Widget _buildScheduleDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATES
  // ============================================================

  Widget _buildChooseAreaState() {
    return ListView(
      padding: const EdgeInsets.only(
        top: 55,
        bottom: 120,
      ),
      children: [
        Icon(
          Icons.location_searching_rounded,
          size: 55,
          color: Colors.green.shade300,
        ),

        const SizedBox(height: 16),

        const Text(
          'Choose Your Collection Area',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 7),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Text(
            'Search your taman, housing area or landmark '
            'to view its collection schedule.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.grey.shade600,
            ),
          ),
        ),

        const SizedBox(height: 18),

        Center(
          child: FilledButton.icon(
            onPressed: _openAreaPicker,
            icon: const Icon(
              Icons.search_rounded,
            ),
            label: const Text(
              'Search Collection Area',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoAreasPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'No Collection Areas Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active Kampar or Ipoh collection areas are currently available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSchedulePage(
    CollectionArea area,
  ) {
    return Center(
      child: Text(
        'No active schedule found for ${area.areaName}.',
        textAlign: TextAlign.center,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),
      body: SafeArea(
        child: _isLoadingAreas
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : _areas.isEmpty
                ? _buildNoAreasPage()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Collection Schedule',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight:
                                FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Check waste collection schedules for supported areas '
                          'in Kampar and Ipoh, Perak.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color:
                                Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 22),

                        Text(
                          'Collection Area',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 8),

                        _buildAreaSelector(),

                        const SizedBox(height: 10),

                        _buildUseMyLocationButton(),

                        _buildLocationMessage(),

                        const SizedBox(height: 15),

                        Expanded(
                          child: _selectedArea == null
                              ? _buildChooseAreaState()
                              : StreamBuilder<
                                  CollectionSchedule?>(
                                  stream: _scheduleService
                                      .watchScheduleForArea(
                                    _selectedArea!,
                                  ),
                                  builder: (
                                    context,
                                    snapshot,
                                  ) {
                                    if (snapshot
                                            .connectionState ==
                                        ConnectionState
                                            .waiting) {
                                      return const Center(
                                        child:
                                            CircularProgressIndicator(),
                                      );
                                    }

                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Failed to load schedule.\n${snapshot.error}',
                                          textAlign:
                                              TextAlign.center,
                                        ),
                                      );
                                    }

                                    final schedule =
                                        snapshot.data;

                                    if (schedule == null) {
                                      return _buildNoSchedulePage(
                                        _selectedArea!,
                                      );
                                    }

                                    return StreamBuilder<
                                        CollectionEvent?>(
                                      stream: _eventService
                                          .watchTodayEvent(
                                        _selectedArea!,
                                      ),
                                      builder: (
                                        context,
                                        eventSnapshot,
                                      ) {
                                        // If the event is still loading, the
                                        // official schedule is shown first.
                                        // Once Firestore returns an event,
                                        // the status updates automatically.
                                        final todayEvent =
                                            eventSnapshot.data;

                                        return ListView(
                                          padding:
                                              const EdgeInsets.only(
                                            top: 2,
                                            bottom: 135,
                                          ),
                                          children: [
                                            if (schedule.daysOfWeek.isEmpty)
                                              _buildPublishedFrequencyCard(
                                                _selectedArea!,
                                                schedule,
                                              )
                                            else ...[
                                              _buildMainCollectionCard(
                                                _selectedArea!,
                                                schedule,
                                                todayEvent,
                                              ),
                                              const SizedBox(
                                                height: 26,
                                              ),
                                              _buildWeeklyScheduleSection(
                                                schedule,
                                              ),
                                            ],

                                            const SizedBox(
                                              height: 18,
                                            ),

                                            _buildScheduleFooter(
                                              _selectedArea!,
                                              schedule,
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ============================================================================
// SEARCHABLE AREA PICKER
// ============================================================================

class _AreaPickerSheet extends StatefulWidget {
  final List<CollectionArea> areas;
  final String? currentAreaId;
  final CollectionScheduleService scheduleService;

  const _AreaPickerSheet({
    required this.areas,
    required this.currentAreaId,
    required this.scheduleService,
  });

  @override
  State<_AreaPickerSheet> createState() =>
      _AreaPickerSheetState();
}

class _AreaPickerSheetState
    extends State<_AreaPickerSheet> {
  final TextEditingController _searchController =
      TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results =
        widget.scheduleService.filterAreas(
      widget.areas,
      _query,
    );

    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height:
          MediaQuery.of(context).size.height * 0.82,
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Collection Area',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),

              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: InputDecoration(
              hintText:
                  'Search taman, area or landmark...',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();

                        setState(() {
                          _query = '';
                        });
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide(
                  color:
                      Colors.green.shade400,
                  width: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 9),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.trim().isEmpty
                  ? '${results.length} supported areas'
                  : '${results.length} result${results.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.grey.shade600,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No matching collection area.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(
                      height: 8,
                    ),
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final area =
                          results[index];

                      final selected =
                          area.areaId ==
                              widget.currentAreaId;

                      return Material(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(
                              context,
                              area,
                            );
                          },
                          borderRadius:
                              BorderRadius.circular(16),
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                              14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              border: Border.all(
                                color: selected
                                    ? Colors
                                        .green.shade300
                                    : Colors
                                        .grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration:
                                      BoxDecoration(
                                    color: Colors
                                        .green.shade50,
                                    borderRadius:
                                        BorderRadius
                                            .circular(12),
                                  ),
                                  child: Icon(
                                    Icons
                                        .location_on_outlined,
                                    color: Colors
                                        .green.shade700,
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
                                        area.areaName,
                                        style:
                                            const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight:
                                              FontWeight
                                                  .w700,
                                          color:
                                              Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        area.localAuthorityId == 'mbi_ipoh'
                                            ? 'MBI service zone • ${area.district}, ${area.state}'
                                            : '${area.zoneName} • ${area.zoneArea}',
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors
                                              .grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                if (selected)
                                  Icon(
                                    Icons
                                        .check_circle_rounded,
                                    color: Colors
                                        .green.shade600,
                                    size: 21,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TODAY STATUS MODEL
// ============================================================================

enum _TodayCollectionStatusType {
  upcoming,
  active,
  ended,
  notScheduled,
  inProgress,
  collected,
  missed,
}

class _TodayCollectionStatus {
  final _TodayCollectionStatusType type;
  final String title;
  final String message;
  final IconData icon;

  const _TodayCollectionStatus({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
  });
}
