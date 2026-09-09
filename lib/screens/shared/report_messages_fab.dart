import 'package:flutter/material.dart';

import '../../services/report_chat_service.dart';
import 'report_messages_screen.dart';

class ReportMessagesFab extends StatelessWidget {
  static const Color _userPrimary = Color(0xFF35C76F);
  static const Color _collectorPrimary = Color(0xFFFFB547);
  static const Color _adminPrimary = Colors.blue;

  final String currentRole;

  const ReportMessagesFab({
    super.key,
    required this.currentRole,
  });

  Color get _primary {
    if (currentRole == 'collector') return _collectorPrimary;
    if (currentRole == 'admin') return _adminPrimary;
    return _userPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ReportChatService();

    return StreamBuilder<int>(
      stream: chatService.watchGlobalUnreadCount(currentRole: currentRole),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton(
              heroTag: 'global_report_messages_fab_$currentRole',
              tooltip: 'Messages',
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 5,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportMessagesScreen(
                      currentRole: currentRole,
                    ),
                  ),
                );
              },
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 26,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: -5,
                top: -6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 23,
                    minHeight: 23,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : unread.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
