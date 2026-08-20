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
    double? selectedLatitude;
    double? selectedLongitude;

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

              setDialogState(() {
                selectedLatitude = lat;
                selectedLongitude = lng;
                selectedArea = newArea.trim().isNotEmpty ? newArea : address;
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

                    Navigator.pop(dialogContext);

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

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_status);
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
                            _status,
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
                    const SizedBox(height: 24),
                    if (_completionImageUrl.isNotEmpty) ...[
                      const Text(
                        'Completion Proof',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _completionImageUrl,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ],
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
