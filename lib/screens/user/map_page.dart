import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; 
import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'report_detail_screen.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? mapController;

  // Defaults to Kampar, Perak
  final LatLng initialPosition = const LatLng(4.3325, 101.1429);

  String _selectedFilter = 'All';
  List<WasteReport> _currentAllReports = []; 
  
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85); 
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

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

  BitmapDescriptor _getMarkerColor(String status) {
    switch (status) {
      case 'Pending':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'Assigned':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case 'In Progress':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      case 'Resolved':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'Rejected':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  List<WasteReport> _filteredReports(List<WasteReport> reports) {
    final validReports = reports.where((r) => r.latitude != 0 && r.longitude != 0).toList();
    if (_selectedFilter == 'All') return validReports;
    return validReports.where((r) => r.status == _selectedFilter).toList();
  }

  // 🚀 Fetches live GPS and moves camera to the User
  Future<void> _goToUserCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14),
        ),
      );
    } catch (e) {
      debugPrint("Could not get live location: $e");
    }
  }

  Set<Marker> _buildMarkers(List<WasteReport> filteredReports) {
    return filteredReports.map((report) {
      return Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude, report.longitude),
        icon: _getMarkerColor(report.status),
        onTap: () {
          final index = filteredReports.indexOf(report);
          if (index != -1 && _pageController.hasClients) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
      );
    }).toSet();
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final Color chipColor = label == 'All' ? Colors.black87 : _statusColor(label);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = label;
          });
          
          final newFilteredList = _filteredReports(_currentAllReports);
          
          if (newFilteredList.isNotEmpty) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
            // 🚀 Optional: If you want clicking a filter to ALSO not move the camera, 
            // you can delete the next 6 lines. Right now, tapping a filter chip will snap to the first result.
            final firstReport = newFilteredList.first;
            mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(firstReport.latitude, firstReport.longitude),
                15, 
              ),
            );
          }
        },
        selectedColor: chipColor,
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        side: BorderSide(color: isSelected ? Colors.transparent : chipColor.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isSelected ? 4 : 0,
        shadowColor: chipColor.withOpacity(0.4),
      ),
    );
  }

  Widget _buildHorizontalReportCard(BuildContext context, WasteReport report) {
    final statusColor = _statusColor(report.status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // 🚀 Tapping the card redirects the map location to the report!
            onTap: () {
              mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(report.latitude, report.longitude),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: report.imageUrl.isNotEmpty
                          ? Image.network(
                              report.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                            )
                          : const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          report.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                report.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Details Button
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade700,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(0, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Community Map',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: _firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          _currentAllReports = snapshot.data ?? [];
          final filteredReports = _filteredReports(_currentAllReports);
          final markers = _buildMarkers(filteredReports);

          return Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.only(left: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  children: _filters.map(_buildFilterChip).toList(),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: initialPosition, zoom: 14),
                        markers: markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false, 
                        padding: const EdgeInsets.only(bottom: 160), 
                        onMapCreated: (controller) {
                          mapController = controller;
                          
                          // 🚀 FIX: When the map opens, ONLY show the user's current location!
                          _goToUserCurrentLocation(); 
                        },
                      ),
                    ),
                    if (filteredReports.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 90, 
                        height: 160, 
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: filteredReports.length,
                          physics: const ClampingScrollPhysics(),
                          // 🚀 Swiping changes the location
                          onPageChanged: (index) {
                            final report = filteredReports[index];
                            mapController?.animateCamera(
                              CameraUpdate.newLatLng(
                                LatLng(report.latitude, report.longitude),
                              ),
                            );
                          },
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0), 
                              child: _buildHorizontalReportCard(context, filteredReports[index]),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}