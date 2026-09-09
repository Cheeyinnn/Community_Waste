import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/collector_application_service.dart';
import '../../services/admin_user_management_service.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectorApplicationService _collectorService =
      CollectorApplicationService();
  final AdminUserManagementService _userManagementService =
      AdminUserManagementService();
  final TextEditingController _searchController = TextEditingController();

  String _roleFilter = 'All';
  String _statusFilter = 'All';
  String _searchText = '';
  String _busyUserId = '';

  static const Map<String, String> _zones = {
    'kampar_zone_1': 'Zone 1 • Kampar - Tronoh Mines',
    'kampar_zone_2': 'Zone 2 • Kampar - Bandar Baru',
    'kampar_zone_3': 'Zone 3 • Kampar Barat - Jeram',
    'kampar_zone_4': 'Zone 4 • Gopeng',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayRole(AppUser user) {
    if (user.role.trim().toLowerCase() == 'admin') {
      return 'Admin';
    }

    if (user.role.trim().toLowerCase() == 'collector' ||
        user.collectorApplicationStatus == 'suspended') {
      return 'Collector';
    }

    return 'User';
  }

  String _displayStatus(AppUser user) {
    if (user.isAccountSuspended) {
      return 'Account Suspended';
    }

    if (user.collectorApplicationStatus == 'suspended') {
      return 'Collector Suspended';
    }

    return 'Active';
  }

  String _statusCategory(AppUser user) {
    return _displayStatus(user) == 'Active' ? 'Active' : 'Suspended';
  }

  bool _isNormalUser(AppUser user) {
    return _displayRole(user) == 'User';
  }

  bool _isActiveCollector(AppUser user) {
    return user.role.trim().toLowerCase() == 'collector' &&
        user.collectorApplicationStatus == 'approved';
  }

  bool _isSuspendedCollector(AppUser user) {
    return user.collectorApplicationStatus == 'suspended';
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    final query = _searchText.trim().toLowerCase();

    final filtered = users.where((user) {
      final displayRole = _displayRole(user);
      final displayStatus = _displayStatus(user);
      final statusCategory = _statusCategory(user);

      if (_roleFilter != 'All' && displayRole != _roleFilter) {
        return false;
      }

      if (_statusFilter != 'All' && statusCategory != _statusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final searchable = [
        user.effectiveDisplayName,
        user.email,
        displayRole,
        displayStatus,
        user.accountSuspensionReason,
        user.collectorApplicationStatus,
        ...user.assignedCollectionZoneIds.map(_zoneDisplayName),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final roleCompare = _roleOrder(_displayRole(a))
          .compareTo(_roleOrder(_displayRole(b)));
      if (roleCompare != 0) return roleCompare;

      return a.effectiveDisplayName.toLowerCase().compareTo(
            b.effectiveDisplayName.toLowerCase(),
          );
    });

    return filtered;
  }

  int _roleOrder(String role) {
    switch (role) {
      case 'Admin':
        return 0;
      case 'Collector':
        return 1;
      case 'User':
      default:
        return 2;
    }
  }

  String _zoneDisplayName(String zoneId) {
    return _zones[zoneId] ?? zoneId;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  Future<void> _showUserDetails(AppUser user) async {
    final role = _displayRole(user);
    final status = _displayStatus(user);
    final photoUrl = user.effectiveProfileImageUrl;
    final currentAdminId = _auth.currentUser?.uid ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundColor: _roleColor(role).withOpacity(0.12),
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Icon(
                              _roleIcon(role),
                              color: _roleColor(role),
                              size: 31,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.effectiveDisplayName.trim().isEmpty
                                ? 'User'
                                : user.effectiveDisplayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _detailRow('Role', role),
                _detailRow('Status', status),
                if (user.isAccountSuspended &&
                    user.accountSuspensionReason.trim().isNotEmpty)
                  _detailRow(
                    'Suspension Reason',
                    user.accountSuspensionReason,
                  ),
                if (user.collectorApplicationStatus.trim().isNotEmpty)
                  _detailRow(
                    'Collector Application',
                    _applicationStatusDisplay(
                      user.collectorApplicationStatus,
                    ),
                  ),
                _detailRow(
                  'Email Verification',
                  user.emailVerified ? 'Verified' : 'Not verified',
                ),
                if (user.assignedCollectionZoneIds.isNotEmpty)
                  _detailRow(
                    'Assigned Zones',
                    user.assignedCollectionZoneIds
                        .map(_zoneDisplayName)
                        .join('\n'),
                  ),
                if (user.preferredCollectionAreaName.trim().isNotEmpty)
                  _detailRow(
                    'Preferred Collection Area',
                    user.preferredCollectionAreaName,
                  ),
                if (user.uid == currentAdminId)
                  _detailRow('Session', 'Current Admin'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
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
            width: 138,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendUserAccount(AppUser user) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Suspend User Account?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.effectiveDisplayName} will be unable to access the application until an Admin reactivates the account.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'e.g. Repeated false reports',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.block_rounded),
              label: const Text('Suspend Account'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    await _runUserAction(
      user: user,
      action: () => _userManagementService.suspendUserAccount(
        userId: user.uid,
        reason: reason,
      ),
      successMessage:
          '${user.effectiveDisplayName}\'s User account has been suspended.',
    );
  }

  Future<void> _reactivateUserAccount(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Reactivate User Account?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Restore normal application access for ${user.effectiveDisplayName}?',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Reactivate Account'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _runUserAction(
      user: user,
      action: () => _userManagementService.reactivateUserAccount(
        userId: user.uid,
      ),
      successMessage:
          '${user.effectiveDisplayName}\'s User account has been reactivated.',
    );
  }

  Future<void> _suspendCollector(AppUser user) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Suspend Collector Access?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.effectiveDisplayName} will temporarily lose Collector access but can continue using the application as a normal User. Assigned collection zones will be kept for later reactivation.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'e.g. Temporary leave',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Suspend'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    await _runUserAction(
      user: user,
      action: () => _collectorService.suspendCollector(
        applicationId: user.uid,
        reason: reason,
      ),
      successMessage:
          '${user.effectiveDisplayName} has been suspended from Collector access.',
    );
  }

  Future<void> _reactivateCollector(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Reactivate Collector?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Restore Collector access for ${user.effectiveDisplayName}? The previously assigned collection zones will be restored.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Reactivate'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _runUserAction(
      user: user,
      action: () => _collectorService.reactivateCollector(
        applicationId: user.uid,
      ),
      successMessage:
          '${user.effectiveDisplayName} has been reactivated as a Collector.',
    );
  }

  Future<void> _demoteCollector(AppUser user) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Demote to User?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.effectiveDisplayName} will permanently return to a normal User account. Collector access and assigned collection zones will be removed. A new Collector application will be required in the future.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'e.g. Collector requested to leave the role',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Demote'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    await _runUserAction(
      user: user,
      action: () => _collectorService.demoteCollector(
        applicationId: user.uid,
        reason: reason,
      ),
      successMessage:
          '${user.effectiveDisplayName} has been demoted to a normal User account.',
    );
  }

  Future<void> _runUserAction({
    required AppUser user,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_busyUserId.isNotEmpty) return;

    setState(() {
      _busyUserId = user.uid;
    });

    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Unable to Complete Action',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              _cleanError(e),
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserId = '';
        });
      }
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.blue;
      case 'Collector':
        return Colors.orange;
      case 'User':
      default:
        return Colors.green;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'Admin':
        return Icons.admin_panel_settings_outlined;
      case 'Collector':
        return Icons.local_shipping_outlined;
      case 'User':
      default:
        return Icons.person_outline_rounded;
    }
  }

  String _applicationStatusDisplay(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'suspended':
        return 'Suspended';
      case 'demoted':
        return 'Demoted';
      default:
        return status;
    }
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search name, email, role or zone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchText.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
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
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  label: 'Role',
                  value: _roleFilter,
                  items: const ['All', 'User', 'Collector', 'Admin'],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _roleFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown(
                  label: 'Status',
                  value: _statusFilter,
                  items: const ['All', 'Active', 'Suspended'],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _statusFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildUserCard(AppUser user) {
    final role = _displayRole(user);
    final status = _displayStatus(user);
    final roleColor = _roleColor(role);
    final isBusy = _busyUserId == user.uid;
    final currentAdminId = _auth.currentUser?.uid ?? '';
    final photoUrl = user.effectiveProfileImageUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
                backgroundColor: roleColor.withOpacity(0.12),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Icon(
                        _roleIcon(role),
                        color: roleColor,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.effectiveDisplayName.trim().isEmpty
                          ? 'User'
                          : user.effectiveDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
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
              _badge(
                text: role,
                color: roleColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                text: status,
                color: status == 'Account Suspended'
                    ? Colors.red.shade700
                    : status == 'Collector Suspended'
                        ? Colors.orange.shade800
                        : Colors.green,
                icon: status == 'Account Suspended'
                    ? Icons.block_rounded
                    : status == 'Collector Suspended'
                        ? Icons.pause_circle_outline_rounded
                        : Icons.check_circle_outline_rounded,
              ),
              if (user.uid == currentAdminId)
                _badge(
                  text: 'Current Admin',
                  color: Colors.blueGrey,
                  icon: Icons.verified_user_outlined,
                ),
            ],
          ),
          if (role == 'Collector' &&
              user.assignedCollectionZoneIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 17,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    user.assignedCollectionZoneIds
                        .map(_zoneDisplayName)
                        .join(', '),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 15),
          if (isBusy)
            const SizedBox(
              width: double.infinity,
              height: 44,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue,
                  ),
                ),
              ),
            )
          else
            _buildActions(user),
        ],
      ),
    );
  }

  Widget _buildActions(AppUser user) {
    final activeCollector = _isActiveCollector(user);
    final suspendedCollector = _isSuspendedCollector(user);
    final normalUser = _isNormalUser(user);
    final accountSuspended = user.isAccountSuspended;

    // Admin accounts are view-only in this screen.
    if (user.role.trim().toLowerCase() == 'admin') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showUserDetails(user),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('View Details'),
        ),
      );
    }

    // Normal User account controls.
    if (normalUser && !suspendedCollector) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showUserDetails(user),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Details'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: accountSuspended
                ? ElevatedButton.icon(
                    onPressed: () => _reactivateUserAccount(user),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Reactivate Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _suspendUserAccount(user),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
          ),
        ],
      );
    }

    // Collector controls.
    if (activeCollector || suspendedCollector) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showUserDetails(user),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Details'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: suspendedCollector
                    ? ElevatedButton.icon(
                        onPressed: () => _reactivateCollector(user),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Reactivate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(44),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _suspendCollector(user),
                        icon: const Icon(Icons.pause_circle_outline_rounded),
                        label: const Text('Suspend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _demoteCollector(user),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Demote'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade200),
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showUserDetails(user),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('View Details'),
      ),
    );
  }

  Widget _badge({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
          'User Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load users.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final users = (snapshot.data?.docs ?? const [])
                    .map((doc) => AppUser.fromMap(doc.data(), doc.id))
                    .toList();
                final filteredUsers = _filterUsers(users);

                if (filteredUsers.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(28),
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        Icons.person_search_outlined,
                        size: 76,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No users match the selected filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 350),
                    );
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 2, 18, 110),
                    itemCount: filteredUsers.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'} found',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      return _buildUserCard(filteredUsers[index - 1]);
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
}
