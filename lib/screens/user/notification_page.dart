import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/waste_report.dart';
import '../../services/firestore_service.dart';
import 'report_detail_screen.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirestoreService firestoreService = FirestoreService();
  bool _markedAsRead = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markNotificationsAsReadOnce();
    });
  }

  Future<void> _markNotificationsAsReadOnce() async {
    if (_markedAsRead) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'last_notification_read_${user.uid}',
      DateTime.now().toIso8601String(),
    );

    _markedAsRead = true;
  }

  void _goBackToHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _openReportDetail(WasteReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          report: report,
          isAdmin: false,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    _goBackToHome();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: _goBackToHome,
          ),
          title: const Text(
            "Notifications",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
        ),
        body: user == null
            ? const Center(
                child: Text("Please log in to see updates"),
              )
            : StreamBuilder<List<WasteReport>>(
                stream: firestoreService.getUserReports(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final reports = snapshot.data ?? [];

                  final updates = reports
                      .where((r) => r.status != 'Pending')
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                  if (updates.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    physics: const ClampingScrollPhysics(),
                    itemCount: updates.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(
                        context,
                        updates[index],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, WasteReport report) {
    String message = "";
    IconData iconData = Icons.notifications_active_rounded;
    Color themeColor = Colors.blue;

    switch (report.status) {
      case 'Assigned':
        message = "A collector has been assigned to your report.";
        iconData = Icons.person_search_rounded;
        themeColor = Colors.deepPurple;
        break;
      case 'In Progress':
        message = "A collector is currently handling your report.";
        iconData = Icons.local_shipping_rounded;
        themeColor = Colors.blue;
        break;
      case 'Resolved':
        message = "Great news! Your waste report has been resolved.";
        iconData = Icons.check_circle_rounded;
        themeColor = Colors.green;
        break;
      case 'Rejected':
        message = "Your report was rejected. Check details for remarks.";
        iconData = Icons.cancel_rounded;
        themeColor = Colors.red;
        break;
      default:
        message = "There is an update on your report.";
        break;
    }

    String dateString = "-";

    try {
      dateString = DateFormat('MMM d, h:mm a').format(
        report.updatedAt.toDate(),
      );
    } catch (e) {
      dateString = "-";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openReportDetail(report),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              report.status,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            Text(
                              dateString,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            "All quiet here",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll get notified when your\nreports are updated.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}