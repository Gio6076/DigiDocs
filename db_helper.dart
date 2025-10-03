import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    _database = await _initDB('digidocs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await databaseFactoryFfi.getDatabasesPath();
    final path = join(dbPath, filePath);
    return await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ));
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT,
        password TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        tags TEXT,
        filePath TEXT NOT NULL,
        uploadedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE AuditLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        action TEXT NOT NULL,
        details TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // default admin
    await db.insert('users', {
      'name': 'Admin',
      'email': 'admin@digidocs.com',
      'password': 'admin123',
      'role': 'admin',
    });
  }
}
