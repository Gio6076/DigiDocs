// lib/api_server.dart
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'db_service.dart';

class ApiServer {
  final DatabaseService _db = DatabaseService.instance;

  Future<void> start() async {
    final router = Router();

    // Home page
    router.get('/', (Request req) {
      return Response.ok('''
        <h1>DigiDocs Database Viewer</h1>
        <p><strong>Your data links:</strong></p>
        <ul>
          <li><a href="/notes">View Notes</a></li>
          <li><a href="/folders">View Folders</a></li>
          <li><a href="/documents">View Documents</a></li>
          <li><a href="/events">View Events</a></li>
          <li><a href="/users">View Users</a></li>
          <li><a href="/audit-logs">View Audit Logs</a></li>
        </ul>
      ''', headers: {'Content-Type': 'text/html'});
    });

    // Data endpoints - SIMPLE JSON
    router.get('/notes', (Request req) async {
      try {
        final notes = await _db.getNotes();
        return Response.ok(JsonEncoder.withIndent('  ').convert(notes),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    router.get('/folders', (Request req) async {
      try {
        final folders = await _db.getFolders();
        return Response.ok(JsonEncoder.withIndent('  ').convert(folders),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    router.get('/documents', (Request req) async {
      try {
        final documents = await _db.getDocuments();
        return Response.ok(JsonEncoder.withIndent('  ').convert(documents),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    router.get('/events', (Request req) async {
      try {
        final events = await _db.getEvents();
        return Response.ok(JsonEncoder.withIndent('  ').convert(events),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    router.get('/users', (Request req) async {
      try {
        final users = await _db.getUsers();
        return Response.ok(JsonEncoder.withIndent('  ').convert(users),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    // AUDIT LOGS ENDPOINT - Added this
    router.get('/audit-logs', (Request req) async {
      try {
        final auditLogs = await _db.getAuditLogs();
        return Response.ok(JsonEncoder.withIndent('  ').convert(auditLogs),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.ok('Error: $e');
      }
    });

    // Start server with error handling
    try {
      final server =
          await shelf_io.serve(router, InternetAddress.loopbackIPv4, 8080);
      print('🎉 API SERVER RUNNING!');
      print('🌐 Open your browser and go to: http://localhost:8080');
      print('📊 You can now view your database data!');
      print('   - Notes: http://localhost:8080/notes');
      print('   - Folders: http://localhost:8080/folders');
      print('   - Documents: http://localhost:8080/documents');
      print('   - Events: http://localhost:8080/events');
      print('   - Users: http://localhost:8080/users');
      print('   - Audit Logs: http://localhost:8080/audit-logs');
    } catch (e) {
      print('❌ Could not start API server: $e');
      rethrow;
    }
  }
}
