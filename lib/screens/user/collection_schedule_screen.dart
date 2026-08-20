import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/collection_schedule.dart';
import '../../services/collection_schedule_service.dart';

class CollectionScheduleScreen extends StatefulWidget {
  const CollectionScheduleScreen({super.key});

  @override
  State<CollectionScheduleScreen> createState() =>
      _CollectionScheduleScreenState();
}

class _CollectionScheduleScreenState extends State<CollectionScheduleScreen>
    with AutomaticKeepAliveClientMixin {
  final CollectionScheduleService _scheduleService =
      CollectionScheduleService();

  List<String> _areas = [];

  String? _selectedArea;

  bool _isLoadingAreas = true;
  bool _isDetectingLocation = false;

  bool _userChangedArea = false;

  String _locationMessage = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _loadAreas();
  }

  // ============================================================
  // LOAD AVAILABLE AREAS
  // ============================================================

  Future<void> _loadAreas() async {
    try {
      final areas = await _scheduleService.getAvailableAreas();

      if (!mounted) return;

      setState(() {
        _areas = areas;

        if (_areas.isNotEmpty) {
          _selectedArea = _areas.first;
        }

        _isLoadingAreas = false;
      });

      if (_areas.isNotEmpty) {
        await _detectAndSelectArea(showMessage: false, forceSelection: false);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingAreas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load collection areas: $e')),
      );
    }
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _detectAndSelectArea({
    required bool showMessage,
    required bool forceSelection,
  }) async {
    if (_isDetectingLocation) return;

    setState(() {
      _isDetectingLocation = true;

      if (showMessage) {
        _locationMessage = 'Detecting your current area...';
      }
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location services are disabled. Please enable GPS.';
        });

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location permission was denied. You can still select an area manually.';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Location permission is permanently denied. Please enable it in your phone settings.';
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
          _locationMessage = 'Unable to identify your current collection area.';
        });

        return;
      }

      final place = placemarks.first;

      final detectedState = (place.administrativeArea ?? '').trim();

      // Only Perak schedules are supported.
      if (!detectedState.toLowerCase().contains('perak')) {
        if (!mounted) return;

        setState(() {
          _locationMessage =
              'Your current location is outside Perak. Please select a Perak area manually.';
        });

        return;
      }

      // Collect all useful names returned by GPS/geocoding.
      final detectedNames = <String>[
        place.name ?? '',
        place.street ?? '',
        place.subLocality ?? '',
        place.locality ?? '',
        place.subAdministrativeArea ?? '',
        place.administrativeArea ?? '',
      ].where((name) => name.trim().isNotEmpty).toList();

      // Firebase decides which main schedule area the locality belongs to.
      final matchedArea = await _scheduleService.findScheduleAreaFromLocation(
        detectedNames,
      );

      if (!mounted) return;

      final detectedLocationName = _getReadableDetectedArea(place);

      if (matchedArea != null && _areas.contains(matchedArea)) {
        if (forceSelection || !_userChangedArea) {
          setState(() {
            _selectedArea = matchedArea;

            _locationMessage = detectedLocationName.isNotEmpty
                ? 'Detected: $detectedLocationName → $matchedArea collection area'
                : 'Your current collection area: $matchedArea, Perak';
          });
        } else {
          setState(() {
            _locationMessage = detectedLocationName.isNotEmpty
                ? 'Detected location: $detectedLocationName ($matchedArea area)'
                : 'Detected collection area: $matchedArea';
          });
        }
      } else {
        setState(() {
          _locationMessage = detectedLocationName.isNotEmpty
              ? 'Your location was detected as $detectedLocationName, but no matching collection schedule area is available yet.'
              : 'Your location is within Perak, but no matching collection schedule area is available yet.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationMessage =
            'Unable to detect your location. You can select an area manually.';
      });

      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // DISPLAY DETECTED LOCALITY
  // ============================================================

  String _getReadableDetectedArea(Placemark place) {
    final values = [
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.name,
    ];

    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  // ============================================================
  // DAY
  // ============================================================

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';

      case 2:
        return 'Tuesday';

      case 3:
        return 'Wednesday';

      case 4:
        return 'Thursday';

      case 5:
        return 'Friday';

      case 6:
        return 'Saturday';

      case 7:
        return 'Sunday';

      default:
        return 'Unknown';
    }
  }

  // ============================================================
  // TIME
  // ============================================================

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);

    return time.format(context);
  }

  // ============================================================
  // COLLECTION START
  // ============================================================

  DateTime _getCollectionStart(CollectionSchedule schedule) {
    final now = DateTime.now();

    int daysUntil = schedule.dayOfWeek - now.weekday;

    if (daysUntil < 0) {
      daysUntil += 7;
    }

    DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    ).add(Duration(days: daysUntil));

    DateTime end = DateTime(
      start.year,
      start.month,
      start.day,
      schedule.endHour,
      schedule.endMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    if (daysUntil == 0 && now.isAfter(end)) {
      start = start.add(const Duration(days: 7));
    }

    return start;
  }

  // ============================================================
  // COLLECTION END
  // ============================================================

  DateTime _getCollectionEnd(CollectionSchedule schedule, DateTime start) {
    DateTime end = DateTime(
      start.year,
      start.month,
      start.day,
      schedule.endHour,
      schedule.endMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    return end;
  }

  // ============================================================
  // COLLECTION CURRENTLY RUNNING
  // ============================================================

  bool _isCollectionInProgress(CollectionSchedule schedule) {
    final now = DateTime.now();

    if (schedule.dayOfWeek != now.weekday) {
      return false;
    }

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    );

    DateTime end = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.endHour,
      schedule.endMinute,
    );

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    return !now.isBefore(start) && !now.isAfter(end);
  }

  // ============================================================
  // FIND NEXT COLLECTION
  // ============================================================

  CollectionSchedule? _findNextCollection(List<CollectionSchedule> schedules) {
    if (schedules.isEmpty) {
      return null;
    }

    for (final schedule in schedules) {
      if (_isCollectionInProgress(schedule)) {
        return schedule;
      }
    }

    final sorted = List<CollectionSchedule>.from(schedules);

    sorted.sort((a, b) {
      final dateA = _getCollectionStart(a);
      final dateB = _getCollectionStart(b);

      return dateA.compareTo(dateB);
    });

    return sorted.first;
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    const months = [
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

  String _getCollectionLabel(CollectionSchedule schedule, DateTime date) {
    if (_isCollectionInProgress(schedule)) {
      return 'Collection in progress';
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final collectionDay = DateTime(date.year, date.month, date.day);

    final difference = collectionDay.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    }

    if (difference == 1) {
      return 'Tomorrow';
    }

    return 'In $difference days';
  }

  // ============================================================
  // AREA SELECTOR
  // ============================================================

  Widget _buildAreaSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedArea,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          borderRadius: BorderRadius.circular(18),
          dropdownColor: Colors.white,
          elevation: 8,
          menuMaxHeight: 350,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey.shade700,
            size: 28,
          ),
          selectedItemBuilder: (context) {
            return _areas.map((area) {
              return Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Colors.green.shade600,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$area, Perak',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              );
            }).toList();
          },
          items: _areas.map((area) {
            final bool isSelected = area == _selectedArea;

            return DropdownMenuItem<String>(
              value: area,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.shade100
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Colors.green.shade600,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$area, Perak',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green.shade600,
                        size: 21,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedArea = value;
              _userChangedArea = true;
              _locationMessage = '';
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // USE MY LOCATION
  // ============================================================

  Widget _buildUseMyLocationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDetectingLocation
            ? null
            : () {
                _detectAndSelectArea(showMessage: true, forceSelection: true);
              },
        icon: _isDetectingLocation
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location_rounded),
        label: Text(
          _isDetectingLocation ? 'Detecting Location...' : 'Use My Location',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green.shade700,
          side: BorderSide(color: Colors.green.shade200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION RESULT MESSAGE
  // ============================================================

  Widget _buildLocationMessage() {
    if (_locationMessage.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lower = _locationMessage.toLowerCase();

    final bool warning =
        lower.contains('outside') ||
        lower.contains('denied') ||
        lower.contains('disabled') ||
        lower.contains('no matching') ||
        lower.contains('unable');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warning ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            warning
                ? Icons.info_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: warning ? Colors.orange.shade700 : Colors.green.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _locationMessage,
              style: TextStyle(
                color: warning ? Colors.orange.shade800 : Colors.green.shade800,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NEXT COLLECTION
  // ============================================================

  Widget _buildNextCollectionCard(List<CollectionSchedule> schedules) {
    final schedule = _findNextCollection(schedules);

    if (schedule == null) {
      return const SizedBox.shrink();
    }

    final startDate = _getCollectionStart(schedule);

    final endDate = _getCollectionEnd(schedule, startDate);

    final inProgress = _isCollectionInProgress(schedule);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF35C76F), Color(0xFF26A65B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.20),
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
                size: 25,
              ),
              SizedBox(width: 10),
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

          const SizedBox(height: 20),

          if (inProgress)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'COLLECTION IN PROGRESS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Text(
              _getCollectionLabel(schedule, startDate),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 8),

          Text(
            _formatDate(startDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                '${_formatTime(startDate.hour, startDate.minute)}'
                ' - '
                '${_formatTime(endDate.hour, endDate.minute)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  schedule.wasteType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (schedule.routeName.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.route_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    schedule.routeName,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // WEEKLY SCHEDULE
  // ============================================================

  Widget _buildScheduleCard(CollectionSchedule schedule) {
    final bool inProgress = _isCollectionInProgress(schedule);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inProgress ? Colors.green.shade300 : Colors.grey.shade200,
          width: inProgress ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              color: Colors.green.shade700,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDayName(schedule.dayOfWeek),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    if (inProgress)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'In Progress',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  '${_formatTime(schedule.startHour, schedule.startMinute)}'
                  ' - '
                  '${_formatTime(schedule.endHour, schedule.endMinute)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  schedule.wasteType,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),

                if (schedule.routeName.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    schedule.routeName,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: _isLoadingAreas
            ? const Center(child: CircularProgressIndicator())
            : _areas.isEmpty
            ? const Center(
                child: Text('No collection schedules are available.'),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Collection Schedule',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Check scheduled waste collection around Perak.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Viewing Area',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildAreaSelector(),

                    const SizedBox(height: 10),

                    _buildUseMyLocationButton(),

                    _buildLocationMessage(),

                    const SizedBox(height: 20),

                    Expanded(
                      child: StreamBuilder<List<CollectionSchedule>>(
                        stream: _scheduleService.getSchedulesByArea(
                          _selectedArea!,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Failed to load schedule.\n'
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final schedules = snapshot.data ?? [];

                          if (schedules.isEmpty) {
                            return Center(
                              child: Text(
                                'No schedule found for $_selectedArea.',
                              ),
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.only(bottom: 100),
                            children: [
                              _buildNextCollectionCard(schedules),

                              const SizedBox(height: 28),

                              const Text(
                                'Weekly Schedule',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 14),

                              ...schedules.map(_buildScheduleCard),
                            ],
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
