import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

import '../../models/waste_report.dart';
import '../../services/report_chat_service.dart';
import '../shared/report_chat_screen.dart';

class ReportDetailScreen extends StatefulWidget {
  final WasteReport report;
  final bool isAdmin;
  final Function(String)? onStatusChanged;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.isAdmin = false,
    this.onStatusChanged,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final ReportChatService _chatService = ReportChatService();

  static const String _googleApiKey = 'AIzaSyBHoNEbIfc0lqJ74D70b26P8_vxL5DSw9s';

  late String _title;
  late String _description;
  late String _wasteType;
  late String _location;
  late String _area;
  late String _status;
  late String _priority;
  late String _completionImageUrl;
  late double _latitude;
  late double _longitude;

  final List<String> _defaultWasteTypes = const [
    'General Waste',
    'Plastic Waste',
    'Illegal Dumping',
    'Bulky Waste',
    'Hazardous Waste',
    'Plastic',
    'Paper',
    'Glass',
    'Metal',
    'Organic Waste',
    'Electronic Waste',
    'Others',
  ];

  List<String> get _wasteTypes {
    final uniqueTypes = <String>[];

    if (_wasteType.trim().isNotEmpty) {
      uniqueTypes.add(_wasteType);
    }

    for (final type in _defaultWasteTypes) {
      if (!uniqueTypes.contains(type)) {
        uniqueTypes.add(type);
      }
    }

    return uniqueTypes;
  }

  @override
  void initState() {
    super.initState();

    _title = widget.report.title;
    _description = widget.report.description;
    _wasteType = widget.report.wasteType;
    _location = widget.report.location;
    _area = widget.report.area;
    _status = widget.report.status;
    _priority = widget.report.priority;
    _completionImageUrl = widget.report.completionImageUrl;
    _latitude = widget.report.latitude;
    _longitude = widget.report.longitude;
  }

  void _goBackFromDetail() {
    Navigator.pop(context, true);
  }

  String _displayStatus(String status) {
    if (!widget.isAdmin && status == 'Completion Submitted') {
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

  Color _priorityColor(String priority) {
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}  '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return '-';
  }

  bool get _canUserEditReport {
    return !widget.isAdmin && _status == 'Pending';
  }

  Future<bool> _handleWillPop() async {
    _goBackFromDetail();
    return false;
  }

  String _buildAreaKey(Placemark place) {
    final parts = <String>[
      if ((place.thoroughfare ?? '').trim().isNotEmpty)
        place.thoroughfare!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty &&
          (place.thoroughfare ?? '').trim().isEmpty)
        place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
    ];

    final uniqueParts = <String>[];

    for (final part in parts) {
      if (!uniqueParts.contains(part)) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(', ');
  }

  Future<String> _getAreaFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return '';
      }

      final place = placemarks.first;
      final areaKey = _buildAreaKey(place);

      if (areaKey.trim().isNotEmpty) {
        return areaKey.trim();
      }

