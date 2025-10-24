import 'dart:async';
import 'package:flutter/material.dart';
import 'db_service.dart';

class NoteEditorPage extends StatefulWidget {
  final Map<String, dynamic> note;
  const NoteEditorPage({Key? key, required this.note}) : super(key: key);

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final DatabaseService db = DatabaseService.instance;
  late TextEditingController _controller;
  Timer? _autoSaveTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note['content'] ?? '');
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_isSaving) return;
    _isSaving = true;

    await db.updateNote(widget.note['id'], {
      'title': widget.note['title'],
      'content': _controller.text.trim(),
      'createdAt': widget.note['createdAt'],
    });

    _isSaving = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note auto-saved')),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note['title'] ?? 'Untitled Note'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Start typing your note here...',
          ),
        ),
      ),
    );
  }
}
