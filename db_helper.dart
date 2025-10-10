// lib/db_helper.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion = 2; // bump when schema changes

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;
    final dbPath = await databaseFactory.getDatabasesPath();
    final pathStr = join(dbPath, 'digidocs.db');

    _database = await databaseFactory.openDatabase(pathStr,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ));
    return _database!;
  }

  Future _onCreate(Database db, int version) async {
    // Create all tables (initial schema)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT,
        password TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        author TEXT,
        tags TEXT,
        filePath TEXT,
        uploadedAt TEXT,
        folderId INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE calendar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventName TEXT,
        eventDate TEXT,
        description TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT,
        action TEXT,
        timestamp TEXT
      )
    ''');

    // default admin
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'role': 'admin',
    });
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Safe upgrade strategy: attempt CREATE TABLE IF NOT EXISTS and ALTER TABLE for new columns.
    // This is defensive to avoid breaking existing DBs.
    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, password TEXT, role TEXT)');
    } catch (_) {}

    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, createdAt TEXT)');
    } catch (_) {}

    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, author TEXT, tags TEXT, filePath TEXT, uploadedAt TEXT, folderId INTEGER)');
    } catch (_) {}

    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, createdAt TEXT)');
    } catch (_) {}

    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS calendar (id INTEGER PRIMARY KEY AUTOINCREMENT, eventName TEXT, eventDate TEXT, description TEXT)');
    } catch (_) {}

    try {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, action TEXT, timestamp TEXT)');
    } catch (_) {}

    // Example: if we later add columns, we can attempt ALTER (wrapped in try/catch)
    // try {
    //   await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
    // } catch (_) {}
  }
}
