import 'package:flutter/material.dart';
import 'db_service.dart';
import 'note_editor_page.dart';

class NotesPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const NotesPage({Key? key, required this.user}) : super(key: key);

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseService db = DatabaseService.instance;
  List<Map<String, dynamic>> notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    notes = await db.getNotes();
    setState(() {});
  }

  Future<void> _createNote() async {
    final titleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Note'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Note title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                await db.insertNote(title, '');
                Navigator.pop(ctx);
                await _loadNotes();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await db.deleteNote(id);
      await _loadNotes();
    }
  }

  void _openNoteEditor(Map<String, dynamic> note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(note: note),
      ),
    );
    await _loadNotes(); // refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNote,
          ),
        ],
      ),
      body: notes.isEmpty
          ? const Center(child: Text('No notes yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (ctx, i) {
                final note = notes[i];
                return ListTile(
                  title: Text(note['title'] ?? ''),
                  subtitle: Text(
                    (note['content'] as String).isEmpty
                        ? 'Empty note'
                        : note['content'].toString().length > 40
                            ? '${note['content'].toString().substring(0, 40)}...'
                            : note['content'].toString(),
                  ),
                  onTap: () => _openNoteEditor(note),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        _deleteNote(note['id'] as int, note['title'] as String),
                  ),
                );
              },
            ),
    );
  }
}
