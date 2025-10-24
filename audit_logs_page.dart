// lib/audit_logs_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';

class AuditLogsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const AuditLogsPage({Key? key, required this.user}) : super(key: key);

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final db = DatabaseService.instance;
  List<Map<String, dynamic>> logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    logs = await db.getAuditLogs();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🧾 Audit Logs',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadLogs,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh logs',
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No audit logs recorded yet.'))
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(log['action']),
                            subtitle: Text(
                                'By ${log['username']} on ${DateFormat('MMM dd, yyyy – hh:mm a').format(DateTime.parse(log['timestamp']))}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
