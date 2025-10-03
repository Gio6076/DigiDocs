import 'package:flutter/material.dart';
import 'db_service.dart';
import 'login_page.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  Dashboard({required this.user});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final DatabaseService dbService = DatabaseService();
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> users = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    documents = await dbService.getDocuments();
    logs = await dbService.getLogs();
    if (widget.user['role'] == 'admin') {
      users = await dbService.getUsers();
    }
    setState(() {});
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      await dbService.insertDocument({
        'title': file.name,
        'author': widget.user['name'],
        'tags': '',
        'filePath': file.path!,
        'uploadedAt': DateTime.now().toIso8601String(),
      });
      await dbService.logAction(
          widget.user['id'], "upload", "Uploaded file: ${file.name}");
      _loadData();
    }
  }

  Future<void> _downloadFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await Process.run('explorer', [file.path]);
      await dbService.logAction(
          widget.user['id'], "download", "Downloaded file: ${file.path}");
    }
  }

  Future<void> _deleteFile(int id, String title) async {
    await dbService.deleteDocument(id);
    await dbService.logAction(
        widget.user['id'], "delete", "Deleted file: $title");
    _loadData();
  }

  Future<void> _addUser() async {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController passCtrl = TextEditingController();
    String role = 'user';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: "Name")),
            TextField(
                controller: emailCtrl,
                decoration: InputDecoration(labelText: "Email")),
            TextField(
                controller: passCtrl,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true),
            DropdownButton<String>(
              value: role,
              onChanged: (val) => role = val!,
              items: ['user', 'admin']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await dbService.addUser(
                  nameCtrl.text, emailCtrl.text, passCtrl.text, role);
              await dbService.logAction(widget.user['id'], "add_user",
                  "Added user: ${emailCtrl.text}");
              Navigator.pop(ctx);
              _loadData();
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int id, String email) async {
    await dbService.deleteUser(id);
    await dbService.logAction(
        widget.user['id'], "delete_user", "Deleted user: $email");
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = documents
        .where((doc) =>
            doc['title'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("DigiDocs Dashboard (${widget.user['role']})"),
        actions: [
          IconButton(onPressed: _logout, icon: Icon(Icons.logout)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔍 Search
            Padding(
              padding: EdgeInsets.all(8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search documents...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
            // 📂 File Management
            ListTile(
                title: Text("File Management",
                    style: TextStyle(fontWeight: FontWeight.bold))),
            Row(
              children: [
                ElevatedButton(
                    onPressed: _uploadFile, child: Text("Upload File")),
              ],
            ),
            ...filteredDocs.map((doc) => ListTile(
                  title: Text(doc['title']),
                  subtitle: Text("By ${doc['author']} on ${doc['uploadedAt']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () => _downloadFile(doc['filePath']),
                          icon: Icon(Icons.download)),
                      IconButton(
                          onPressed: () => _deleteFile(doc['id'], doc['title']),
                          icon: Icon(Icons.delete)),
                    ],
                  ),
                )),
            Divider(),
            // 📜 Audit Logs
            ListTile(
                title: Text("Audit Logs",
                    style: TextStyle(fontWeight: FontWeight.bold))),
            ...logs.map((log) => ListTile(
                  title: Text("${log['action']}"),
                  subtitle: Text("${log['details']} at ${log['createdAt']}"),
                )),
            Divider(),
            // 👥 User Management (Admin only)
            if (widget.user['role'] == 'admin') ...[
              ListTile(
                  title: Text("User Management",
                      style: TextStyle(fontWeight: FontWeight.bold))),
              ElevatedButton(onPressed: _addUser, child: Text("Add User")),
              ...users.map((u) => ListTile(
                    title: Text(u['name']),
                    subtitle: Text("${u['email']} - ${u['role']}"),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteUser(u['id'], u['email']),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
