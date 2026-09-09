import 'package:flutter/material.dart';

import '../../models/collector_application.dart';
import '../../services/collector_application_service.dart';

class CollectorApplicationScreen extends StatefulWidget {
  const CollectorApplicationScreen({super.key});

  @override
  State<CollectorApplicationScreen> createState() =>
      _CollectorApplicationScreenState();
}

class _CollectorApplicationScreenState
    extends State<CollectorApplicationScreen> {
  final CollectorApplicationService _applicationService =
      CollectorApplicationService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _preferredAreaController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _showReapplyForm = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _preferredAreaController.dispose();
    _experienceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _applicationService.submitApplication(
        phone: _phoneController.text,
        preferredArea: _preferredAreaController.text,
        experience: _experienceController.text,
        reason: _reasonController.text,
      );

      if (!mounted) return;

      _showReapplyForm = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collector application submitted successfully.',
          ),
          backgroundColor: Color(0xFF35C76F),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Collector Application',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<CollectorApplication?>(
        stream: _applicationService.watchMyApplication(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF35C76F),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your collector application.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final application = snapshot.data;

          if (application == null ||
              ((application.isRejected || application.isDemoted) &&
                  _showReapplyForm)) {
            return _buildApplicationForm(
              previousApplication: application,
            );
          }

          return _buildApplicationStatus(application);
        },
      ),
    );
  }

  Widget _buildApplicationForm({
    CollectorApplication? previousApplication,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43B9FF), Color(0xFF35C76F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                SizedBox(height: 12),
                Text(
                  'Apply to Become a Collector',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Submitting this form does not change your role immediately. '
                  'An administrator must review and approve your application first.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Application Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'e.g. 012-3456789',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _preferredAreaController,
            label: 'Preferred Work Area',
            hint: 'e.g. Kampar / Gopeng / Flexible',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _experienceController,
            label: 'Relevant Experience (Optional)',
            hint: 'Briefly describe any relevant work experience',
            icon: Icons.work_outline_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _reasonController,
            label: 'Why do you want to become a collector?',
            hint: 'Tell the admin why you are interested in this role',
            icon: Icons.edit_note_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange.shade800,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your preferred work area is only a preference. '
                    'The admin will decide your official collection zone after approval.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (previousApplication?.isRejected == true ||
              previousApplication?.isDemoted == true) ...[
            const SizedBox(height: 14),
            if ((previousApplication?.isRejected == true &&
                    previousApplication!.adminRemark.trim().isNotEmpty) ||
                (previousApplication?.isDemoted == true &&
                    previousApplication!.demotionReason.trim().isNotEmpty))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  previousApplication!.isDemoted
                      ? 'Previous demotion reason: ${previousApplication!.demotionReason}'
                      : 'Previous admin remark: ${previousApplication!.adminRemark}',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35C76F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Application',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatus(
    CollectorApplication application,
  ) {
    final Color statusColor;
    final IconData statusIcon;
    final String title;
    final String message;

    if (application.isApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.verified_rounded;
      title = 'Application Approved';
      message =
          'Your Collector access is active and your collection zone has been assigned. Log out and sign in using Collector Login to enter the Collector workspace.';
    } else if (application.isSuspended) {
      statusColor = Colors.orange;
      statusIcon = Icons.pause_circle_outline_rounded;
      title = 'Collector Access Suspended';
      message =
          'Your Collector access is temporarily suspended. You can continue using the application as a normal User until an Admin reactivates your Collector access.';
    } else if (application.isDemoted) {
      statusColor = Colors.grey;
      statusIcon = Icons.person_off_outlined;
      title = 'Collector Role Ended';
      message =
          'Your Collector role has been returned to a normal User account. You may continue using User functions and apply again in the future if you want to become a Collector.';
    } else if (application.isRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_outlined;
      title = 'Application Rejected';
      message =
          'Your application was not approved. You may review the admin remark and submit a new application.';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top_rounded;
      title = 'Application Pending';
      message =
          'Your application has been submitted and is waiting for administrator review.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 22),
                _buildStatusRow(
                  'Status',
                  application.statusDisplayName,
                  valueColor: statusColor,
                ),
                _buildStatusRow(
                  'Preferred Area',
                  application.preferredArea,
                ),
                if ((application.isApproved || application.isSuspended) &&
                    application.assignedCollectionZoneIds.isNotEmpty)
                  _buildStatusRow(
                    'Assigned Zone',
                    application.assignedCollectionZoneIds
                        .map(_zoneDisplayName)
                        .join(', '),
                  ),
                _buildStatusRow(
                  'Phone',
                  application.phone,
                ),
                if (application.adminRemark.trim().isNotEmpty)
                  _buildStatusRow(
                    'Admin Remark',
                    application.adminRemark,
                  ),
                if (application.isSuspended &&
                    application.suspensionReason.trim().isNotEmpty)
                  _buildStatusRow(
                    'Suspension Reason',
                    application.suspensionReason,
                    valueColor: Colors.orange.shade800,
                  ),
                if (application.isDemoted &&
                    application.demotionReason.trim().isNotEmpty)
                  _buildStatusRow(
                    'Demotion Reason',
                    application.demotionReason,
                    valueColor: Colors.grey.shade700,
                  ),
                if (application.isRejected || application.isDemoted) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _phoneController.text = application.phone;
                        _preferredAreaController.text =
                            application.preferredArea;
                        _experienceController.text = application.experience;
                        _reasonController.clear();

                        setState(() {
                          _showReapplyForm = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35C76F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Apply Again',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _zoneDisplayName(String zoneId) {
    switch (zoneId) {
      case 'kampar_zone_1':
        return 'Zone 1 • Kampar - Tronoh Mines';
      case 'kampar_zone_2':
        return 'Zone 2 • Kampar - Bandar Baru';
      case 'kampar_zone_3':
        return 'Zone 3 • Kampar Barat - Jeram';
      case 'kampar_zone_4':
        return 'Zone 4 • Gopeng';
      default:
        return zoneId;
    }
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: maxLines == 1 ? Icon(icon) : null,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF35C76F),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
