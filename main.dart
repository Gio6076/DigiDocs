// lib/main.dart
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'db_helper.dart';
import 'api_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Starting DigiDocs App...');

  // Initialize DB first
  await DatabaseHelper.instance.database;
  print('✅ Database initialized');

  // Start API server - FORCE IT TO START
  _startApiServer();

  // Run Flutter app
  runApp(DigiDocsApp());
}

void _startApiServer() {
  print('🔧 Attempting to start API server...');

  // Use a future to not block the Flutter app
  Future(() async {
    try {
      final api = ApiServer();
      await api.start();
    } catch (e) {
      print('❌ API Server failed: $e');
      print('💡 Try these solutions:');
      print('   1. Port 8080 might be busy - wait a moment');
      print('   2. Restart the app');
      print('   3. The Flutter app will still work without API');
    }
  });
}

class DigiDocsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DigiDocs',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
    );
  }
}
