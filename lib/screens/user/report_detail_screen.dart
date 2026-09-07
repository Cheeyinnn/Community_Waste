import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

import '../../models/waste_report.dart';

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
    String? locationErrorMessage;

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

              final resolvedArea =
                  newArea.trim().isNotEmpty ? newArea : address;

              final isPerak = _isPerakLocation(
                location: address,
                area: resolvedArea,
                state: newState,
              );

              setDialogState(() {
                selectedLatitude = lat;
                selectedLongitude = lng;
                selectedArea = resolvedArea;
                selectedState = newState;
                verifiedLocationText = address.trim();

                locationErrorMessage = isPerak
                    ? null
                    : 'This service only accepts waste reports within Perak.';
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
                        errorText: locationErrorMessage,
                        errorMaxLines: 2,
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
                            locationErrorMessage =
                                'Please select a suggested location before saving.';
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
                            locationErrorMessage =
                                'Please select a suggested location before saving.';
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
                  onPressed: () => Navigator.pop(dialogContext),
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
                        setDialogState(() {
                          locationErrorMessage =
                              'Please select a suggested location before saving.';
                        });
                        return;
                      }

                      if (!_isPerakLocation(
                        location: newLocation,
                        area: newArea,
                        state: selectedState,
                      )) {
                        setDialogState(() {
                          locationErrorMessage =
                              'This service only accepts waste reports within Perak.';
                        });
                        return;
                      }

                      setDialogState(() {
                        locationErrorMessage = null;
                      });
                    }

                    // The Google Places autocomplete widget can keep an
                    // active focus/overlay while the edit dialog is open.
                    // Closing the dialog immediately while that overlay is
                    // still attached can trigger Flutter's
                    // "_dependents.isEmpty" assertion.
                    //
                    // Always release the keyboard/focus first and give the
                    // autocomplete overlay a short moment to detach before
                    // removing the dialog route.
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

    // Give GooglePlaceAutoCompleteTextField time to finish removing
    // any internal suggestion/focus overlay before its controller is
    // disposed. This is especially important when the user presses
    // Save without selecting a new location.
    await Future.delayed(
      const Duration(milliseconds: 250),
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

  Future<void> _showCompletionImagePreview(
    String imageUrl,
  ) async {
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
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 52,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Unable to load completion photo',
                                style: TextStyle(
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
                        _showCompletionImagePreview(completionUrl);
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

  @override
  Widget build(BuildContext context) {
    final displayStatus = _displayStatus(_status);
    final statusColor = _statusColor(displayStatus);
    final priorityColor = _priorityColor(_priority);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 300.0,
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: _goBackFromDetail,
              ),
              actions: [
                if (widget.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _showStatusDialog(context),
                        icon: Icon(
                          Icons.edit_rounded,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                if (_canUserEditReport)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: 'Edit Report',
                        onPressed: () => _showEditReportDialog(context),
                        icon: Icon(
                          Icons.edit_note_rounded,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: widget.report.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.report.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 60),
                        ),
                      )
                    : Container(
                        color: Colors.green.shade50,
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.green.shade200,
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_canUserEditReport)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can still edit this report while it is Pending.',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Reported: ${_formatTimestamp(widget.report.createdAt)}",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    if (widget.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Priority: $_priority",
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (widget.isAdmin) const SizedBox(height: 20),
                    Text(
                      "Last Updated: ${_formatTimestamp(widget.report.updatedAt)}",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    _buildInfoSection(
                      icon: Icons.delete_outline,
                      title: 'Waste Type',
                      value: _wasteType,
                    ),
                    const SizedBox(height: 14),
                    _buildInfoSection(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      value: _location,
                    ),
                    if (widget.isAdmin) ...[
                      const SizedBox(height: 14),
                      _buildInfoSection(
                        icon: Icons.place_outlined,
                        title: 'Area',
                        value: _area.isEmpty ? '-' : _area,
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    _buildCompletionProofSection(),
                  ],
                ),
              ),
            ),
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
