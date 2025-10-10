// lib/db_service.dart
import 'db_helper.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  DatabaseService();

  // -------- AUTH --------
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await _dbHelper.database;
    final res = await db.query('users',
        where: 'username = ? AND password = ?',
        whereArgs: [username, password]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await _dbHelper.database;
    return await db.query('users', orderBy: 'id ASC');
  }

  Future<int> addUser(String username, String password, String role) async {
    final db = await _dbHelper.database;
    return await db.insert('users', {
      'username': username,
      'password': password,
      'role': role,
    });
  }

  Future<void> deleteUser(int id) async {
    final db = await _dbHelper.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // -------- FOLDERS --------
  Future<int> createFolder(String name) async {
    final db = await _dbHelper.database;
    return await db.insert('folders',
        {'name': name, 'createdAt': DateTime.now().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    final db = await _dbHelper.database;
    return await db.query('folders', orderBy: 'createdAt DESC');
  }

  Future<void> deleteFolder(int id) async {
    final db = await _dbHelper.database;
    // delete files in folder first
    await db.delete('documents', where: 'folderId = ?', whereArgs: [id]);
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // -------- DOCUMENTS / FILES --------
  Future<int> insertDocument(Map<String, dynamic> doc) async {
    final db = await _dbHelper.database;
    return await db.insert('documents', doc);
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final db = await _dbHelper.database;
    // unassigned files (folderId IS NULL)
    return await db.query('documents',
        where: 'folderId IS NULL', orderBy: 'uploadedAt DESC');
  }

  Future<List<Map<String, dynamic>>> getFilesInFolder(int folderId) async {
    final db = await _dbHelper.database;
    return await db.query('documents',
        where: 'folderId = ?',
        whereArgs: [folderId],
        orderBy: 'uploadedAt DESC');
  }

  Future<void> moveFileToFolder(int fileId, int? folderId) async {
    final db = await _dbHelper.database;
    await db.update('documents', {'folderId': folderId},
        where: 'id = ?', whereArgs: [fileId]);
  }

  Future<void> deleteDocument(int id) async {
    final db = await _dbHelper.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // -------- NOTES --------
  Future<int> insertNote(String title, String content) async {
    final db = await _dbHelper.database;
    return await db.insert('notes', {
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await _dbHelper.database;
    return await db.query('notes', orderBy: 'createdAt DESC');
  }

  Future<void> deleteNote(int id) async {
    final db = await _dbHelper.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // -------- CALENDAR / EVENTS --------
  Future<int> insertEvent(
      String name, String dateIso, String description) async {
    final db = await _dbHelper.database;
    return await db.insert('calendar', {
      'eventName': name,
      'eventDate': dateIso,
      'description': description,
    });
  }

  Future<List<Map<String, dynamic>>> getEvents() async {
    final db = await _dbHelper.database;
    return await db.query('calendar', orderBy: 'eventDate ASC');
  }

  Future<void> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    await db.delete('calendar', where: 'id = ?', whereArgs: [id]);
  }

  // -------- AUDIT --------
  Future<int> insertAuditLog(String username, String action) async {
    final db = await _dbHelper.database;
    return await db.insert('audit_logs', {
      'username': username,
      'action': action,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await _dbHelper.database;
    return await db.query('audit_logs', orderBy: 'timestamp DESC');
  }
}
