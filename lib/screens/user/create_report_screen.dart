import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/waste_ai_service.dart';

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
  final FocusNode _locationFocusNode = FocusNode();

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final WasteAiService _wasteAiService = WasteAiService();

  // Keep your current working Google API key here.
  static const String _googleApiKey = 'AIzaSyBHoNEbIfc0lqJ74D70b26P8_vxL5DSw9s';

  File? _imageFile;

  String _wasteType = 'General Waste';

  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isAnalyzingImage = false;

  WasteAiSuggestion? _aiSuggestion;

  double _latitude = 0.0;
  double _longitude = 0.0;

  String _detectedArea = '';
  String _detectedState = '';

  // Stores the exact text belonging to a verified GPS/Google location.
  String _verifiedLocationText = '';

  final List<String> _wasteTypes = [
    'General Waste',
    'Plastic Waste',
    'Illegal Dumping',
    'Bulky Waste',
    'Hazardous Waste',
  ];

  Timer? _locationSearchDebounce;
  final List<Map<String, String>> _placeSuggestions = [];
  bool _isSearchingPlaces = false;
  String _latestSearchQuery = '';

  void _setLocationText(String text) {
    _locationController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _clearLocation() {
    _locationSearchDebounce?.cancel();
    _latestSearchQuery = '';
    _locationController.clear();

    setState(() {
      _placeSuggestions.clear();
      _isSearchingPlaces = false;
      _verifiedLocationText = '';
      _latitude = 0.0;
      _longitude = 0.0;
      _detectedArea = '';
      _detectedState = '';
    });

    _locationFocusNode.requestFocus();
  }

  void _onLocationChanged(String value) {
    final query = value.trim();

    _locationSearchDebounce?.cancel();

    setState(() {
      // Any manual edit makes the previous GPS/Google location invalid
      // until the user selects a suggestion again.
      _verifiedLocationText = '';
      _latitude = 0.0;
      _longitude = 0.0;
      _detectedArea = '';
      _detectedState = '';

      if (query.length < 2) {
        _placeSuggestions.clear();
        _isSearchingPlaces = false;
      }
    });

    if (query.length < 2) {
      _latestSearchQuery = query;
      return;
    }

    _locationSearchDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    _latestSearchQuery = query;

    if (mounted) {
      setState(() {
        _isSearchingPlaces = true;
      });
    }

    try {
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': _googleApiKey,
          'language': 'en',
          'components': 'country:my',
        },
      );

      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Location search failed');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';

      // Ignore an old response if the user has already typed something else.
      if (!mounted ||
          _latestSearchQuery != query ||
          _locationController.text.trim() != query) {
        return;
      }

      if (status == 'OK') {
        final predictions = (data['predictions'] as List<dynamic>? ?? []);

        final suggestions = predictions
            .take(6)
            .map<Map<String, String>>((item) {
              final prediction = item as Map<String, dynamic>;

              return {
                'description': prediction['description']?.toString() ?? '',
                'placeId': prediction['place_id']?.toString() ?? '',
              };
            })
            .where((item) {
              return item['description']!.isNotEmpty &&
                  item['placeId']!.isNotEmpty;
            })
            .toList();

        setState(() {
          _placeSuggestions
            ..clear()
            ..addAll(suggestions);
          _isSearchingPlaces = false;
        });
      } else if (status == 'ZERO_RESULTS') {
        setState(() {
          _placeSuggestions.clear();
          _isSearchingPlaces = false;
        });
      } else {
        debugPrint(
          'Google Places autocomplete error: '
          '${data['error_message'] ?? status}',
        );

        setState(() {
          _placeSuggestions.clear();
          _isSearchingPlaces = false;
        });
      }
    } catch (e) {
      if (!mounted || _latestSearchQuery != query) return;

      debugPrint('Location search error: $e');

      setState(() {
        _placeSuggestions.clear();
        _isSearchingPlaces = false;
      });
    }
  }

  Future<void> _selectPlace(Map<String, String> suggestion) async {
    final description = suggestion['description'] ?? '';
    final placeId = suggestion['placeId'] ?? '';

    if (description.isEmpty || placeId.isEmpty) {
      return;
    }

    _locationSearchDebounce?.cancel();
    _latestSearchQuery = '';

    setState(() {
      _placeSuggestions.clear();
      _isSearchingPlaces = true;
    });

    _setLocationText(description);
    _locationFocusNode.unfocus();

    try {
      final url =
          Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
            'place_id': placeId,
            'key': _googleApiKey,
            'language': 'en',
            'fields': 'formatted_address,geometry,address_components',
          });

      final request = await HttpClient().getUrl(url);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Failed to load location details');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (data['status'] != 'OK' || data['result'] == null) {
        throw Exception(
          data['error_message']?.toString() ??
              'Unable to verify the selected location',
        );
      }

      final result = data['result'] as Map<String, dynamic>;
      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      final latValue = location?['lat'];
      final lngValue = location?['lng'];

      if (latValue == null || lngValue == null) {
        throw Exception('Selected location has no coordinates');
      }

      final lat = (latValue as num).toDouble();
      final lng = (lngValue as num).toDouble();

      final formattedAddress =
          result['formatted_address']?.toString().trim() ?? '';

      final displayAddress = formattedAddress.isNotEmpty
          ? formattedAddress
          : description;

      _setLocationText(displayAddress);

      setState(() {
        _latitude = lat;
        _longitude = lng;
        _verifiedLocationText = displayAddress;
        _isSearchingPlaces = false;
      });

      // Prefer Google's address components because they are more reliable
      // around UTAR / Bandar Barat than the device reverse-geocoder alone.
      _applyGoogleLocationMetadata(result);

      // Fall back to the geocoding package only when Google did not provide
      // enough area/state information. Existing Google metadata is preserved.
      if (_detectedArea.trim().isEmpty || _detectedState.trim().isEmpty) {
        await _setAreaFromCoordinates(lat, lng);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _verifiedLocationText = '';
        _latitude = 0.0;
        _longitude = 0.0;
        _detectedArea = '';
        _detectedState = '';
        _isSearchingPlaces = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select location: $e'),
          backgroundColor: Colors.red,
        ),
      );

      _locationFocusNode.requestFocus();
    }
  }

  // ============================================================
  // UNSAVED REPORT
  // ============================================================

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

  // ============================================================
  // IMAGE
  // ============================================================

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );

      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
          _aiSuggestion = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
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

  // ============================================================
  // GEMINI AI WASTE TYPE SUGGESTION
  // ============================================================

  Future<void> _analyzeWasteImage() async {
    if (_imageFile == null || _isAnalyzingImage || _isLoading) {
      return;
    }

    setState(() {
      _isAnalyzingImage = true;
      _aiSuggestion = null;
    });

    try {
      final suggestion =
          await _wasteAiService.suggestWasteType(_imageFile!);

      if (!mounted) return;

      setState(() {
        _aiSuggestion = suggestion;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI suggestion failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  void _useAiSuggestion() {
    final category = _aiSuggestion?.category;

    if (category == null || !_wasteTypes.contains(category)) {
      return;
    }

    setState(() {
      _wasteType = category;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Waste type changed to $category'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildAiSuggestionCard() {
    final suggestion = _aiSuggestion;

    if (_imageFile == null) {
      return const SizedBox.shrink();
    }

    if (_isAnalyzingImage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.deepPurple.shade100,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gemini is analyzing the waste image...',
                style: TextStyle(
                  color: Colors.deepPurple.shade800,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (suggestion == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _analyzeWasteImage,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('AI Suggest Waste Type'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: BorderSide(
              color: Colors.deepPurple.shade200,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    final hasCategory = suggestion.category != null;

    final Color accentColor = hasCategory
        ? Colors.deepPurple
        : suggestion.isUnclear
            ? Colors.orange
            : Colors.red;

    final Color boxColor = hasCategory
        ? Colors.deepPurple.shade50
        : suggestion.isUnclear
            ? Colors.orange.shade50
            : Colors.red.shade50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasCategory
                    ? Icons.auto_awesome_rounded
                    : suggestion.isUnclear
                        ? Icons.help_outline_rounded
                        : Icons.warning_amber_rounded,
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCategory
                          ? 'Gemini AI Suggestion'
                          : suggestion.isUnclear
                              ? 'AI Could Not Decide'
                              : 'Image May Not Show Waste',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.message,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasCategory) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _aiSuggestion = null;
                            });

                            _analyzeWasteImage();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(
                        color: accentColor.withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Analyze Again'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _useAiSuggestion,
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 18,
                    ),
                    label: const Text('Use Suggestion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _aiSuggestion = null;
                        });

                        _analyzeWasteImage();
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: accentColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'AI only provides a suggestion. You can still choose any waste '
            'type manually.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADDRESS
  // ============================================================

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
      if ((place.postalCode ?? '').trim().isNotEmpty) place.postalCode!.trim(),
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

  String _googleAddressComponent(
    Map<String, dynamic> result,
    String wantedType, {
    bool shortName = false,
  }) {
    final components =
        (result['address_components'] as List<dynamic>? ?? const []);

    for (final item in components) {
      if (item is! Map<String, dynamic>) continue;

      final types = (item['types'] as List<dynamic>? ?? const [])
          .map((type) => type.toString())
          .toList();

      if (types.contains(wantedType)) {
        final key = shortName ? 'short_name' : 'long_name';
        return item[key]?.toString().trim() ?? '';
      }
    }

    return '';
  }

  String _buildGoogleAreaKey(Map<String, dynamic> result) {
    final route = _googleAddressComponent(result, 'route');
    final sublocality =
        _googleAddressComponent(result, 'sublocality_level_1');
    final locality = _googleAddressComponent(result, 'locality');
    final district =
        _googleAddressComponent(result, 'administrative_area_level_2');
    final state =
        _googleAddressComponent(result, 'administrative_area_level_1');

    final parts = <String>[
      route,
      sublocality,
      locality,
      district,
      state,
    ];

    final uniqueParts = <String>[];

    for (final rawPart in parts) {
      final part = rawPart.trim();

      if (part.isEmpty) continue;

      final alreadyExists = uniqueParts.any(
        (existing) => existing.toLowerCase() == part.toLowerCase(),
      );

      if (!alreadyExists) {
        uniqueParts.add(part);
      }
    }

    return uniqueParts.join(', ');
  }

  void _applyGoogleLocationMetadata(Map<String, dynamic> result) {
    final googleArea = _buildGoogleAreaKey(result);
    final googleState =
        _googleAddressComponent(result, 'administrative_area_level_1');

    if (!mounted) return;

    setState(() {
      if (googleArea.isNotEmpty) {
        _detectedArea = googleArea;
      }

      if (googleState.isNotEmpty) {
        _detectedState = googleState;
      }
    });
  }

  // ============================================================
  // STATE AND LOCATION VALIDATION
  // ============================================================

  bool _isLocationInPerak() {
    final stateText = _detectedState.toLowerCase();
    final verifiedAddress = _verifiedLocationText.toLowerCase();

    // Prefer structured state metadata, but also accept the verified Google
    // address text as a fallback. This prevents valid places such as UTAR FICT
    // from being blocked when the device reverse-geocoder returns an empty or
    // inconsistent administrativeArea.
    return stateText.contains('perak') || verifiedAddress.contains('perak');
  }

  bool _isOutsidePerak() {
    return _isLocationVerified() && !_isLocationInPerak();
  }

  bool _isLocationVerified() {
    if (_locationController.text.trim().isEmpty) {
      return false;
    }

    return _verifiedLocationText.trim().isNotEmpty &&
        _locationController.text.trim() == _verifiedLocationText.trim() &&
        _latitude != 0.0 &&
        _longitude != 0.0;
  }

  bool _canSubmitLocation() {
    return _isLocationVerified() && _isLocationInPerak();
  }

  Future<void> _setAreaFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty || !mounted) {
        return;
      }

      final place = placemarks.first;
      final areaKey = _buildAreaKey(place);
      final fallbackArea = areaKey.isNotEmpty
          ? areaKey
          : '${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
                .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                .trim();
      final fallbackState = (place.administrativeArea ?? '').trim();

      setState(() {
        // Do not erase valid metadata already obtained from Google.
        if (_detectedArea.trim().isEmpty && fallbackArea.isNotEmpty) {
          _detectedArea = fallbackArea;
        }

        if (_detectedState.trim().isEmpty && fallbackState.isNotEmpty) {
          _detectedState = fallbackState;
        }
      });
    } catch (e) {
      // Keep any Google metadata already obtained. A failure from the device
      // geocoder should not invalidate an otherwise verified Google location.
      debugPrint('Reverse geocoding fallback failed: $e');
    }
  }

  // ============================================================
  // CURRENT GPS LOCATION
  // ============================================================

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

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

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition();

      final lat = position.latitude;
      final lng = position.longitude;

      setState(() {
        _latitude = lat;
        _longitude = lng;
      });

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=$_googleApiKey',
      );

      final request = await HttpClient().getUrl(url);
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();

      final data = jsonDecode(responseBody);

      String detectedAddress = '';
      Map<String, dynamic>? googleResult;

      if (data['status'] == 'OK' &&
          data['results'] != null &&
          data['results'].isNotEmpty) {
        googleResult =
            Map<String, dynamic>.from(data['results'][0] as Map);

        detectedAddress =
            googleResult['formatted_address']?.toString().trim() ?? '';

        _applyGoogleLocationMetadata(googleResult);
      }

      if (detectedAddress.isEmpty) {
        final placemarks = await placemarkFromCoordinates(lat, lng);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final fullAddress = _buildFullAddress(place);

          detectedAddress = fullAddress.isNotEmpty
              ? fullAddress
              : '${place.locality ?? ''}, '
                        '${place.administrativeArea ?? ''}, '
                        '${place.country ?? ''}'
                    .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                    .trim();
        } else {
          detectedAddress =
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _verifiedLocationText = detectedAddress;
      });

      _setLocationText(detectedAddress);

      // Use the device geocoder only as a fallback for missing metadata.
      if (_detectedArea.trim().isEmpty || _detectedState.trim().isEmpty) {
        await _setAreaFromCoordinates(lat, lng);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // DUPLICATE REPORT
  // ============================================================

  Future<bool> _showDuplicateWarningDialog(List<WasteReport> duplicates) async {
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

  // ============================================================
  // SUBMIT REPORT
  // ============================================================

  Future<void> _submitReport() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));

      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

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

    if (!_isLocationVerified()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a suggested location or use your current location.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    if (!_isLocationInPerak()) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final duplicates = await _checkPotentialDuplicates();

      if (duplicates.isNotEmpty) {
        if (!mounted) return;

        final shouldContinue = await _showDuplicateWarningDialog(duplicates);

        if (!shouldContinue) {
          setState(() {
            _isLoading = false;
          });

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
        userName:
            (user.displayName != null && user.displayName!.trim().isNotEmpty)
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
        const SnackBar(
          content: Text(
            'Report submitted successfully! Thank you for helping keep our community clean.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _descriptionController.clear();

      // Clear verification before clearing the text field.
      _verifiedLocationText = '';

      _setLocationText('');

      setState(() {
        _imageFile = null;
        _aiSuggestion = null;
        _wasteType = 'General Waste';
        _latitude = 0.0;
        _longitude = 0.0;
        _detectedArea = '';
        _detectedState = '';
      });

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // INPUT DESIGN
  // ============================================================

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ============================================================
  // LOCATION STATUS
  // ============================================================

  Color _locationBoxColor() {
    if (_locationController.text.trim().isNotEmpty && !_isLocationVerified()) {
      return Colors.orange.shade50;
    }

    if (_detectedArea.isEmpty) {
      return Colors.grey.shade100;
    }

    if (_isLocationInPerak()) {
      return Colors.green.shade50;
    }

    return Colors.red.shade50;
  }

  Color _locationTextColor() {
    if (_locationController.text.trim().isNotEmpty && !_isLocationVerified()) {
      return Colors.orange.shade800;
    }

    if (_detectedArea.isEmpty) {
      return Colors.grey.shade700;
    }

    if (_isLocationInPerak()) {
      return Colors.green.shade800;
    }

    return Colors.red.shade800;
  }

  IconData _locationStatusIcon() {
    if (_locationController.text.trim().isNotEmpty && !_isLocationVerified()) {
      return Icons.warning_amber_rounded;
    }

    if (_detectedArea.isEmpty) {
      return Icons.location_searching;
    }

    if (_isLocationInPerak()) {
      return Icons.check_circle_outline;
    }

    return Icons.error_outline;
  }

  String _locationStatusText() {
    if (_locationController.text.trim().isNotEmpty && !_isLocationVerified()) {
      return 'Please select a suggested location or use your current location.';
    }

    if (_detectedArea.isEmpty) {
      return 'Area will be detected after selecting a suggested location or using current location.';
    }

    if (_isLocationInPerak()) {
      return 'Detected area: $_detectedArea\nLocation is within Perak.';
    }

    return 'Detected area: $_detectedArea\nReporting is only available within Perak.';
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _locationFocusNode.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();

    super.dispose();
  }

  // ============================================================
  // PAGE
  // ============================================================

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
                    'Photo Evidence',
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
                            ? Border.all(color: Colors.green.shade300, width: 2)
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
                                            'Change',
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
                                  'Tap to add photo',
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

                  if (_imageFile != null) ...[
                    const SizedBox(height: 14),
                    _buildAiSuggestionCard(),
                  ],

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
                          'Report Details',
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
                            return DropdownMenuItem<String>(
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
                          ).copyWith(alignLabelWithHint: true),
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
                              child: TextFormField(
                                controller: _locationController,
                                focusNode: _locationFocusNode,
                                keyboardType: TextInputType.streetAddress,
                                textInputAction: TextInputAction.search,
                                onChanged: _onLocationChanged,
                                onFieldSubmitted: (_) {
                                  if (_placeSuggestions.isNotEmpty) {
                                    _selectPlace(_placeSuggestions.first);
                                  }
                                },
                                decoration:
                                    _modernDecoration(
                                      'Search location',
                                      Icons.pin_drop_outlined,
                                    ).copyWith(
                                      suffixIcon:
                                          _locationController.text.isNotEmpty
                                          ? IconButton(
                                              tooltip: 'Clear location',
                                              onPressed: _clearLocation,
                                              icon: const Icon(Icons.close),
                                            )
                                          : null,
                                    ),
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

                        if (_isSearchingPlaces) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            minHeight: 2,
                            color: Colors.green.shade600,
                            backgroundColor: Colors.green.shade50,
                          ),
                        ],

                        if (_placeSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 230),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _placeSuggestions.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final suggestion = _placeSuggestions[index];

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.green.shade600,
                                  ),
                                  title: Text(
                                    suggestion['description'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  onTap: () => _selectPlace(suggestion),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _locationBoxColor(),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _locationStatusIcon(),
                                color: _locationTextColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _locationStatusText(),
                                  style: TextStyle(
                                    color: _locationTextColor(),
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
                      onPressed: (_isLoading || !_canSubmitLocation())
                          ? null
                          : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        foregroundColor: Colors.white,
                        elevation: _canSubmitLocation() ? 4 : 0,
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
                                  'Submitting...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              !_isLocationVerified()
                                  ? 'Select or Detect a Location'
                                  : _isOutsidePerak()
                                  ? 'Outside Perak - Cannot Submit'
                                  : 'Submit Report',
                              style: const TextStyle(
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
