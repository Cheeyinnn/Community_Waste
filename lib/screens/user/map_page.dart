import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  final LatLng initialPosition = const LatLng(3.1390, 101.6869);

  String _selectedFilter = 'All';
  WasteReport? _selectedReport;

  final List<String> _filters = [
    'All',
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  BitmapDescriptor _getMarkerColor(String status) {
    switch (status) {
      case 'Pending':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case 'Assigned':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case 'In Progress':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case 'Resolved':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        );
      case 'Rejected':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.amber;
      case 'Assigned':
        return Colors.deepPurple;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  List<WasteReport> _filteredReports(List<WasteReport> reports) {
    final validReports = reports
        .where((r) => r.latitude != 0 && r.longitude != 0)
        .toList();

    if (_selectedFilter == 'All') return validReports;

    return validReports.where((r) => r.status == _selectedFilter).toList();
  }

  Set<Marker> _buildMarkers(List<WasteReport> reports) {
    return reports.map((report) {
      return Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude, report.longitude),
        icon: _getMarkerColor(report.status),
        infoWindow: InfoWindow(
          title: report.title,
          snippet: '${report.wasteType} • ${report.status}',
        ),
        onTap: () async {
          setState(() {
            _selectedReport = report;
          });

          await mapController?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(report.latitude, report.longitude),
            ),
          );
        },
      );
    }).toSet();
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = label;
            _selectedReport = null;
          });
        },
        selectedColor: Colors.green.shade200,
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.green.shade900 : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildSelectedReportCard(BuildContext context, WasteReport report) {
    final statusColor = _statusColor(report.status);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(report: report),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: report.imageUrl.isNotEmpty
                    ? Image.network(
                        report.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.wasteType,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        report.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 5, backgroundColor: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        item(Colors.amber, 'Pending'),
        item(Colors.deepPurple, 'Assigned'),
        item(Colors.orange, 'In Progress'),
        item(Colors.green, 'Resolved'),
        item(Colors.red, 'Rejected'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Map'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<WasteReport>>(
        stream: _firestoreService.getAllReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading map: ${snapshot.error}'),
            );
          }

          final reports = snapshot.data ?? [];
          final filteredReports = _filteredReports(reports);
          final markers = _buildMarkers(filteredReports);

          return Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map(_buildFilterChip).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildLegend(),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filteredReports.isEmpty
                    ? const Center(
                        child: Text('No reports with valid map locations'),
                      )
                    : Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: initialPosition,
                              zoom: 13,
                            ),
                            markers: markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                            onMapCreated: (controller) {
                              mapController = controller;
                            },
                          ),
                          if (_selectedReport != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _buildSelectedReportCard(
                                context,
                                _selectedReport!,
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