      return '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
          .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> _getStateFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return '';
      }

      return (placemarks.first.administrativeArea ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  bool _isPerakLocation({
    required String location,
    required String area,
    required String state,
  }) {
    final combined = '$location $area $state'.toLowerCase();
    return combined.contains('perak');
  }

  Future<void> _showStatusDialog(BuildContext context) async {
    String selectedStatus = _status;

    final statuses = [
      'Pending',
      'Assigned',
      'In Progress',
      'Resolved',
      'Rejected',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Update Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.green.shade600,
                    ),
                    items: statuses.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(
                          status,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                if (selectedStatus != _status) {
                  setState(() {
                    _status = selectedStatus;
                  });

                  widget.onStatusChanged?.call(selectedStatus);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditReportDialog(BuildContext context) async {
    final titleController = TextEditingController(text: _title);
    final descriptionController = TextEditingController(text: _description);
    final locationController = TextEditingController(text: _location);

    String selectedWasteType = _wasteType;
    String selectedArea = _area;
    String selectedState = '';

    // The original saved location is treated as already verified.
    // If the user changes the location text, a Google suggestion must be
    // selected again before the edit can be saved.
    String verifiedLocationText = _location.trim();

    double? selectedLatitude = _latitude;
    double? selectedLongitude = _longitude;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> updateSelectedLocation({
              required String address,
              required double lat,
              required double lng,
            }) async {
              locationController.text = address;
              locationController.selection = TextSelection.fromPosition(
                TextPosition(offset: address.length),
              );

              final newArea = await _getAreaFromCoordinates(lat, lng);
              final newState = await _getStateFromCoordinates(lat, lng);

              setDialogState(() {
                selectedLatitude = lat;
                selectedLongitude = lng;
                selectedArea = newArea.trim().isNotEmpty ? newArea : address;
                selectedState = newState;
                verifiedLocationText = address.trim();
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedWasteType,
                      decoration: InputDecoration(
                        labelText: 'Waste Type',
                        prefixIcon: const Icon(Icons.delete_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: _wasteTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedWasteType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    GooglePlaceAutoCompleteTextField(
                      textEditingController: locationController,
                      googleAPIKey: _googleApiKey,
                      debounceTime: 600,
                      isLatLngRequired: true,
                      countries: const ['my'],
                      inputDecoration: InputDecoration(
                        labelText: 'Search Location',
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      boxDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      itemClick: (prediction) async {
                        final selectedText = prediction.description ?? '';

                        final lat = double.tryParse(prediction.lat ?? '');
                        final lng = double.tryParse(prediction.lng ?? '');

                        if (lat != null && lng != null) {
                          await updateSelectedLocation(
                            address: selectedText,
                            lat: lat,
                            lng: lng,
                          );
                        } else {
                          locationController.text = selectedText;
                          locationController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: selectedText.length),
                              );

                          setDialogState(() {
                            selectedArea = selectedText;
                            selectedState = '';
                            verifiedLocationText = '';
                            selectedLatitude = null;
                            selectedLongitude = null;
                          });
                        }
                      },
                      getPlaceDetailWithLatLng: (prediction) async {
                        final selectedText = prediction.description ?? '';

                        final lat = double.tryParse(prediction.lat ?? '');
                        final lng = double.tryParse(prediction.lng ?? '');

                        if (lat != null && lng != null) {
                          await updateSelectedLocation(
                            address: selectedText,
                            lat: lat,
                            lng: lng,
                          );
                        } else if (selectedText.trim().isNotEmpty) {
                          locationController.text = selectedText;
                          locationController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: selectedText.length),
                              );

                          setDialogState(() {
                            selectedArea = selectedText;
                            selectedState = '';
                            verifiedLocationText = '';
                            selectedLatitude = null;
                            selectedLongitude = null;
                          });
                        }
                      },
                      itemBuilder: (context, index, prediction) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  prediction.description ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      seperatedBuilder: const Divider(height: 1),
                      isCrossBtnShown: false,
                      containerHorizontalPadding: 0,
                    ),

                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedArea.trim().isEmpty
                                  ? 'Area will be updated after selecting a suggested location.'
                                  : 'Detected area: $selectedArea',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Note: You can only edit reports while the status is Pending.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await Future.delayed(
                      const Duration(milliseconds: 150),
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newTitle = titleController.text.trim();
                    final newDescription = descriptionController.text.trim();
                    final newLocation = locationController.text.trim();

                    if (newTitle.isEmpty ||
                        newDescription.isEmpty ||
                        newLocation.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final newArea = selectedArea.trim().isNotEmpty
                        ? selectedArea.trim()
                        : newLocation;

                    final locationChanged =
                        newLocation != _location.trim();

                    if (locationChanged) {
                      final hasVerifiedSelection =
                          verifiedLocationText.isNotEmpty &&
                          newLocation == verifiedLocationText &&
                          selectedLatitude != null &&
                          selectedLongitude != null;

                      if (!hasVerifiedSelection) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select a suggested location before saving.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (!_isPerakLocation(
                        location: newLocation,
                        area: newArea,
                        state: selectedState,
                      )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This service only accepts waste reports within Perak.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    // Google Places autocomplete keeps an overlay/focus dependency
                    // attached to the edit dialog. If the dialog is removed immediately
                    // after tapping Save, Flutter can dispose the inherited widgets
                    // before the autocomplete overlay detaches, causing the
                    // "_dependents.isEmpty" framework assertion.
                    FocusManager.instance.primaryFocus?.unfocus();

                    await Future.delayed(
                      const Duration(milliseconds: 250),
                    );

                    if (!dialogContext.mounted) return;

                    Navigator.of(dialogContext).pop();

                    await _updateUserReport(
                      title: newTitle,
                      wasteType: selectedWasteType,
                      description: newDescription,
                      location: newLocation,
                      area: newArea,
                      latitude: selectedLatitude,
                      longitude: selectedLongitude,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
  }

  Future<void> _updateUserReport({
    required String title,
    required String wasteType,
    required String description,
    required String location,
    required String area,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final bool locationChanged = location.trim() != _location.trim();

      double? finalLatitude = latitude;
      double? finalLongitude = longitude;
      String finalArea = area.trim().isNotEmpty ? area.trim() : location.trim();

      // Always try to convert the newest address into coordinates.
      // This is because map marker uses latitude and longitude, not location text.
      try {
        final locations = await locationFromAddress(location);

        if (locations.isNotEmpty) {
          finalLatitude = locations.first.latitude;
          finalLongitude = locations.first.longitude;

          final detectedArea = await _getAreaFromCoordinates(
            finalLatitude,
            finalLongitude,
          );

          if (detectedArea.trim().isNotEmpty) {
            finalArea = detectedArea.trim();
          }
        }
      } catch (e) {
        debugPrint('Failed to geocode edited location: $e');
      }

      if (finalLatitude == null || finalLongitude == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to get the new location coordinates. Please select a location from the suggestion list.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Final safeguard: if the location was changed, verify the resolved
      // coordinates still belong to Perak before writing anything to Firestore.
      if (locationChanged) {
        final resolvedState = await _getStateFromCoordinates(
          finalLatitude,
          finalLongitude,
        );

        if (!_isPerakLocation(
          location: location,
          area: finalArea,
          state: resolvedState,
        )) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This service only accepts waste reports within Perak.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      debugPrint('SAVE REPORT LOCATION: $location');
      debugPrint('SAVE REPORT AREA: $finalArea');
      debugPrint('SAVE REPORT LATITUDE: $finalLatitude');
      debugPrint('SAVE REPORT LONGITUDE: $finalLongitude');

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update({
            'title': title,
            'wasteType': wasteType,
            'description': description,
            'location': location,
            'area': finalArea,
            'latitude': finalLatitude,
            'longitude': finalLongitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      setState(() {
        _title = title;
        _wasteType = wasteType;
        _description = description;
        _location = location;
        _area = finalArea;
        _latitude = finalLatitude!;
        _longitude = finalLongitude!;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImagePreview(
    String imageUrl, {
    String errorText = 'Unable to load photo',
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Container(
                        constraints: const BoxConstraints(
                          minHeight: 260,
                        ),
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Container(
                        height: 260,
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 52,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                errorText,
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withOpacity(0.65),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletionMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionProofSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data =
            snapshot.data?.data() ?? <String, dynamic>{};

        final liveCompletionUrl =
            data['completionImageUrl']?.toString().trim() ?? '';

        final completionUrl = liveCompletionUrl.isNotEmpty
            ? liveCompletionUrl
            : _completionImageUrl.trim();

        final collectorName =
            data['collectorName']?.toString().trim() ?? '';

        final collectorRemark =
            data['collectorRemark']?.toString().trim() ?? '';

        final completionSubmittedAt =
            data['completionSubmittedAt'];

        final completionApprovedAt =
            data['completionReviewedAt'] ??
            data['resolvedAt'] ??
            data['updatedAt'] ??
            widget.report.updatedAt;

        final liveStatus =
            data['status']?.toString().trim() ?? _status;

        // --------------------------------------------------------
        // USER: COMPLETION IS WAITING FOR ADMIN VERIFICATION
        // --------------------------------------------------------
        // Do not present an unverified collector photo as final
        // "Completion Proof". The user only sees that evidence has
        // been submitted and is currently being verified.
        if (!widget.isAdmin &&
            liveStatus == 'Completion Submitted') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 26),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.fact_check_outlined,
                      color: Colors.amber.shade800,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Completion Update',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Under Verification',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          color: Colors.amber.shade800,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The assigned collector has submitted completion '
                            'evidence. An Admin is reviewing it before this '
                            'report can be marked as Resolved.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (collectorName.isNotEmpty ||
                        completionSubmittedAt != null) ...[
                      const SizedBox(height: 16),
                      Divider(
                        color: Colors.amber.shade200,
                        height: 1,
                      ),
                      const SizedBox(height: 14),
                      _buildCompletionMetaRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Submitted by',
                        value: collectorName.isNotEmpty
                            ? collectorName
                            : 'Assigned collector',
                      ),
                      _buildCompletionMetaRow(
                        icon: Icons.upload_rounded,
                        label: 'Submitted at',
                        value: completionSubmittedAt != null
                            ? _formatTimestamp(completionSubmittedAt)
                            : '-',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        // Rejected evidence is not shown to the user as final proof.
        if (!widget.isAdmin && liveStatus != 'Resolved') {
          return const SizedBox.shrink();
        }

        // Final completion proof is shown only after Admin approval.
        if (liveStatus != 'Resolved') {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Colors.green.shade700,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'Completion Proof',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Resolved',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.shade100,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.025),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (completionUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        _showImagePreview(
                          completionUrl,
                          errorText: 'Unable to load completion photo',
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                completionUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }

                                  return Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.grey.shade400,
                                      size: 46,
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  color: Colors.black.withOpacity(0.52),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                      SizedBox(width: 7),
                                      Text(
                                        'Tap photo to view',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildCompletionMetaRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Submitted by',
                    value: collectorName.isNotEmpty
                        ? collectorName
                        : 'Assigned collector',
                  ),
                  _buildCompletionMetaRow(
                    icon: Icons.upload_rounded,
                    label: 'Submitted at',
                    value: completionSubmittedAt != null
                        ? _formatTimestamp(completionSubmittedAt)
                        : '-',
                  ),
                  _buildCompletionMetaRow(
                    icon: Icons.verified_outlined,
                    label: 'Approved at',
                    value: _formatTimestamp(completionApprovedAt),
                  ),
                  if (collectorRemark.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collector Remark',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            collectorRemark,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.grey.shade500,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This completion evidence was submitted by the '
                          'assigned collector and approved by Admin before '
                          'the report was marked as Resolved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openReportChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportChatScreen(
          reportId: widget.report.id,
          reportTitle: _title,
          reportLocation: _location,
          reportLatitude: _latitude,
          reportLongitude: _longitude,
          currentRole: 'user',
        ),
      ),
    );
  }

  Widget _buildReportChatSection() {
    if (widget.isAdmin) {
      return const SizedBox.shrink();
    }

    const primaryGreen = Color(0xFF35C76F);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = data?['status']?.toString().trim() ?? _status;
        final collectorId =
            data?['collectorId']?.toString().trim() ?? widget.report.collectorId;
        final collectorName =
            data?['collectorName']?.toString().trim() ?? widget.report.collectorName;

        final showChat = collectorId.isNotEmpty &&
            (status == 'Assigned' ||
                status == 'In Progress' ||
                status == 'Completion Submitted' ||
                status == 'Resolved');

        if (!showChat) {
          return const SizedBox.shrink();
        }

        final isReadOnly = status == 'Resolved';

        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeading(
                icon: Icons.forum_outlined,
                title: 'Report Chat',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.11),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                collectorName.isEmpty
                                    ? 'Chat with Collector'
                                    : 'Chat with $collectorName',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isReadOnly
                                    ? 'This resolved report keeps the conversation available for reference.'
                                    : 'Clarify the exact location, access point, or other report details with your assigned Collector.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<int>(
                      stream: _chatService.watchUnreadCount(widget.report.id),
                      builder: (context, unreadSnapshot) {
                        final unread = unreadSnapshot.data ?? 0;

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openReportChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  isReadOnly
                                      ? Icons.history_rounded
                                      : Icons.forum_rounded,
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: -8,
                                    top: -7,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        unread > 99 ? '99+' : '$unread',
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
                            label: Text(
                              isReadOnly
                                  ? 'View Conversation'
                                  : unread > 0
                                      ? 'Open Chat ($unread new)'
                                      : 'Open Chat',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _progressIndexForStatus(String status) {
    switch (status) {
      case 'Pending':
        return 0;
      case 'Assigned':
        return 1;
      case 'In Progress':
        return 2;
      case 'Completion Submitted':
      case 'Under Verification':
        return 3;
      case 'Resolved':
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildReportProgressSection() {
    const primaryGreen = Color(0xFF35C76F);
    final displayStatus = _displayStatus(_status);

    if (_status == 'Rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading(
            icon: Icons.route_outlined,
            title: 'Report Progress',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              children: [
                _buildProgressStep(
                  title: 'Submitted',
                  subtitle: 'Your report was submitted successfully.',
                  icon: Icons.check_rounded,
                  color: primaryGreen,
                  showLine: true,
                  lineColor: Colors.red.shade200,
                ),
                _buildProgressStep(
                  title: 'Rejected',
                  subtitle: 'The report was reviewed and rejected by Admin.',
                  icon: Icons.close_rounded,
                  color: Colors.red,
                  showLine: false,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final currentIndex = _progressIndexForStatus(displayStatus);
    const steps = <Map<String, Object>>[
      {
        'title': 'Submitted',
        'subtitle': 'Report submitted for Admin review.',
        'icon': Icons.upload_file_rounded,
      },
      {
        'title': 'Assigned',
        'subtitle': 'A Collector has been assigned.',
        'icon': Icons.assignment_ind_outlined,
      },
      {
        'title': 'In Progress',
        'subtitle': 'The Collector is handling the report.',
        'icon': Icons.local_shipping_outlined,
      },
      {
        'title': 'Under Verification',
        'subtitle': 'Completion evidence is being reviewed.',
        'icon': Icons.fact_check_outlined,
      },
      {
        'title': 'Resolved',
        'subtitle': 'Completion was approved by Admin.',
        'icon': Icons.verified_outlined,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          icon: Icons.route_outlined,
          title: 'Report Progress',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final isComplete = index < currentIndex;
              final isCurrent = index == currentIndex;
              final isFuture = index > currentIndex;

              final Color stepColor;
              final IconData stepIcon;

              if (isComplete) {
                stepColor = primaryGreen;
                stepIcon = Icons.check_rounded;
              } else if (isCurrent) {
                stepColor = _statusColor(displayStatus);
                stepIcon = step['icon']! as IconData;
              } else {
                stepColor = Colors.grey.shade400;
                stepIcon = step['icon']! as IconData;
              }

              final nextLineColor = index < currentIndex
                  ? primaryGreen
                  : Colors.grey.shade200;

              return _buildProgressStep(
                title: step['title']! as String,
                subtitle: step['subtitle']! as String,
                icon: stepIcon,
                color: stepColor,
                showLine: index != steps.length - 1,
                lineColor: nextLineColor,
                muted: isFuture,
                current: isCurrent,
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool showLine,
    Color? lineColor,
    bool muted = false,
    bool current = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(muted ? 0.08 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(muted ? 0.35 : 0.8),
                      width: current ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: color,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: lineColor ?? Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                current ? FontWeight.w800 : FontWeight.w700,
                            color: muted
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (current)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              color: color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: muted
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required IconData icon,
    required String title,
  }) {
    const primaryGreen = Color(0xFF35C76F);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: primaryGreen,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportEvidenceSection() {
    const primaryGreen = Color(0xFF35C76F);
    final imageUrl = widget.report.imageUrl.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading(
          icon: Icons.photo_outlined,
          title: 'Report Evidence',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photo submitted with this report',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.grey.shade100,
                  child: InkWell(
                    onTap: imageUrl.isEmpty
                        ? null
                        : () {
                            _showImagePreview(
                              imageUrl,
                              errorText: 'Unable to load report photo',
                            );
                          },
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: imageUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }

                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: primaryGreen,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image_outlined,
                                            size: 44,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Unable to load report photo',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    color: Colors.black.withOpacity(0.52),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 17,
                                        ),
                                        SizedBox(width: 7),
                                        Text(
                                          'Tap photo to view',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: primaryGreen.withOpacity(0.06),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 44,
                                    color: primaryGreen,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No report photo available',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRejectedNotice() {
    if (_status != 'Rejected') {
      return const SizedBox.shrink();
    }

    final reason = widget.report.adminRemark.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Rejected',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : 'This report was rejected by the administrator.',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayStatus = _displayStatus(_status);
    final statusColor = _statusColor(displayStatus);
    final priorityColor = _priorityColor(_priority);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F9FC),
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _goBackFromDetail,
          ),
          title: const Text(
            'Report Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Update Status',
                  onPressed: () => _showStatusDialog(context),
                  icon: Icon(
                    Icons.edit_rounded,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            if (_canUserEditReport)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Edit Report',
                  onPressed: () => _showEditReportDialog(context),
                  icon: Icon(
                    Icons.edit_note_rounded,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Reported ${_formatTimestamp(widget.report.createdAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.update_rounded,
                      size: 15,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Updated ${_formatTimestamp(widget.report.updatedAt)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Priority: $_priority',
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
            if (_canUserEditReport) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You can still edit this report while it is Pending.',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_status == 'Rejected') ...[
              const SizedBox(height: 16),
              _buildRejectedNotice(),
            ],
            const SizedBox(height: 26),
            _buildReportProgressSection(),
            const SizedBox(height: 26),
            _buildReportChatSection(),
            _buildReportEvidenceSection(),
            const SizedBox(height: 26),
            _buildSectionHeading(
              icon: Icons.info_outline_rounded,
              title: 'Report Information',
            ),
            const SizedBox(height: 12),
            _buildInfoSection(
              icon: Icons.delete_outline,
              title: 'Waste Type',
              value: _wasteType,
            ),
            const SizedBox(height: 12),
            _buildInfoSection(
              icon: Icons.location_on_outlined,
              title: 'Location',
              value: _location,
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              _buildInfoSection(
                icon: Icons.place_outlined,
                title: 'Area',
                value: _area.isEmpty ? '-' : _area,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 21,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            _buildCompletionProofSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
