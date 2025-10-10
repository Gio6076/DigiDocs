// lib/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'db_service.dart';

class CalendarPage extends StatefulWidget {
  final Map<String, dynamic> user;
  CalendarPage({required this.user});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final db = DatabaseService.instance;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final rows = await db.getEvents();
    eventsMap.clear();
    for (var r in rows) {
      final dt = DateTime.tryParse(r['eventDate'] as String) ?? DateTime.now();
      final key = DateTime(dt.year, dt.month, dt.day);
      eventsMap[key] = eventsMap[key] ?? [];
      eventsMap[key]!.add(r);
    }
    setState(() {});
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return eventsMap[key] ?? [];
  }

  Future<void> _addEvent() async {
    if (titleCtrl.text.trim().isEmpty || _selectedDay == null) return;
    await db.insertEvent(titleCtrl.text.trim(), _selectedDay!.toIso8601String(),
        descCtrl.text.trim());
    await db.insertAuditLog(
        widget.user['username'], 'add_event:${titleCtrl.text.trim()}');
    titleCtrl.clear();
    descCtrl.clear();
    _loadEvents();
  }

  Future<void> _deleteEvent(int id) async {
    await db.deleteEvent(id);
    await db.insertAuditLog(widget.user['username'], 'delete_event:$id');
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              onDaySelected: (sel, foc) {
                setState(() {
                  _selectedDay = sel;
                  _focusedDay = foc;
                });
              },
              eventLoader: _eventsForDay,
            ),
            const SizedBox(height: 8),
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Event title')),
            const SizedBox(height: 8),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: _addEvent, child: const Text('Add Event')),
            const SizedBox(height: 12),
            Expanded(
                child: ListView(
                    children: (_selectedDay == null
                            ? []
                            : _eventsForDay(_selectedDay!))
                        .map((e) => Card(
                            child: ListTile(
                                title: Text(e['eventName'] ?? ''),
                                subtitle: Text(e['description'] ?? ''),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        _deleteEvent(e['id'] as int)))))
                        .toList())),
          ],
        ),
      ),
    );
  }
}
