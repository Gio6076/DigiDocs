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

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService dbService = DatabaseService();
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> users = [];
  int? selectedFolderId;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _loadData() async {
    documents = await dbService.getDocuments();
    logs = await dbService.getLogs();
    folders = await dbService.getFolders(widget.user['id']);
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

  // Create folder
  Future<void> _createFolder() async {
    TextEditingController folderCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Create New Folder"),
        content: TextField(
          controller: folderCtrl,
          decoration: InputDecoration(labelText: "Folder Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final folderId = await dbService.createFolder(
                  widget.user['id'], folderCtrl.text);
              await dbService.logAction(widget.user['id'], "create_folder",
                  "Created folder: ${folderCtrl.text}");
              Navigator.pop(ctx);
              setState(() => selectedFolderId = folderId);
              _loadData();
            },
            child: Text("Create"),
          ),
        ],
      ),
    );
  }

  // Upload file
  Future<void> _uploadFile({int? folderId}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      await dbService.insertDocument({
        'title': file.name,
        'author': widget.user['name'],
        'tags': '',
        'filePath': file.path!,
        'uploadedAt': DateTime.now().toIso8601String(),
        'folderId': folderId,
      });
      await dbService.logAction(
          widget.user['id'], "upload", "Uploaded file: ${file.name}");
      _loadData();
    }
  }

  Future<void> _deleteFolder(int id, String name) async {
    await dbService.deleteFolder(id);
    await dbService.logAction(
        widget.user['id'], "delete_folder", "Deleted folder: $name");
    if (selectedFolderId == id) selectedFolderId = null;
    _loadData();
  }

  Future<void> _deleteFile(int id, String title) async {
    await dbService.deleteDocument(id);
    await dbService.logAction(
        widget.user['id'], "delete", "Deleted file: $title");
    _loadData();
  }

  Future<void> _deleteUser(int id, String email) async {
    await dbService.deleteUser(id);
    await dbService.logAction(
        widget.user['id'], "delete_user", "Deleted user: $email");
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

  @override
  Widget build(BuildContext context) {
    final filteredDocs = documents
        .where((doc) =>
            selectedFolderId == null || doc['folderId'] == selectedFolderId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("DigiDocs Dashboard (${widget.user['role']})"),
        actions: [IconButton(onPressed: _logout, icon: Icon(Icons.logout))],
      ),
      body: Row(
        children: [
          // 🗂 Sidebar for Folders
          Container(
            width: 250,
            color: Colors.grey.shade200,
            child: Column(
              children: [
                ListTile(
                  title: Text("Folders",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                      icon: Icon(Icons.add), onPressed: _createFolder),
                ),
                Expanded(
                  child: ListView(
                    children: folders.map((f) {
                      return ListTile(
                        title: Text(f['name']),
                        selected: selectedFolderId == f['id'],
                        onTap: () =>
                            setState(() => selectedFolderId = f['id'] as int),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteFolder(
                              f['id'] as int, f['name'] as String),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (selectedFolderId != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadFile(folderId: selectedFolderId),
                      icon: Icon(Icons.upload_file),
                      label: Text("Upload to Folder"),
                    ),
                  ),
              ],
            ),
          ),

          VerticalDivider(width: 1),

          // 📝 Main Area with Tabs
          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.black,
                  tabs: [
                    Tab(text: "Files"),
                    Tab(text: "Audit Logs"),
                    if (widget.user['role'] == 'admin') Tab(text: "Users"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Files Tab
                      Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search files...",
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => setState(() {}),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                return ListTile(
                                  title: Text(doc['title']),
                                  subtitle: Text(
                                      "By ${doc['author']} on ${doc['uploadedAt']}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          onPressed: () => Process.run(
                                              'explorer', [doc['filePath']]),
                                          icon: Icon(Icons.download)),
                                      IconButton(
                                          onPressed: () => _deleteFile(
                                              doc['id'], doc['title']),
                                          icon: Icon(Icons.delete)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Audit Logs Tab
                      ListView(
                        children: logs.map((log) {
                          return ListTile(
                            title: Text("${log['action']}"),
                            subtitle: Text(
                                "${log['details']} at ${log['createdAt']}"),
                          );
                        }).toList(),
                      ),

                      // Users Tab (admin only)
                      if (widget.user['role'] == 'admin')
                        Column(
                          children: [
                            ElevatedButton(
                                onPressed: _addUser, child: Text("Add User")),
                            Expanded(
                              child: ListView(
                                children: users.map((u) {
                                  return ListTile(
                                    title: Text(u['name']),
                                    subtitle:
                                        Text("${u['email']} - ${u['role']}"),
                                    trailing: IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () =>
                                          _deleteUser(u['id'], u['email']),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
