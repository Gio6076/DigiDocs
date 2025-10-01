import 'db_helper.dart';
import 'dart:io';

class DatabaseService {
  final dbHelper = DatabaseHelper();

  // 🔑 Users
  Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> addUser(
      String name, String email, String password, String role) async {
    final db = await dbHelper.database;
    await db.insert('users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await dbHelper.database;
    return await db.query('users');
  }

  Future<void> deleteUser(int userId) async {
    final db = await dbHelper.database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  // 📂 Documents
  Future<void> insertDocument(Map<String, dynamic> document) async {
    final db = await dbHelper.database;
    await db.insert('Documents', document);
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final db = await dbHelper.database;
    return await db.query('Documents', orderBy: "uploadedAt DESC");
  }

  Future<void> deleteDocument(int id) async {
    final db = await dbHelper.database;
    await db.delete('Documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDocumentWithFile(int id, String filePath) async {
    final db = await dbHelper.database;
    await db.delete('Documents', where: 'id = ?', whereArgs: [id]);

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<Map<String, dynamic>>> searchDocuments(String query) async {
    final db = await dbHelper.database;
    return await db.query(
      'Documents',
      where: 'title LIKE ? OR author LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

  // 📝 Audit Logs
  Future<void> logAction(int userId, String action, String details) async {
    final db = await dbHelper.database;
    await db.insert('AuditLogs', {
      'userId': userId,
      'action': action,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await dbHelper.database;
    return await db.query('AuditLogs', orderBy: "createdAt DESC");
  }
}
