import 'package:flutter/material.dart';
import 'login_page.dart';
import 'db_helper.dart';
import 'api_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start API server
  final api = ApiServer();
  api.start();

  // Initialize DB (this will create or upgrade db as needed)
  await DatabaseHelper.instance.database;
  runApp(DigiDocsApp());
}

class DigiDocsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiDocs',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
    );
  }
}
