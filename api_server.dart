// lib/api_server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'db_service.dart';

class ApiServer {
  final _db = DatabaseService();

  Future<void> start() async {
    final router = Router();

    // Root endpoint
    router.get('/', (Request req) {
      return Response.ok('DigiDocs Local API is running 🚀');
    });

    // Get all notes
    router.get('/notes', (Request req) async {
      final notes = await _db.getNotes();
      return Response.ok(notes.toString(),
          headers: {'Content-Type': 'application/json'});
    });

    // Add new note
    router.post('/notes', (Request req) async {
      final data = await req.readAsString();
      await _db.insertNote("New Note", data);
      return Response.ok('Note added successfully!');
    });

    // Get all folders
    router.get('/folders', (Request req) async {
      final folders = await _db.getFolders();
      return Response.ok(folders.toString(),
          headers: {'Content-Type': 'application/json'});
    });

    // Get all documents
    router.get('/documents', (Request req) async {
      final docs = await _db.getDocuments();
      return Response.ok(docs.toString(),
          headers: {'Content-Type': 'application/json'});
    });

    // Start the local server
    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router);

    final server = await serve(handler, InternetAddress.loopbackIPv4, 8080);
    print(
        '✅ DigiDocs API running on http://${server.address.host}:${server.port}');
  }
}
