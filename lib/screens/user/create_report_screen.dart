import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  static const String _googleApiKey =
      'AIzaSyBHoNEbIfc0lqJ74D70b26P8_vxL5DSw9s';

  File? _imageFile;
  String _wasteType = 'General Waste';
  bool _isLoading = false;

  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isGettingLocation = false;
  String _detectedArea = '';

  final List<String> _wasteTypes = [
    'General Waste',
    'Plastic Waste',
    'Illegal Dumping',
    'Bulky Waste',
    'Hazardous Waste',
  ];

  bool _hasUnsavedChanges() {
    return _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _locationController.text.isNotEmpty ||
        _imageFile != null;
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Discard Report?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard this report and go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep Editing',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );

      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Upload Evidence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _buildFullAddress(Placemark place) {
    final parts = <String>[
      if ((place.subThoroughfare ?? '').trim().isNotEmpty)
        place.subThoroughfare!.trim(),
      if ((place.thoroughfare ?? '').trim().isNotEmpty)
        place.thoroughfare!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
      if ((place.postalCode ?? '').trim().isNotEmpty)
        place.postalCode!.trim(),
      if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
    ];

    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.contains(part)) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(', ');
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

  Future<void> _setAreaFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;

      final place = placemarks.first;
      final areaKey = _buildAreaKey(place);

      setState(() {
        _detectedArea = areaKey.isNotEmpty
            ? areaKey
            : '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                .trim();
      });
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition();

      final lat = position.latitude;
      final lng = position.longitude;

      setState(() {
        _latitude = lat;
        _longitude = lng;
      });

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey',
      );

      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      final responseBody =
          await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody);

      if (data['status'] == 'OK' &&
          data['results'] != null &&
          data['results'].isNotEmpty) {
        final address = data['results'][0]['formatted_address'] as String;

        setState(() {
          _locationController.text = address;
        });
      } else {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final fullAddress = _buildFullAddress(place);

          setState(() {
            _locationController.text = fullAddress.isNotEmpty
                ? fullAddress
                : '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}'
                    .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                    .trim();
          });
        } else {
          setState(() {
            _locationController.text =
                '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
          });
        }
      }

      await _setAreaFromCoordinates(lat, lng);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<bool> _showDuplicateWarningDialog(
    List<WasteReport> duplicates,
  ) async {
    final first = duplicates.first;
    final count = duplicates.length;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Possible Duplicate Report',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              count == 1
                  ? 'A similar report was found within 100 meters in the last 24 hours.\n\n'
                      'Existing report:\n'
                      '• Title: ${first.title}\n'
                      '• Location: ${first.location}\n'
                      '• Status: ${first.status}\n\n'
                      'Do you still want to submit this report?'
                  : '$count similar reports were found within 100 meters in the last 24 hours.\n\n'
                      'Nearest example:\n'
                      '• Title: ${first.title}\n'
                      '• Location: ${first.location}\n'
                      '• Status: ${first.status}\n\n'
                      'Do you still want to submit this report?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<List<WasteReport>> _checkPotentialDuplicates() async {
    if (_latitude == 0.0 && _longitude == 0.0) {
      return [];
    }

    final duplicates = await _firestoreService.findNearbyDuplicateCandidates(
      wasteType: _wasteType,
      latitude: _latitude,
      longitude: _longitude,
      withinDuration: const Duration(hours: 24),
      radiusMeters: 100,
      maxResults: 50,
    );

    duplicates.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
        _latitude,
        _longitude,
        a.latitude,
        a.longitude,
      );
      final distanceB = Geolocator.distanceBetween(
        _latitude,
        _longitude,
        b.latitude,
        b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    return duplicates;
  }

  Future<void> _submitReport() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload photo evidence')),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a location')),
      );
      return;
    }

    if (_detectedArea.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect location first')),
      );
      return;
    }

    if (_latitude == 0.0 && _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please use current location or select a suggested location before submitting',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final duplicates = await _checkPotentialDuplicates();

      if (duplicates.isNotEmpty) {
        if (!mounted) return;

        final shouldContinue = await _showDuplicateWarningDialog(duplicates);

        if (!shouldContinue) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final imageUrl = await _storageService.uploadReportImage(_imageFile!);
      final now = Timestamp.now();

      final autoPriority = await _firestoreService.getAutoPriorityByArea(
        _detectedArea.trim(),
      );

      final report = WasteReport(
        id: '',
        userId: user.uid,
        userName: (user.displayName != null &&
                user.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : 'Community Member',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        area: _detectedArea.trim(),
        wasteType: _wasteType,
        imageUrl: imageUrl,
        status: 'Pending',
        priority: autoPriority,
        collectorId: '',
        collectorName: '',
        adminRemark: '',
        collectorRemark: '',
        completionImageUrl: '',
        latitude: _latitude,
        longitude: _longitude,
        createdAt: now,
        updatedAt: now,
      );

      await _firestoreService.createReport(report);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted successfully! Thank you for helping keep our community clean.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();

      setState(() {
        _imageFile = null;
        _wasteType = 'General Waste';
        _latitude = 0.0;
        _longitude = 0.0;
        _detectedArea = '';
      });

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _modernDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green.shade600, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.green.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        bool shouldPop = true;

        if (_hasUnsavedChanges()) {
          shouldPop = await _showDiscardDialog() ?? false;
        }

        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text(
            'Report Waste',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Photo Evidence",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _isLoading ? null : _showImageSourceOptions,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: _imageFile == null
                            ? Border.all(
                                color: Colors.green.shade300,
                                width: 2,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(_imageFile!, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withOpacity(0.6),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Change",
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add_a_photo,
                                    size: 36,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Tap to add photo",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Report Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _titleController,
                          decoration: _modernDecoration(
                            'What did you find?',
                            Icons.title,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _wasteType,
                          decoration: _modernDecoration(
                            'Type of Waste',
                            Icons.category_outlined,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          items: _wasteTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _wasteType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: _modernDecoration(
                            'Additional details...',
                            Icons.notes_rounded,
                          ).copyWith(
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please add a description';
                            }
                            if (value.trim().length < 10) {
                              return 'Please be a bit more descriptive (10+ chars)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 10),
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GooglePlaceAutoCompleteTextField(
                                textEditingController: _locationController,
                                googleAPIKey: _googleApiKey,
                                inputDecoration: _modernDecoration(
                                  'Search location',
                                  Icons.pin_drop_outlined,
                                ),
                                debounceTime: 600,
                                isLatLngRequired: true,
                                countries: const ['my'],
                                boxDecoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                itemClick: (prediction) async {
                                  final selectedText =
                                      prediction.description ?? '';

                                  _locationController.text = selectedText;
                                  _locationController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(offset: selectedText.length),
                                  );

                                  final lat =
                                      double.tryParse(prediction.lat ?? '');
                                  final lng =
                                      double.tryParse(prediction.lng ?? '');

                                  if (lat != null && lng != null) {
                                    setState(() {
                                      _latitude = lat;
                                      _longitude = lng;
                                    });

                                    await _setAreaFromCoordinates(lat, lng);
                                  }
                                },
                                getPlaceDetailWithLatLng: (prediction) async {
                                  final lat =
                                      double.tryParse(prediction.lat ?? '');
                                  final lng =
                                      double.tryParse(prediction.lng ?? '');

                                  if (lat != null && lng != null) {
                                    setState(() {
                                      _latitude = lat;
                                      _longitude = lng;
                                    });

                                    await _setAreaFromCoordinates(lat, lng);
                                  }
                                },
                                itemBuilder: (context, index, prediction) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          color: Colors.green.shade600,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            prediction.description ?? '',
                                            style:
                                                const TextStyle(fontSize: 14),
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
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 55,
                              width: 55,
                              child: ElevatedButton(
                                onPressed: _isGettingLocation
                                    ? null
                                    : _getCurrentLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: _isGettingLocation
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _detectedArea.isEmpty
                                      ? 'Area will be detected after selecting a suggested location or using current location.'
                                      : 'Detected area: $_detectedArea',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.green.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Submitting...",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Submit Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}