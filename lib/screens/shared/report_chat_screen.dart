import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/report_chat_message.dart';
import '../../services/report_chat_service.dart';

class ReportChatScreen extends StatefulWidget {
  final String reportId;
  final String reportTitle;
  final String reportLocation;
  final double reportLatitude;
  final double reportLongitude;

  /// Use "user", "collector", or "admin".
  final String currentRole;

  /// User-Collector is the public report clarification chat.
  /// Admin-Collector is a separate operational conversation.
  final ReportChatChannel channel;

  const ReportChatScreen({
    super.key,
    required this.reportId,
    required this.reportTitle,
    required this.reportLocation,
    required this.reportLatitude,
    required this.reportLongitude,
    required this.currentRole,
    this.channel = ReportChatChannel.userCollector,
  });

  @override
  State<ReportChatScreen> createState() => _ReportChatScreenState();
}

class _ReportChatScreenState extends State<ReportChatScreen> {
  static const Color _userPrimary = Color(0xFF35C76F);
  static const Color _collectorPrimary = Color(0xFFFFB547);
  static const Color _adminPrimary = Colors.blue;

  final ReportChatService _chatService = ReportChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _typingTimer;
  bool _isSending = false;
  bool _typingSent = false;

  Color get _rolePrimary {
    switch (widget.currentRole) {
      case 'collector':
        return _collectorPrimary;
      case 'admin':
        return _adminPrimary;
      case 'user':
      default:
        return _userPrimary;
    }
  }

  String get _roleLabel {
    switch (widget.currentRole) {
      case 'collector':
        return 'Collector';
      case 'admin':
        return 'Admin';
      case 'user':
      default:
        return 'User';
    }
  }

  bool get _isAdminAuditView =>
      widget.currentRole == 'admin' &&
      widget.channel == ReportChatChannel.userCollector;

  String get _otherRole {
    if (widget.channel == ReportChatChannel.adminCollector) {
      return widget.currentRole == 'collector' ? 'admin' : 'collector';
    }

    return widget.currentRole == 'collector' ? 'user' : 'collector';
  }

  String get _conversationTitle {
    if (widget.channel == ReportChatChannel.adminCollector) {
      return 'Admin & Collector';
    }

    if (_isAdminAuditView) {
      return 'User & Collector Conversation';
    }

    return 'Report Chat';
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();

    if (_typingSent) {
      _chatService.setTyping(
        reportId: widget.reportId,
        role: widget.currentRole,
        isTyping: false,
        channel: widget.channel,
      );
    }

    super.dispose();
  }

  bool _isChatOpen(String status) {
    return status == 'Assigned' ||
        status == 'In Progress' ||
        status == 'Completion Submitted';
  }

  String _chatStatusText(String status) {
    switch (status) {
      case 'Pending':
        return 'Chat opens after a Collector is assigned.';
      case 'Resolved':
        return 'This report is resolved. The conversation is read-only.';
      case 'Rejected':
        return 'This report was rejected. Messaging is closed.';
      default:
        return 'Messaging is currently unavailable.';
    }
  }

