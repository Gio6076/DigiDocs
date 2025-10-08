import 'package:flutter/material.dart';
import 'db_service.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  final Map<String, dynamic> user;
  CalendarPage({required this.user});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final DatabaseService dbService = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _markedDates = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final db = await dbService.dbHelper.database;
    await db.execute(
        'CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, title TEXT, eventDate TEXT)');

    final events = await db.query(
      'events',
      where: 'userId = ?',
      whereArgs: [widget.user['id']],
      orderBy: 'eventDate ASC',
    );

    Map<DateTime, List<String>> marked = {};
    for (var e in events) {
      final dateStr = e['eventDate'] as String? ?? '';
      if (dateStr.isEmpty) continue;

      DateTime d = DateTime.parse(dateStr).toLocal();
      marked[d] = marked[d] ?? [];
      marked[d]!.add(e['title'] as String? ?? '');
    }

    setState(() {
      _events = events;
      _markedDates = marked;
    });
  }

  Future<void> _saveEvent() async {
    if (_controller.text.isEmpty || _selectedDay == null) return;

    final db = await dbService.dbHelper.database;
    await db.insert('events', {
      'userId': widget.user['id'],
      'title': _controller.text,
      'eventDate': _selectedDay!.toIso8601String(),
    });
    _controller.clear();
    _loadEvents();
  }

  Future<void> _deleteEvent(int id) async {
    final db = await dbService.dbHelper.database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
    _loadEvents();
  }

  List<String> _getEventsForDay(DateTime day) {
    return _markedDates[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calendar Events')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // 🗓 Mini Calendar
            Container(
              width: 350,
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final dayEvents = _getEventsForDay(day);
                    if (dayEvents.isNotEmpty) {
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),

            SizedBox(width: 20),

            // 📝 Event List & Add Event
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Add new event...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _saveEvent,
                    child: Text('Save Event'),
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final title = event['title'] as String? ?? '';
                        final dateStr = event['eventDate'] as String? ?? '';
                        return Card(
                          child: ListTile(
                            title: Text(title),
                            subtitle: Text(dateStr),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEvent(event['id'] as int),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
