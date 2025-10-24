// lib/dashboard.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'notes_page.dart';
import 'calendar_page.dart';
import 'login_page.dart';
import 'pdf_viewer_page.dart';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const Dashboard({Key? key, required this.user}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseService db = DatabaseService.instance;

  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> users = [];

  int? selectedFolderId;
  String? selectedFolderName;
  late TabController _tabController;

  String searchQuery = ""; // ✅ for filtering files

  late List<Map<String, dynamic>> _frequentItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.user['role'] == 'admin' ? 3 : 2, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    folders = await db.getFolders();
    files = (selectedFolderId == null)
        ? await db.getDocuments()
        : await db.getFilesInFolder(selectedFolderId!);
    logs = await db.getAuditLogs();
    if (widget.user['role'] == 'admin') users = await db.getUsers();

    _frequentItems = await _getFrequentAccessedItems();
    setState(() {});
  }

  // ✅ Get top 5 most accessed items from audit logs
  Future<List<Map<String, dynamic>>> _getFrequentAccessedItems() async {
    final auditLogs = await db.getAuditLogs();
    final Map<String, int> accessCount = {};

    for (var log in auditLogs) {
      final action = log['action'] as String;
      if (action.startsWith('open_file:') ||
          action.startsWith('open_folder:')) {
        final name = action.split(':').last.trim();
        accessCount[name] = (accessCount[name] ?? 0) + 1;
      }
    }

    final sorted = accessCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) {
      final name = e.key;
      final isFolder = name.toLowerCase().contains('folder');
      return {'name': name, 'type': isFolder ? 'folder' : 'file'};
    }).toList();
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) {
                  await db.createFolder(name);
                  await db.insertAuditLog(
                      widget.user['username'], 'create_folder: $name');
                  Navigator.pop(ctx);
                  await _loadAll();
                }
              },
              child: const Text('Create')),
        ],
      ),
    );
  }

  Future<void> _uploadFile({int? folderId}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null) return;
    final f = result.files.single;
    if (f.path == null) return;

    final doc = {
      'title': f.name,
      'author': widget.user['username'],
      'tags': '',
      'filePath': f.path,
      'uploadedAt': DateTime.now().toIso8601String(),
      'folderId': folderId,
    };
    await db.insertDocument(doc);
    await db.insertAuditLog(
      widget.user['username'],
      folderId == null
          ? 'upload: ${f.name}'
          : 'upload: ${f.name} -> folder $folderId',
    );
    await _loadAll();
  }

  Future<void> _deleteFile(int id, String title) async {
    await db.deleteDocument(id);
    await db.insertAuditLog(widget.user['username'], 'delete_file: $title');
    await _loadAll();
  }

  Future<void> _openFolder(int folderId, String folderName) async {
    selectedFolderId = folderId;
    selectedFolderName = folderName;
    files = await db.getFilesInFolder(folderId);
    await db.insertAuditLog(
        widget.user['username'], 'open_folder: $folderName');
    setState(() {});
  }

  Future<void> _deleteFolder(int folderId, String folderName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete folder'),
        content:
            Text('Delete na brader"$folderName" and all documents inside?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await db.deleteFolder(folderId);
      await db.insertAuditLog(
          widget.user['username'], 'delete_folder: $folderName');
      selectedFolderId = null;
      selectedFolderName = null;
      await _loadAll();
    }
  }

  void _logout() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => LoginPage()));
  }

  Widget _fileTile(Map<String, dynamic> doc) {
    final uploadedAt = doc['uploadedAt'] ?? '';
    final shortDate = uploadedAt.isNotEmpty
        ? DateFormat.yMMMd().format(DateTime.parse(uploadedAt))
        : '';
    final filePath = doc['filePath'] as String? ?? '';

    return ListTile(
      leading: const Icon(Icons.insert_drive_file),
      title: Text(doc['title'] ?? ''),
      subtitle: Text('By ${doc['author'] ?? ''} • $shortDate'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Open file
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () async {
              if (filePath.isEmpty || !File(filePath).existsSync()) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File not found on disk')));
                return;
              }
              final ext = filePath.split('.').last.toLowerCase();

              await db.insertAuditLog(
                  widget.user['username'], 'open_file: ${doc['title']}');

              if (['txt', 'csv', 'md'].contains(ext)) {
                final content = await File(filePath).readAsString();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(doc['title']),
                    content: SizedBox(
                        width: 600,
                        height: 400,
                        child: SingleChildScrollView(child: Text(content))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close')),
                    ],
                  ),
                );
              } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(doc['title']),
                    content: SizedBox(
                        width: 600,
                        height: 400,
                        child: Image.file(File(filePath), fit: BoxFit.contain)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close')),
                    ],
                  ),
                );
              } else if (ext == 'pdf') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                        filePath: filePath,
                        title: doc['title'] ?? 'PDF Viewer'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Preview not supported for this file type')));
              }
            },
          ),

          // Download button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              if (filePath.isEmpty || !File(filePath).existsSync()) return;
              final outputDir = await FilePicker.platform.getDirectoryPath();
              if (outputDir == null) return;
              final destPath = '$outputDir/${doc['title']}';
              await File(filePath).copy(destPath);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File downloaded to $destPath')));
            },
          ),

          // Export dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.upload_rounded),
            onSelected: (value) async {
              final outputDir = await FilePicker.platform.getDirectoryPath();
              if (outputDir == null) return;
              final baseName =
                  doc['title']?.split('.').first ?? 'exported_file';
              String destPath = '';
              if (value == 'pdf') {
                destPath = '$outputDir/$baseName.pdf';
                await File(filePath).copy(destPath);
              } else if (value == 'docx') {
                destPath = '$outputDir/$baseName.docx';
                await File(filePath).copy(destPath);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported as .$value to $destPath')));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              const PopupMenuItem(value: 'docx', child: Text('Export as DOCX')),
            ],
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () =>
                _deleteFile(doc['id'] as int, doc['title'] as String),
          ),
        ],
      ),
    );
  }

  // ===========================
  // Storage Monitor
  // ===========================
  Future<int> _calculateStorageUsed() async {
    int total = 0;
    for (var file in files) {
      final path = file['filePath'] as String? ?? '';
      if (path.isNotEmpty && File(path).existsSync()) {
        total += File(path).lengthSync();
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    // Filtered files based on search query
    final displayedFiles = (selectedFolderId == null)
        ? files
        : files.where((f) => f['folderId'] == selectedFolderId).toList();

    final filteredFiles = displayedFiles
        .where((f) => f['title']
            .toString()
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('DigiDocs (${widget.user['username']})'),
        actions: [
          IconButton(
              icon: const Icon(Icons.note),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NotesPage(user: widget.user)))),
          IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CalendarPage(user: widget.user)))),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Row(
        children: [
          // =====================
          // Sidebar
          // =====================
          Container(
            width: 260,
            color: Colors.grey.shade200,
            child: Column(
              children: [
                if (_frequentItems.isNotEmpty) ...[
                  const ListTile(
                    title: Text('Most Accessed',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ..._frequentItems.map((item) {
                    final isFolder = item['type'] == 'folder';
                    return ListTile(
                      leading: Icon(
                          isFolder ? Icons.folder : Icons.insert_drive_file,
                          color: isFolder ? Colors.amber : Colors.blue),
                      title: Text(item['name']),
                      onTap: () async {
                        if (isFolder) {
                          final folder = folders.firstWhere(
                              (f) => f['name'] == item['name'],
                              orElse: () => {});
                          if (folder.isNotEmpty) {
                            await _openFolder(folder['id'], folder['name']);
                          }
                        } else {
                          final file = files.firstWhere(
                              (f) => f['title'] == item['name'],
                              orElse: () => {});
                          if (file.isNotEmpty) {
                            final filePath = file['filePath'];
                            if (File(filePath).existsSync()) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfViewerPage(
                                      filePath: filePath, title: file['title']),
                                ),
                              );
                            }
                          }
                        }
                      },
                    );
                  }).toList(),
                  const Divider(),
                ],
                ListTile(
                  title: const Text('Folders',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                      icon: const Icon(Icons.create_new_folder),
                      onPressed: _createFolder),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dashboard),
                        title: const Text('Documents'),
                        selected: selectedFolderId == null,
                        onTap: () async {
                          selectedFolderId = null;
                          files = await db.getDocuments();
                          setState(() {});
                        },
                      ),
                      ...folders.map((f) => ListTile(
                            leading:
                                const Icon(Icons.folder, color: Colors.amber),
                            title: Text(f['name'] as String),
                            selected: selectedFolderId == f['id'],
                            onTap: () => _openFolder(
                                f['id'] as int, f['name'] as String),
                            trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteFolder(
                                    f['id'] as int, f['name'] as String)),
                          )),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _uploadFile(folderId: selectedFolderId),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload File'),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<int>(
                        future: _calculateStorageUsed(),
                        builder: (context, snapshot) {
                          final used = snapshot.data ?? 0;
                          final maxStorage = 1024 * 1024 * 1024 * 10; // 10 GB
                          final percent = (used / maxStorage).clamp(0.0, 1.0);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(value: percent),
                              const SizedBox(height: 4),
                              Text(
                                'Storage: ${_formatBytes(used)} / ${_formatBytes(maxStorage)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // =====================
          // Main area: Tabs
          // =====================
          Expanded(
            child: Column(
              children: [
                TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.black,
                    tabs: [
                      const Tab(text: 'Files'),
                      const Tab(text: 'Audit Logs'),
                      if (widget.user['role'] == 'admin')
                        const Tab(text: 'Accounts'),
                    ]),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Files tab
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(children: [
                              Expanded(
                                  child: Text(selectedFolderId == null
                                      ? 'Documents'
                                      : 'Foldername: $selectedFolderName')),
                              ElevatedButton.icon(
                                  onPressed: () =>
                                      _uploadFile(folderId: selectedFolderId),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload')),
                            ]),
                          ),

                          // Search Bar
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search files...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          Expanded(
                            child: filteredFiles.isEmpty
                                ? const Center(child: Text('No files found'))
                                : ListView(
                                    children:
                                        filteredFiles.map(_fileTile).toList()),
                          ),
                        ],
                      ),

                      // Audit logs tab
                      ListView(
                          children: logs
                              .map((l) => ListTile(
                                  title: Text(l['action'] as String),
                                  subtitle: Text(
                                      '${l['username']} at ${l['timestamp']}')))
                              .toList()),

                      // Users tab
                      if (widget.user['role'] == 'admin')
                        Column(
                          children: [
                            ElevatedButton.icon(
                                onPressed: () async {
                                  final uCtrl = TextEditingController();
                                  final pCtrl = TextEditingController();
                                  String role = 'user';
                                  await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                            title: const Text('Add user'),
                                            content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextField(
                                                      controller: uCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Username')),
                                                  TextField(
                                                      controller: pCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Password')),
                                                  DropdownButton<String>(
                                                      value: role,
                                                      onChanged: (v) =>
                                                          role = v ?? 'user',
                                                      items: ['user', 'admin']
                                                          .map((r) =>
                                                              DropdownMenuItem(
                                                                  value: r,
                                                                  child:
                                                                      Text(r)))
                                                          .toList()),
                                                ]),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('Cancel')),
                                              ElevatedButton(
                                                  onPressed: () async {
                                                    if (uCtrl.text
                                                        .trim()
                                                        .isNotEmpty) {
                                                      await db.addUser(
                                                          uCtrl.text.trim(),
                                                          pCtrl.text.trim(),
                                                          role);
                                                      await db.insertAuditLog(
                                                          widget
                                                              .user['username'],
                                                          'add_user: ${uCtrl.text.trim()}');
                                                      Navigator.pop(ctx);
                                                      await _loadAll();
                                                    }
                                                  },
                                                  child: const Text('Save'))
                                            ],
                                          ));
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add User')),
                            Expanded(
                                child: ListView(
                                    children: users
                                        .map((u) => ListTile(
                                              title:
                                                  Text(u['username'] as String),
                                              subtitle:
                                                  Text('role: ${u['role']}'),
                                              trailing: IconButton(
                                                  icon:
                                                      const Icon(Icons.delete),
                                                  onPressed: () async {
                                                    await db.deleteUser(
                                                        u['id'] as int);
                                                    await db.insertAuditLog(
                                                        widget.user['username'],
                                                        'delete_user: ${u['username']}');
                                                    await _loadAll();
                                                  }),
                                            ))
                                        .toList()))
                          ],
                        )
                      else
                        Container(),
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
