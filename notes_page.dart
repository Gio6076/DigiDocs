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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create New Note',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Note title',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Note',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text('My Notes',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: _createNote,
          ),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to create your first note',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final note = notes[i];
                final content = note['content'] as String;
                final hasContent = content.isNotEmpty;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.note, color: Color(0xFF2196F3)),
                    ),
                    title: Text(
                      note['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          hasContent
                              ? (content.length > 60
                                  ? '${content.substring(0, 60)}...'
                                  : content)
                              : 'Empty note',
                          style: TextStyle(
                            color: hasContent
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        if (hasContent) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${content.split(' ').length} words • ${content.length} characters',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () => _openNoteEditor(note),
                    trailing: IconButton(
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.delete,
                            color: Colors.red, size: 18),
                      ),
                      onPressed: () => _deleteNote(
                          note['id'] as int, note['title'] as String),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
