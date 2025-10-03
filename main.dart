import 'package:flutter/material.dart';
import 'login_page.dart';
import 'db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database; // initialize DB
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
