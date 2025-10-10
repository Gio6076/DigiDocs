// lib/notes_page.dart
import 'package:flutter/material.dart';
import 'db_service.dart';

class NotesPage extends StatefulWidget {
  final Map<String, dynamic> user;
  NotesPage({required this.user});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final db = DatabaseService.instance;
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  List<Map<String, dynamic>> notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    notes = await db.getNotes();
    setState(() {});
  }

  Future<void> _addNote() async {
    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    if (content.isEmpty && title.isEmpty) return;
    await db.insertNote(title, content);
    await db.insertAuditLog(widget.user['username'], 'add_note');
    titleCtrl.clear();
    contentCtrl.clear();
    _load();
  }

  Future<void> _deleteNote(int id) async {
    await db.deleteNote(id);
    await db.insertAuditLog(widget.user['username'], 'delete_note:$id');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Title')),
            const SizedBox(height: 8),
            TextField(
                controller: contentCtrl,
                minLines: 3,
                maxLines: 8,
                decoration:
                    const InputDecoration(hintText: 'Write your note...')),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: _addNote, child: const Text('Save')),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: () {
                    titleCtrl.clear();
                    contentCtrl.clear();
                  },
                  child: const Text('Clear')),
            ]),
            const SizedBox(height: 12),
            Expanded(
                child: notes.isEmpty
                    ? const Center(child: Text('No notes yet'))
                    : ListView(
                        children: notes
                            .map((n) => Card(
                                child: ListTile(
                                    title: Text(n['title'] ?? ''),
                                    subtitle: Text(n['content'] ?? ''),
                                    trailing: IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () =>
                                            _deleteNote(n['id'] as int)))))
                            .toList()))
          ],
        ),
      ),
    );
  }
}
