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
    _autoSaveTimer = Timer(const Duration(milliseconds: 30), _autoSave);
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
        SnackBar(
          content: const Text('Note auto-saved'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF2196F3),
        ),
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
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: Text(
          widget.note['title'] ?? 'Untitled Note',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF2196F3),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Start typing your note here...',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.check),
      ),
    );
  }
}
