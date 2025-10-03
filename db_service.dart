import 'db_helper.dart';

class DatabaseService {
  final dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getDocuments() async {
    final db = await dbHelper.database;
    return await db.query('Documents');
  }

  Future<void> insertDocument(Map<String, dynamic> document) async {
    final db = await dbHelper.database;
    await db.insert('Documents', document);
  }

  Future<void> deleteDocument(int id) async {
    final db = await dbHelper.database;
    await db.delete('Documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> logAction(int userId, String action, String details) async {
    final db = await dbHelper.database;
    await db.insert('AuditLogs', {
      'userId': userId,
      'action': action,
      'details': details,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await dbHelper.database;
    return await db.query('AuditLogs', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await dbHelper.database;
    return await db.query('users');
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

  Future<void> deleteUser(int id) async {
    final db = await dbHelper.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
