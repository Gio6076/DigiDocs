import 'package:flutter/material.dart';
import 'db_service.dart';

class NotesPage extends StatefulWidget {
  final Map<String, dynamic> user;
  NotesPage({required this.user});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseService dbService = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final db = await dbService.dbHelper.database;
    await db.execute(
        'CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, content TEXT, createdAt TEXT)');
    final notes = await db.query(
      'notes',
      where: 'userId = ?',
      whereArgs: [widget.user['id']],
      orderBy: 'id DESC',
    );
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _saveNote() async {
    final db = await dbService.dbHelper.database;
    await db.insert('notes', {
      'userId': widget.user['id'],
      'content': _controller.text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _controller.clear();
    _loadNotes();
  }

  Future<void> _deleteNote(int id) async {
    final db = await dbService.dbHelper.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type your note...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveNote,
              child: Text('Save Note'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return Card(
                    child: ListTile(
                      title: Text(note['content'] ?? ''),
                      subtitle: Text(note['createdAt'] ?? ''),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNote(note['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
