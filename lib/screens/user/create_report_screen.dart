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

  File? _imageFile;
  String _wasteType = 'General Waste';
  bool _isLoading = false;

  /// 📍 GPS
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isGettingLocation = false;

  final List<String> _wasteTypes = [
    'General Waste',
    'Plastic Waste',
    'Illegal Dumping',
    'Bulky Waste',
    'Hazardous Waste',
  ];

  /// 📷 Pick Image
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  /// 📍 Get Current Location
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

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;

        _locationController.text =
            '${_latitude.toStringAsFixed(5)}, ${_longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }

     final placemarks = await placemarkFromCoordinates(
     _latitude,
     _longitude,
);

    final place = placemarks.first;

    String state = place.administrativeArea ?? '';
    String city = place.locality ?? '';

    setState(() {
    _locationController.text = "$city, $state";
});
}

  /// 🚀 Submit Report
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
        const SnackBar(content: Text('Please upload an image')),
      );
      return;
    }

    /// ❗ GPS validation
    if (_latitude == 0.0 || _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get your current location')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _storageService.uploadReportImage(_imageFile!);
      final now = Timestamp.now();

      final report = WasteReport(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Unknown User',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        wasteType: _wasteType,
        imageUrl: imageUrl,
        status: 'Pending',
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

      /// Reset form
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();

      setState(() {
        _imageFile = null;
        _wasteType = 'General Waste';
        _latitude = 0.0;
        _longitude = 0.0;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Report'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter report title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _inputDecoration('Description'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  if (value.trim().length < 10) {
                    return 'Minimum 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: _inputDecoration('Location'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),

              /// 📍 GPS Button
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isGettingLocation ? null : _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: _isGettingLocation
                      ? const Text('Getting Location...')
                      : const Text('Use Current Location'),
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _wasteType,
                decoration: _inputDecoration('Waste Type'),
                items: _wasteTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _wasteType = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _imageFile!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('No image selected')),
                    ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReport,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}