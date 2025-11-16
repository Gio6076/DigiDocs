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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Event added successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: const Color(0xFF2196F3),
      ),
    );
  }

  Future<void> _deleteEvent(int id) async {
    await db.deleteEvent(id);
    await db.insertAuditLog(widget.user['username'], 'delete_event:$id');
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text('Calendar',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF2196F3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Calendar and Add Event Side by Side
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Section
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Calendar',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020),
                                lastDay: DateTime.utc(2035),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (d) =>
                                    isSameDay(_selectedDay, d),
                                onDaySelected: (sel, foc) {
                                  setState(() {
                                    _selectedDay = sel;
                                    _focusedDay = foc;
                                  });
                                },
                                eventLoader: _eventsForDay,
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  headerPadding:
                                      EdgeInsets.symmetric(vertical: 8),
                                  leftChevronPadding: EdgeInsets.zero,
                                  rightChevronPadding: EdgeInsets.zero,
                                  titleTextStyle: TextStyle(fontSize: 14),
                                ),
                                calendarStyle: CalendarStyle(
                                  todayDecoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: const BoxDecoration(
                                    color: Color(0xFF2196F3),
                                    shape: BoxShape.circle,
                                  ),
                                  defaultTextStyle:
                                      const TextStyle(fontSize: 12),
                                ),
                                daysOfWeekStyle: const DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(fontSize: 12),
                                  weekendStyle: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Add Event Section
                  Expanded(
                    flex: 1,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add New Event',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedDay == null
                                  ? 'Select a date on the calendar'
                                  : 'Selected: ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedDay == null
                                    ? Colors.grey
                                    : const Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: titleCtrl,
                              decoration: InputDecoration(
                                labelText: 'Event title',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descCtrl,
                              decoration: InputDecoration(
                                labelText: 'Description (optional)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedDay == null
                                      ? Colors.grey
                                      : const Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed:
                                    _selectedDay == null ? null : _addEvent,
                                child: const Text('Add Event',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Events List Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.list, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDay == null
                              ? 'All Events'
                              : 'Events on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200, // Fixed height for events list
                      child: (_selectedDay == null
                                  ? []
                                  : _eventsForDay(_selectedDay!))
                              .isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event_busy,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedDay == null
                                        ? 'Select a date to view events'
                                        : 'No events scheduled',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _eventsForDay(_selectedDay!).length,
                              itemBuilder: (_, i) {
                                final e = _eventsForDay(_selectedDay!)[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA000)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.event,
                                          color: Color(0xFFFFA000), size: 18),
                                    ),
                                    title: Text(
                                      e['eventName'] ?? 'Untitled Event',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: e['description'] != null &&
                                            e['description']
                                                .toString()
                                                .isNotEmpty
                                        ? Text(
                                            e['description'].toString(),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: IconButton(
                                      icon: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(Icons.delete,
                                            color: Colors.red, size: 16),
                                      ),
                                      onPressed: () =>
                                          _deleteEvent(e['id'] as int),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    dense: true,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