  void _handleTypingChanged(String value) {
    _typingTimer?.cancel();

    final hasText = value.trim().isNotEmpty;

    if (hasText && !_typingSent) {
      _typingSent = true;
      _chatService.setTyping(
        reportId: widget.reportId,
        role: widget.currentRole,
        isTyping: true,
        channel: widget.channel,
      );
    }

    if (!hasText && _typingSent) {
      _typingSent = false;
      _chatService.setTyping(
        reportId: widget.reportId,
        role: widget.currentRole,
        isTyping: false,
        channel: widget.channel,
      );
      return;
    }

    if (hasText) {
      _typingTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!_typingSent) return;

        _typingSent = false;
        _chatService.setTyping(
          reportId: widget.reportId,
          role: widget.currentRole,
          isTyping: false,
          channel: widget.channel,
        );
      });
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendText(
        reportId: widget.reportId,
        text: text,
        channel: widget.channel,
      );

      _messageController.clear();
      _typingTimer?.cancel();

      if (_typingSent) {
        _typingSent = false;
        _chatService.setTyping(
          reportId: widget.reportId,
          role: widget.currentRole,
          isTyping: false,
          channel: widget.channel,
        );
      }

      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_isSending) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1800,
    );

    if (picked == null || !mounted) {
      return;
    }

    final file = File(picked.path);
    final captionController = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Send Photo',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: captionController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Add a caption (optional)',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _rolePrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send'),
            ),
          ],
        );
      },
    );

    final caption = captionController.text.trim();
    captionController.dispose();

    if (shouldSend != true || !mounted) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendImage(
        reportId: widget.reportId,
        imageFile: file,
        caption: caption,
        channel: widget.channel,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _shareReportLocation() async {
    if (_isSending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Share Report Location?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            widget.reportLocation.trim().isEmpty
                ? 'Share the saved coordinates for this waste report?'
                : widget.reportLocation,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _rolePrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Share'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendReportLocation(
        reportId: widget.reportId,
        locationLabel: widget.reportLocation,
        latitude: widget.reportLatitude,
        longitude: widget.reportLongitude,
        channel: widget.channel,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _showAttachmentOptions() async {
    FocusScope.of(context).unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Share with Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _buildAttachmentTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photo from Gallery',
                  subtitle: 'Send a photo to clarify the report.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _buildAttachmentTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take Photo',
                  subtitle: 'Take and send a new photo.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentTile(
                  icon: Icons.location_on_outlined,
                  title: 'Report Location',
                  subtitle: 'Share the saved location for this report.',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _shareReportLocation();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _rolePrimary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _rolePrimary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey.shade400,
      ),
    );
  }

  Future<void> _openMap(ReportChatMessage message) async {
    final bool hasCoordinates =
        message.latitude.abs() > 0.000001 || message.longitude.abs() > 0.000001;

    final Uri uri;

    if (hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${message.latitude},${message.longitude}',
      );
    } else {
      final query = Uri.encodeComponent(message.locationLabel);
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showImagePreview(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('Chat Photo'),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 72,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }

  bool _otherParticipantIsTyping(
    Map<String, dynamic>? typingData,
  ) {
    if (typingData == null) return false;

    final isTyping = typingData['${_otherRole}Typing'] == true;
    final rawAt = typingData['${_otherRole}TypingAt'];

    if (!isTyping || rawAt is! Timestamp) {
      return false;
    }

    return DateTime.now().difference(rawAt.toDate()).inSeconds <= 5;
  }

  Widget _buildMessageBubble({
    required ReportChatMessage message,
    required String currentUid,
    required String otherParticipantId,
  }) {
    final isMine = message.isMine(currentUid);
    final Color senderColor;

    switch (message.senderRole) {
      case 'collector':
        senderColor = _collectorPrimary;
        break;
      case 'admin':
        senderColor = _adminPrimary;
        break;
      case 'user':
      default:
        senderColor = _userPrimary;
        break;
    }

    // In Admin audit mode, show User on the left and Collector on the
    // right even though neither message was sent by the viewing Admin.
    final alignRight = _isAdminAuditView
        ? message.senderRole == 'collector'
        : isMine;

    final bubbleColor = isMine
        ? senderColor
        : senderColor.withOpacity(0.10);

    final textColor = isMine ? Colors.white : Colors.black87;
    final isRead = widget.channel == ReportChatChannel.adminCollector &&
            message.senderRole == 'collector' &&
            widget.currentRole == 'collector'
        ? message.readBy.length > 1
        : otherParticipantId.isNotEmpty &&
            message.readBy.contains(otherParticipantId);

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: message.type == 'image'
            ? const EdgeInsets.all(6)
            : const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(alignRight ? 18 : 5),
            bottomRight: Radius.circular(alignRight ? 5 : 18),
          ),
          border: isMine
              ? null
              : Border.all(color: senderColor.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment:
              alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  message.senderName.isEmpty
                      ? (message.senderRole == 'collector'
                          ? 'Collector'
                          : message.senderRole == 'admin'
                              ? 'Administrator'
                              : 'User')
                      : message.senderName,
                  style: TextStyle(
                    color: senderColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (message.type == 'image') ...[
              GestureDetector(
                onTap: message.imageUrl.isEmpty
                    ? null
                    : () => _showImagePreview(message.imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: message.imageUrl.isEmpty
                        ? Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported_outlined),
                          )
                        : Image.network(
                            message.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;

                              return Container(
                                color: Colors.grey.shade100,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: senderColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              if (message.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 8, 7, 2),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
            ] else if (message.type == 'location') ...[
              InkWell(
                onTap: () => _openMap(message),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: isMine ? Colors.white : senderColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Location',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message.locationLabel.trim().isEmpty
                                  ? '${message.latitude}, ${message.longitude}'
                                  : message.locationLabel,
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white.withOpacity(0.88)
                                    : Colors.grey.shade700,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to open map',
                              style: TextStyle(
                                color: isMine
                                    ? Colors.white.withOpacity(0.92)
                                    : senderColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.5,
                  height: 1.38,
                ),
              ),
            const SizedBox(height: 5),
            Padding(
              padding: message.type == 'image'
                  ? const EdgeInsets.symmetric(horizontal: 7)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: TextStyle(
                      color: isMine
                          ? Colors.white.withOpacity(0.78)
                          : Colors.grey.shade500,
                      fontSize: 10.5,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: isRead
                          ? Colors.white
                          : Colors.white.withOpacity(0.72),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isRead ? 'Read' : 'Sent',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard({
    required String otherParticipantName,
    required String status,
  }) {
    final otherRoleLabel = _otherRole == 'admin'
        ? 'Administrator'
        : _otherRole == 'collector'
            ? 'Collector'
            : 'User';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _rolePrimary.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _rolePrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.forum_outlined,
              color: _rolePrimary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAdminAuditView
                      ? 'User & Collector Conversation'
                      : otherParticipantName.trim().isEmpty
                          ? 'Chat with $otherRoleLabel'
                          : 'Chat with $otherParticipantName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isAdminAuditView
                      ? 'View the report-specific conversation between the User and assigned Collector.'
                      : widget.channel == ReportChatChannel.adminCollector
                          ? 'Operational chat for Admin and the assigned Collector. ${widget.reportLocation}'
                          : widget.reportLocation.trim().isEmpty
                              ? 'Use this chat to clarify report details and access information.'
                              : widget.reportLocation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isChatOpen(status) ? 'Messaging active' : _chatStatusText(status),
                  style: TextStyle(
                    color: _isChatOpen(status)
                        ? _rolePrimary
                        : Colors.grey.shade600,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _rolePrimary,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${_otherRole == 'collector' ? 'Collector' : _otherRole == 'admin' ? 'Administrator' : 'User'} is typing...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer({
    required bool canSend,
  }) {
    if (!canSend) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Conversation is read-only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach',
              onPressed: _isSending ? null : _showAttachmentOptions,
              icon: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _rolePrimary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _rolePrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                onChanged: _handleTypingChanged,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: _rolePrimary.withOpacity(0.55),
                      width: 1.3,
                    ),
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 44,
              height: 44,
              child: FilledButton(
                onPressed: _isSending ? null : _sendText,
                style: FilledButton.styleFrom(
                  backgroundColor: _rolePrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.reportId)
          .snapshots(),
      builder: (context, reportSnapshot) {
        final reportData = reportSnapshot.data?.data();
        final status = reportData?['status']?.toString().trim() ?? '';
        final ownerId = reportData?['userId']?.toString().trim() ?? '';
        final collectorId =
            reportData?['collectorId']?.toString().trim() ?? '';
        final ownerName =
            reportData?['userName']?.toString().trim() ?? 'User';
        final collectorName =
            reportData?['collectorName']?.toString().trim() ?? 'Collector';

        final bool isParticipant;

        if (widget.channel == ReportChatChannel.adminCollector) {
          isParticipant = collectorId.isNotEmpty &&
              (widget.currentRole == 'admin' || currentUser.uid == collectorId);
        } else {
          isParticipant = _isAdminAuditView ||
              currentUser.uid == ownerId ||
              currentUser.uid == collectorId;
        }

        final canSend = !_isAdminAuditView &&
            isParticipant &&
            _isChatOpen(status);

        final String otherParticipantId;
        final String otherParticipantName;

        if (widget.channel == ReportChatChannel.adminCollector) {
          if (widget.currentRole == 'collector') {
            // The Admin UID is intentionally not stored on the report.
            otherParticipantId = '';
            otherParticipantName = 'Administrator';
          } else {
            otherParticipantId = collectorId;
            otherParticipantName = collectorName;
          }
        } else if (widget.currentRole == 'collector') {
          otherParticipantId = ownerId;
          otherParticipantName = ownerName;
        } else {
          otherParticipantId = collectorId;
          otherParticipantName = collectorName;
        }

        return Scaffold(
          backgroundColor: widget.currentRole == 'user'
              ? const Color(0xFFEFF8F6)
              : widget.currentRole == 'admin'
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFFFAF4),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _conversationTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.reportTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _rolePrimary.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _roleLabel,
                  style: TextStyle(
                    color: _rolePrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          body: !reportSnapshot.hasData
              ? Center(
                  child: CircularProgressIndicator(color: _rolePrimary),
                )
              : !isParticipant
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'You do not have access to this conversation.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _buildContextCard(
                          otherParticipantName: otherParticipantName,
                          status: status,
                        ),
                        Expanded(
                          child: StreamBuilder<List<ReportChatMessage>>(
                            stream: _chatService.watchMessages(
                              widget.reportId,
                              channel: widget.channel,
                            ),
                            builder: (context, messageSnapshot) {
                              if (messageSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !messageSnapshot.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: _rolePrimary,
                                  ),
                                );
                              }

                              if (messageSnapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Unable to load messages.\n'
                                      '${messageSnapshot.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                );
                              }

                              final messages =
                                  messageSnapshot.data ?? <ReportChatMessage>[];

                              if (!_isAdminAuditView) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _chatService.markMessagesRead(
                                    reportId: widget.reportId,
                                    messages: messages,
                                    channel: widget.channel,
                                  );
                                });
                              }

                              if (messages.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: _rolePrimary.withOpacity(0.10),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 34,
                                            color: _rolePrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          'No messages yet',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          canSend
                                              ? (widget.channel == ReportChatChannel.adminCollector
                                                  ? 'Start an operational conversation about this assigned report task.'
                                                  : 'Start the conversation to clarify the exact location or other report details.')
                                              : _chatStatusText(status),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                reverse: true,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  8,
                                  14,
                                  14,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  return _buildMessageBubble(
                                    message: messages[index],
                                    currentUid: currentUser.uid,
                                    otherParticipantId: otherParticipantId,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (canSend)
                          StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _chatService.watchTypingState(
                              widget.reportId,
                              channel: widget.channel,
                            ),
                            builder: (context, typingSnapshot) {
                              if (_otherParticipantIsTyping(
                                typingSnapshot.data?.data(),
                              )) {
                                return _buildTypingIndicator();
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        _buildComposer(canSend: canSend),
                      ],
                    ),
        );
      },
    );
  }
}
