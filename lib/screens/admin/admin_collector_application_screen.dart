import 'package:flutter/material.dart';

import '../../models/collector_application.dart';
import '../../services/collector_application_service.dart';

class AdminCollectorApplicationScreen extends StatefulWidget {
  const AdminCollectorApplicationScreen({super.key});

  @override
  State<AdminCollectorApplicationScreen> createState() =>
      _AdminCollectorApplicationScreenState();
}

class _AdminCollectorApplicationScreenState
    extends State<AdminCollectorApplicationScreen> {
  final CollectorApplicationService _applicationService =
      CollectorApplicationService();

  String _selectedFilter = 'pending';

  static const Map<String, String> _zones = {
    'kampar_zone_1': 'Zone 1 • Kampar - Tronoh Mines',
    'kampar_zone_2': 'Zone 2 • Kampar - Bandar Baru',
    'kampar_zone_3': 'Zone 3 • Kampar Barat - Jeram',
    'kampar_zone_4': 'Zone 4 • Gopeng',
    'ipoh_zone_bercham': 'Ipoh • Bercham',
    'ipoh_zone_buntong': 'Ipoh • Buntong',
    'ipoh_zone_chempaka': 'Ipoh • Chempaka',
    'ipoh_zone_chemor': 'Ipoh • Chemor',
    'ipoh_zone_cherry': 'Ipoh • Cherry',
    'ipoh_zone_gunung_rapat': 'Ipoh • Gunung Rapat',
    'ipoh_zone_happy_garden': 'Ipoh • Happy Garden',
    'ipoh_zone_housing_trust': 'Ipoh • Housing Trust',
    'ipoh_zone_jelapang': 'Ipoh • Jelapang / Meru',
    'ipoh_zone_lahat': 'Ipoh • Lahat',
    'ipoh_zone_manjoi': 'Ipoh • Manjoi',
    'ipoh_zone_menglembu': 'Ipoh • Menglembu',
    'ipoh_zone_pasir_pinji': 'Ipoh • Pasir Pinji',
    'ipoh_zone_pekan_lama_baru': 'Ipoh • Pekan Lama & Baru',
    'ipoh_zone_simee_canning': 'Ipoh • Simee / Canning',
    'ipoh_zone_simpang_pulai': 'Ipoh • Simpang Pulai',
    'ipoh_zone_tambun': 'Ipoh • Tambun',
    'ipoh_zone_tanjung_rambutan': 'Ipoh • Tanjung Rambutan',
    'ipoh_zone_tasek': 'Ipoh • Tasek',
  };

  Stream<List<CollectorApplication>> get _applicationStream {
    return _applicationService.watchApplicationsByStatus(
      _selectedFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Collector Applications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<CollectorApplication>>(
              stream: _applicationStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load collector applications.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final applications =
                    snapshot.data ?? <CollectorApplication>[];

                if (applications.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                    await Future<void>.delayed(
                      const Duration(milliseconds: 350),
                    );
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      10,
                      18,
                      110,
                    ),
                    itemCount: applications.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildApplicationCard(
                        applications[index],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    const filters = <MapEntry<String, String>>[
      MapEntry('pending', 'Pending'),
      MapEntry('approved', 'Approved'),
      MapEntry('rejected', 'Rejected'),
      MapEntry('all', 'All'),
    ];

    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected =
              _selectedFilter == filter.key;

          return ChoiceChip(
            label: Text(filter.value),
            selected: selected,
            showCheckmark: false,
            selectedColor: Colors.blue,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? Colors.transparent
                  : Colors.grey.shade300,
            ),
            labelStyle: TextStyle(
              color:
                  selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter.key;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(
    CollectorApplication application,
  ) {
    final statusColor = _statusColor(application.status);
    final submittedText =
        _formatTimestamp(application.submittedAt);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    statusColor.withOpacity(0.12),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.applicantName.isEmpty
                          ? 'User'
                          : application.applicantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      application.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  application.statusDisplayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.phone_outlined,
            'Phone',
            application.phone,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Preferred Area',
            application.preferredArea,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.schedule_rounded,
            'Submitted',
            submittedText,
          ),
          if (application.isApproved &&
              application
                  .assignedCollectionZoneIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.route_outlined,
              'Assigned',
              application.assignedCollectionZoneIds
                  .map(_zoneDisplayName)
                  .join(', '),
            ),
          ],
          const SizedBox(height: 17),
          if (application.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showRejectDialog(application);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.shade200,
                      ),
                      minimumSize:
                          const Size.fromHeight(46),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showApprovalSheet(application);
                    },
                    icon: const Icon(
                      Icons.verified_outlined,
                    ),
                    label:
                        const Text('Review & Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize:
                          const Size.fromHeight(46),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showDetails(application);
                },
                icon: const Icon(
                  Icons.visibility_outlined,
                ),
                label: const Text('View Details'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 76,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 15),
            Text(
              'No ${_filterDisplayName()} applications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApprovalSheet(
    CollectorApplication application,
  ) async {
    final selectedZones = <String>{};
    final remarkController = TextEditingController();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext)
                    .viewInsets
                    .bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Approve Collector',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        application.applicantName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildReviewDetail(
                        'Preferred Area',
                        application.preferredArea,
                      ),
                      _buildReviewDetail(
                        'Phone',
                        application.phone,
                      ),
                      _buildReviewDetail(
                        'Experience',
                        application.experience.isEmpty
                            ? 'Not provided'
                            : application.experience,
                      ),
                      _buildReviewDetail(
                        'Reason',
                        application.reason,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Assign Collection Zone',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Select at least one zone. The applicant\'s preferred area is only a preference.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._zones.entries.map((entry) {
                        final checked =
                            selectedZones.contains(entry.key);

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: checked,
                          activeColor: Colors.blue,
                          title: Text(
                            entry.value,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onChanged: saving
                              ? null
                              : (value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      selectedZones.add(entry.key);
                                    } else {
                                      selectedZones.remove(entry.key);
                                    }
                                  });
                                },
                        );
                      }),
                      const SizedBox(height: 8),
                      TextField(
                        controller: remarkController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Admin Remark (Optional)',
                          hintText:
                              'Add approval notes if needed',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (selectedZones.isEmpty) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select at least one collection zone.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() {
                                    saving = true;
                                  });

                                  try {
                                    await _applicationService
                                        .approveApplication(
                                      applicationId:
                                          application.id,
                                      assignedCollectionZoneIds:
                                          selectedZones.toList(),
                                      adminRemark:
                                          remarkController.text,
                                    );

                                    if (!mounted) return;

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Collector application approved.',
                                        ),
                                        backgroundColor:
                                            Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;

                                    setSheetState(() {
                                      saving = false;
                                    });

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Approval failed: $e',
                                        ),
                                        backgroundColor:
                                            Colors.red,
                                      ),
                                    );
                                  }
                                },
                          icon: saving
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.verified_rounded,
                                ),
                          label: Text(
                            saving
                                ? 'Approving...'
                                : 'Approve & Assign Zone',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    remarkController.dispose();
  }

  Future<void> _showRejectDialog(
    CollectorApplication application,
  ) async {
    final remarkController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reject Application?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Reject ${application.applicantName}\'s collector application?',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin Remark',
                  hintText:
                      'Optional reason for rejection',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      remarkController.dispose();
      return;
    }

    try {
      await _applicationService.rejectApplication(
        applicationId: application.id,
        adminRemark: remarkController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collector application rejected.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rejection failed: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      remarkController.dispose();
    }
  }

  Future<void> _showDetails(
    CollectorApplication application,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            26,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        application.applicantName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          application.status,
                        ).withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        application.statusDisplayName,
                        style: TextStyle(
                          color: _statusColor(
                            application.status,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildReviewDetail(
                  'Email',
                  application.email,
                ),
                _buildReviewDetail(
                  'Phone',
                  application.phone,
                ),
                _buildReviewDetail(
                  'Preferred Area',
                  application.preferredArea,
                ),
                _buildReviewDetail(
                  'Experience',
                  application.experience.isEmpty
                      ? 'Not provided'
                      : application.experience,
                ),
                _buildReviewDetail(
                  'Reason',
                  application.reason,
                ),
                _buildReviewDetail(
                  'Submitted',
                  _formatTimestamp(
                    application.submittedAt,
                  ),
                ),
                if (application.reviewedAt != null)
                  _buildReviewDetail(
                    'Reviewed',
                    _formatTimestamp(
                      application.reviewedAt,
                    ),
                  ),
                if (application
                    .assignedCollectionZoneIds.isNotEmpty)
                  _buildReviewDetail(
                    'Assigned Zones',
                    application.assignedCollectionZoneIds
                        .map(_zoneDisplayName)
                        .join('\n'),
                  ),
                if (application.adminRemark.trim().isNotEmpty)
                  _buildReviewDetail(
                    'Admin Remark',
                    application.adminRemark,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewDetail(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _filterDisplayName() {
    switch (_selectedFilter) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'all':
        return '';
      case 'pending':
      default:
        return 'pending';
    }
  }

  String _zoneDisplayName(String zoneId) {
    return _zones[zoneId] ?? zoneId;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return '-';
    }

    try {
      final date = timestamp.toDate() as DateTime;

      String two(int value) =>
          value.toString().padLeft(2, '0');

      return '${two(date.day)}/${two(date.month)}/${date.year} '
          '${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return '-';
    }
  }
}
