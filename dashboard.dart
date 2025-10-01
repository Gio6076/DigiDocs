import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'db_service.dart';
import 'main.dart';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  Dashboard({required this.user});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final DatabaseService dbService = DatabaseService();
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  void _performSearch() async {
    final results = await dbService.searchDocuments(searchController.text);
    setState(() {
      searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.user['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${widget.user['name']}"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () async {
              await dbService.logAction(
                widget.user['id'],
                "logout",
                "${widget.user['name']} logged out",
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔎 Search Bar
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search documents...",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _performSearch,
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            SizedBox(height: 20),

            if (searchResults.isNotEmpty) ...[
              Text("Search Results",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final doc = searchResults[index];
                  return ListTile(
                    title: Text(doc['title']),
                    subtitle: Text(
                        "Author: ${doc['author'] ?? 'N/A'} | Tags: ${doc['tags'] ?? ''}"),
                    trailing: Wrap(
                      spacing: 10,
                      children: [
                        IconButton(
                          icon: Icon(Icons.open_in_new, color: Colors.blue),
                          onPressed: () async {
                            await OpenFilex.open(doc['filePath']);
                            await dbService.logAction(
                              widget.user['id'],
                              "download",
                              "Opened file: ${doc['title']}",
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await dbService.deleteDocument(doc['id']);
                            await dbService.logAction(
                              widget.user['id'],
                              "delete",
                              "Deleted file: ${doc['title']}",
                            );
                            _performSearch(); // refresh search
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(),
            ],

            Text("File Management",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              children: [
                // Upload File
                ElevatedButton(
                  onPressed: () async {
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
                        widget.user['id'],
                        "upload",
                        "Uploaded file: ${file.name}",
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text("File '${file.name}' uploaded successfully!")),
                      );
                    }
                  },
                  child: Text("Upload File"),
                ),
                SizedBox(width: 10),

                // Download File
                ElevatedButton(
                  onPressed: () async {
                    final docs = await dbService.getDocuments();
                    if (docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("No documents available.")),
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("Select a file to open"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              return ListTile(
                                title: Text(doc['title']),
                                subtitle: Text("Uploaded: ${doc['uploadedAt']}"),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await OpenFilex.open(doc['filePath']);
                                  await dbService.logAction(
                                    widget.user['id'],
                                    "download",
                                    "Opened file: ${doc['title']}",
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text("Download File"),
                ),
                SizedBox(width: 10),

                // Delete File
                ElevatedButton(
                  onPressed: () async {
                    final docs = await dbService.getDocuments();
                    if (docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("No documents available.")),
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text("Select a file to delete"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              return ListTile(
                                title: Text(doc['title']),
                                subtitle: Text("Uploaded: ${doc['uploadedAt']}"),
                                trailing: Icon(Icons.delete, color: Colors.red),
                                onTap: () async {
                                  await dbService.deleteDocument(doc['id']);
                                  await dbService.logAction(
                                    widget.user['id'],
                                    "delete",
                                    "Deleted file: ${doc['title']}",
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            "File '${doc['title']}' deleted.")),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text("Delete File"),
                ),
              ],
            ),
            SizedBox(height: 30),

            if (isAdmin) ...[
              Text("Admin Controls",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              // Add User
              ElevatedButton(
                onPressed: () => _showAddUserDialog(),
                child: Text("Add New User"),
              ),
              SizedBox(height: 10),

              // View Audit Logs
              ElevatedButton(
                onPressed: () async {
                  final logs = await dbService.getAuditLogs();
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Audit Logs"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return ListTile(
                              title: Text(
                                  "${log['action']} - ${log['details']}"),
                              subtitle: Text(
                                  "UserID: ${log['userId']} at ${log['createdAt']}"),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: Text("View Audit Logs"),
              ),
              SizedBox(height: 10),

              // Manage Users
              ElevatedButton(
                onPressed: () async {
                  final users = await dbService.getUsers();
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Manage Users"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return ListTile(
                              title: Text("${user['name']} (${user['role']})"),
                              subtitle: Text(user['email']),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  if (user['id'] == widget.user['id']) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              "You cannot delete your own account!")),
                                    );
                                    return;
                                  }
                                  await dbService.deleteUser(user['id']);
                                  await dbService.logAction(
                                    widget.user['id'],
                                    "delete_user",
                                    "Deleted user: ${user['name']} (${user['email']})",
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: Text("Manage Users"),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Add User Dialog
  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = "user";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add New User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Name")),
            TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email")),
            TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true),
            DropdownButton<String>(
              value: role,
              items: ["user", "admin"]
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) => setState(() => role = value!),
            )
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await db
