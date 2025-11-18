import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'db_service.dart';
import 'notes_page.dart';
import 'calendar_page.dart';
import 'login_page.dart';
import 'pdf_viewer_page.dart';
import 'accounts_page.dart';
import 'audit_logs_page.dart';

class MainLayout extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainLayout({Key? key, required this.user}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

// -------------------------
// Dashboard (merged from dashboard.dart)
// -------------------------

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

  String searchQuery = "";
  List<Map<String, dynamic>> _frequentItems = [];

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

  Future<List<Map<String, dynamic>>> _getFrequentAccessedItems(
      {int top = 5}) async {
    final auditLogs = await db.getAuditLogs();
    final counts = <String, int>{};

    // Count file openings from audit logs
    for (var log in auditLogs) {
      final action = log['action'] as String? ?? '';
      if (action.startsWith('open_file:')) {
        final fileName = action.split(':').last.trim();
        counts[fileName] = (counts[fileName] ?? 0) + 1;
      }
    }

    // Get ALL files from the system (unassigned + from all folders)
    final allSystemFiles = <Map<String, dynamic>>[];

    // Add unassigned files
    final unassignedFiles = await db.getDocuments();
    allSystemFiles.addAll(unassignedFiles);

    // Add files from all folders
    final allFolders = await db.getFolders();
    for (var folder in allFolders) {
      final folderId = folder['id'] as int;
      final filesInFolder = await db.getFilesInFolder(folderId);
      allSystemFiles.addAll(filesInFolder);
    }

    // Match file names from audit logs with actual files
    final result = <Map<String, dynamic>>[];
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var e in entries.take(top)) {
      final fileName = e.key;
      // Find the file by title in ALL system files
      final file = allSystemFiles.firstWhere(
        (f) => f['title'] == fileName,
        orElse: () => {},
      );

      if (file.isNotEmpty) {
        // Add access count to the file data for display
        final fileWithCount = Map<String, dynamic>.from(file);
        fileWithCount['access_count'] = e.value;
        result.add(fileWithCount);
      }
    }

    return result;
  }

  // --------------------------
  // Storage Monitor (System-wide)
  // --------------------------
  Future<int> _calculateTotalStorageUsed() async {
    int total = 0;

    // Calculate storage for all files (including those in folders)
    final allFiles = await db.getDocuments(); // Gets unassigned files
    for (var file in allFiles) {
      final path = file['filePath'] as String? ?? '';
      if (path.isNotEmpty && File(path).existsSync()) {
        total += File(path).lengthSync();
      }
    }

    // Calculate storage for files in folders
    final allFolders = await db.getFolders();
    for (var folder in allFolders) {
      final folderId = folder['id'] as int;
      final filesInFolder = await db.getFilesInFolder(folderId);
      for (var file in filesInFolder) {
        final path = file['filePath'] as String? ?? '';
        if (path.isNotEmpty && File(path).existsSync()) {
          total += File(path).lengthSync();
        }
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

  // Helper method to count total files in the system
  Future<int> _getFileCount() async {
    int count = 0;

    //  Para sa mga unassigned files itow, bibilangin
    final allFiles = await db.getDocuments();
    count += allFiles.length;

    // Para sa mga files na nasa folders, bibilangin rin tow
    final allFolders = await db.getFolders();
    for (var folder in allFolders) {
      final folderId = folder['id'] as int;
      final filesInFolder = await db.getFilesInFolder(folderId);
      count += filesInFolder.length;
    }

    return count;
  }

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Folder',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Folder name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
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
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile({int? folderId}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true, // Enable multiple file selection
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'csv',
        'md'
      ],
    );

    if (result == null || result.files.isEmpty) return;

    int successCount = 0;
    int errorCount = 0;

    // Show progress dialog for multiple files
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Uploading Files',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Processing ${result.files.length} files...',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Success: $successCount | Failed: $errorCount',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    // Upload each file
    for (final f in result.files) {
      if (f.path == null) {
        errorCount++;
        continue;
      }

      try {
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
        successCount++;
      } catch (e) {
        errorCount++;
        print('Error uploading file ${f.name}: $e');
      }
    }

    // Close the progress dialog
    Navigator.of(context).pop();

    // Show result summary
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successCount > 0
              ? 'Successfully uploaded $successCount file(s)${errorCount > 0 ? ', $errorCount failed' : ''}'
              : 'Failed to upload files',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor:
            successCount > 0 ? const Color(0xFF4CAF50) : Colors.orange,
      ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Delete "$folderName" and all documents inside?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
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

  // --------------------------
  // Password Change Methods
  // --------------------------
  Future<void> _changeUserPassword(Map<String, dynamic> user) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Changing password for: ${user['username']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newPassword = passwordCtrl.text.trim();
              final confirmPassword = confirmCtrl.text.trim();

              if (newPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a new password'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Passwords do not match'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (newPassword.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        const Text('Password must be at least 3 characters'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await db.updateUserPassword(user['id'] as int, newPassword);
                await db.insertAuditLog(
                  widget.user['username'],
                  'change_password: ${user['username']}',
                );

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password updated for ${user['username']}'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating password: $e'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update Password',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeOwnPassword() async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change My Password',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Changing password for: ${widget.user['username']}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newPassword = passwordCtrl.text.trim();
              final confirmPassword = confirmCtrl.text.trim();

              if (newPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a new password'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Passwords do not match'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await db.updateUserPassword(
                    widget.user['id'] as int, newPassword);
                await db.insertAuditLog(
                  widget.user['username'],
                  'change_own_password',
                );

                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Your password has been updated'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating password: $e'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Update Password',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

// --------------------------
// File popup menu & tile
// --------------------------
  Widget _buildFilePopupMenu(Map<String, dynamic> file) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        final filePath = file['filePath'] as String? ?? '';
        if (filePath.isEmpty || !File(filePath).existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('File not found on disk'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
          return;
        }

        final ext = filePath.split('.').last.toLowerCase();

        if (value == 'open') {
          await db.insertAuditLog(
              widget.user['username'], 'open_file: ${file['title']}');

          if (['txt', 'csv', 'md'].contains(ext)) {
            final content = await File(filePath).readAsString();
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text(file['title']),
                      content: SizedBox(
                          width: 600,
                          height: 400,
                          child: SingleChildScrollView(child: Text(content))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'))
                      ],
                    ));
          } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text(file['title']),
                      content: SizedBox(
                          width: 600,
                          height: 400,
                          child:
                              Image.file(File(filePath), fit: BoxFit.contain)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'))
                      ],
                    ));
          } else if (ext == 'pdf') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                        filePath: filePath, title: file['title'])));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Preview not supported for this file type'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ));
          }
        } else if (value == 'download') {
          final outputDir = await FilePicker.platform.getDirectoryPath();
          if (outputDir == null) return;
          final destPath = '$outputDir/${file['title']}';

          try {
            await File(filePath).copy(destPath);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File downloaded to $destPath'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error downloading file: $e'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (value == 'export_pdf' || value == 'export_docx') {
          final outputDir = await FilePicker.platform.getDirectoryPath();
          if (outputDir == null) return;

          final originalFile = File(filePath);
          if (!await originalFile.exists()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Original file not found'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          try {
            final fileExtension = value == 'export_pdf' ? 'pdf' : 'docx';
            final fileName = file['title'].split('.').first;
            final destPath = '$outputDir/${fileName}_exported.$fileExtension';

            // Copy the file to the new location with new extension
            await originalFile.copy(destPath);

            // Log the export action
            await db.insertAuditLog(
              widget.user['username'],
              'export_$fileExtension: ${file['title']}',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File exported as $fileExtension to $destPath'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error exporting file: $e'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete File',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              content: Text('Delete "${file['title']}" permanently?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.white))),
              ],
            ),
          );
          if (confirmed == true) {
            await _deleteFile(file['id'] as int, file['title'] as String);
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: 'open',
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 20),
                SizedBox(width: 8),
                Text('Open'),
              ],
            )),
        const PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: 8),
                Text('Download'),
              ],
            )),
        const PopupMenuItem(
            value: 'export_pdf',
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, size: 20),
                SizedBox(width: 8),
                Text('Export to PDF'),
              ],
            )),
        const PopupMenuItem(
            value: 'export_docx',
            child: Row(
              children: [
                Icon(Icons.description, size: 20),
                SizedBox(width: 8),
                Text('Export to DOCX'),
              ],
            )),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'delete',
            child: Row(children: const [
              Icon(Icons.delete, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red))
            ])),
      ],
    );
  }

  Widget _fileTile(Map<String, dynamic> doc) {
    final uploadedAt = doc['uploadedAt'] ?? '';
    final shortDate = uploadedAt.isNotEmpty
        ? DateFormat.yMMMd().format(DateTime.parse(uploadedAt))
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.insert_drive_file,
              color: Color(0xFF2196F3), size: 20),
        ),
        title: Text(doc['title'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('By ${doc['author'] ?? ''} • $shortDate',
            style: TextStyle(color: Colors.grey[600])),
        trailing: _buildFilePopupMenu(doc),
        onTap: () async {
          final filePath = doc['filePath'] as String? ?? '';
          if (filePath.isEmpty || !File(filePath).existsSync()) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('File not found on disk'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ));
            return;
          }
          final ext = filePath.split('.').last.toLowerCase();
          if (ext == 'pdf') {
            await db.insertAuditLog(
                widget.user['username'], 'open_file: ${doc['title']}');
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PdfViewerPage(
                        filePath: filePath, title: doc['title'])));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFFF8FAFD),
      body: Column(
        children: [
          // Header with Navigation
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Logo and App Name Picture
                Row(
                  children: [
                    // Main Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/Logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // App Name Picture (replaces "DigiDocs" text)
                    Container(
                      width: 120, // Adjust width as needed for your image
                      height: 30, // Adjust height as needed for your image
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: const DecorationImage(
                          image: AssetImage(
                              'assets/images/Name.png'), // Your text image
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // User Profile with Dropdown
                _buildProfileDropdown(),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Column(
                    children: [
                      // Frequently Accessed Files - MOVED TO TOP
                      if (_frequentItems.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Frequently Accessed',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        ..._frequentItems
                            .map((file) => Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2196F3)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.insert_drive_file,
                                          color: Color(0xFF2196F3), size: 16),
                                    ),
                                    title: Text(file['title'] ?? '',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      'Accessed ${file['access_count'] ?? 0} times',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    trailing: _buildFilePopupMenu(file),
                                    onTap: () async {
                                      final filePath =
                                          file['filePath'] as String? ?? '';
                                      if (filePath.isEmpty ||
                                          !File(filePath).existsSync()) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text('File not found')));
                                        return;
                                      }
                                      final ext = filePath
                                          .split('.')
                                          .last
                                          .toLowerCase();
                                      if (ext == 'pdf') {
                                        await db.insertAuditLog(
                                            widget.user['username'],
                                            'open_file: ${file['title']}');
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => PdfViewerPage(
                                                    filePath: filePath,
                                                    title: file['title'])));
                                      }
                                    },
                                  ),
                                ))
                            .toList(),
                        const Divider(height: 16),
                      ],

                      // Folders Section with Create Button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Folders',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _createFolder,
                              icon: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.create_new_folder,
                                    color: Colors.white, size: 18),
                              ),
                              tooltip: 'Create New Folder',
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.dashboard, size: 20),
                                ),
                                title: const Text('All Documents',
                                    style: TextStyle(fontSize: 14)),
                                selected: selectedFolderId == null,
                                selectedColor: const Color(0xFF2196F3),
                                selectedTileColor:
                                    const Color(0xFF2196F3).withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                onTap: () async {
                                  selectedFolderId = null;
                                  files = await db.getDocuments();
                                  setState(() {});
                                },
                              ),
                            ),
                            ...folders.map((f) => Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFA000)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.folder,
                                          color: Color(0xFFFFA000), size: 20),
                                    ),
                                    title: Text(f['name'] as String,
                                        style: const TextStyle(fontSize: 14)),
                                    selected: selectedFolderId == f['id'],
                                    selectedColor: const Color(0xFF2196F3),
                                    selectedTileColor: const Color(0xFF2196F3)
                                        .withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    onTap: () => _openFolder(
                                        f['id'] as int, f['name'] as String),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.grey, size: 18),
                                      onPressed: () => _deleteFolder(
                                          f['id'] as int, f['name'] as String),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),

                      // Storage Section - System-wide
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: FutureBuilder<int>(
                          future: _calculateTotalStorageUsed(),
                          builder: (context, snapshot) {
                            final used = snapshot.data ?? 0;
                            final maxStorage = 1024 * 1024 * 1024 * 10; // 10 GB
                            final percent = (used / maxStorage).clamp(0.0, 1.0);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.storage,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    const Text('System Storage',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text(
                                        '${_formatBytes(used)} / ${_formatBytes(maxStorage)}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: percent,
                                  backgroundColor: Colors.grey[300],
                                  color: percent > 0.9
                                      ? Colors.red
                                      : percent > 0.7
                                          ? Colors.orange
                                          : const Color(0xFF2196F3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${(percent * 100).toStringAsFixed(1)}% used',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: percent > 0.9
                                            ? Colors.red
                                            : percent > 0.7
                                                ? Colors.orange
                                                : Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    FutureBuilder<int>(
                                      future: _getFileCount(),
                                      builder: (context, snapshot) {
                                        final fileCount = snapshot.data ?? 0;
                                        return Text(
                                          '$fileCount files',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Area
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFD),
                    ),
                    child: Column(
                      children: [
                        // Modern Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF2196F3),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: const Color(0xFF2196F3),
                            indicatorWeight: 3,
                            labelStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                            tabs: [
                              const Tab(
                                  text: 'Files',
                                  icon:
                                      Icon(Icons.insert_drive_file, size: 20)),
                              const Tab(
                                  text: 'Audit Logs',
                                  icon: Icon(Icons.history, size: 20)),
                              if (widget.user['role'] == 'admin')
                                const Tab(
                                    text: 'Accounts',
                                    icon: Icon(Icons.people, size: 20)),
                            ],
                          ),
                        ),

                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Files Tab
                              Column(
                                children: [
                                  // Header with Search and Upload
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey[200]!)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                              selectedFolderId == null
                                                  ? 'All Documents'
                                                  : 'Folder: $selectedFolderName',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        Container(
                                          width: 300,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Search files...',
                                              prefixIcon: const Icon(
                                                  Icons.search,
                                                  color: Colors.grey),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 0),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                searchQuery = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2196F3),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                          ),
                                          onPressed: () => _uploadFile(
                                              folderId: selectedFolderId),
                                          icon: const Icon(Icons.upload_file,
                                              size: 18),
                                          label: const Text('Upload'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Files List
                                  Expanded(
                                    child: filteredFiles.isEmpty
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.folder_open,
                                                    size: 64,
                                                    color: Colors.grey),
                                                SizedBox(height: 16),
                                                Text('No files found',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          )
                                        : ListView(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            children: filteredFiles
                                                .map(_fileTile)
                                                .toList(),
                                          ),
                                  ),
                                ],
                              ),

                              // Audit Logs Tab
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey[200]!)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text('Audit Logs',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600)),
                                        Spacer(),
                                        Icon(Icons.history, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: logs.isEmpty
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.history_toggle_off,
                                                    size: 64,
                                                    color: Colors.grey),
                                                SizedBox(height: 16),
                                                Text(
                                                    'No audit logs recorded yet',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.all(16),
                                            itemCount: logs.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 8),
                                            itemBuilder: (_, i) {
                                              final log = logs[i];
                                              return Card(
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: ListTile(
                                                  leading: Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF2196F3)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                        Icons.history,
                                                        color:
                                                            Color(0xFF2196F3),
                                                        size: 20),
                                                  ),
                                                  title: Text(log['action'],
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                  subtitle: Text(
                                                    'By ${log['username']} on ${DateFormat('MMM dd, yyyy – hh:mm a').format(DateTime.parse(log['timestamp']))}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),

                              // Accounts Tab
                              if (widget.user['role'] == 'admin')
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Colors.grey[200]!)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Text('User Management',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600)),
                                          Spacer(),
                                          Icon(Icons.people,
                                              color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2196F3),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                        ),
                                        onPressed: () async {
                                          final uCtrl = TextEditingController();
                                          final pCtrl = TextEditingController();
                                          String role = 'user';

                                          await showDialog(
                                            context: context,
                                            builder: (ctx) => StatefulBuilder(
                                              builder: (context, setState) {
                                                return Dialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16)),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            24),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Text(
                                                            'Add New User',
                                                            style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        const SizedBox(
                                                            height: 20),
                                                        TextField(
                                                          controller: uCtrl,
                                                          decoration:
                                                              InputDecoration(
                                                            labelText:
                                                                'Username',
                                                            border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12)),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        TextField(
                                                          controller: pCtrl,
                                                          obscureText: true,
                                                          decoration:
                                                              InputDecoration(
                                                            labelText:
                                                                'Password',
                                                            border: OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12)),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 20),
                                                        const Text('Role',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                        const SizedBox(
                                                            height: 12),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  OutlinedButton(
                                                                style: OutlinedButton
                                                                    .styleFrom(
                                                                  backgroundColor: role ==
                                                                          'user'
                                                                      ? const Color(
                                                                              0xFF2196F3)
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : null,
                                                                  side:
                                                                      BorderSide(
                                                                    color: role ==
                                                                            'user'
                                                                        ? const Color(
                                                                            0xFF2196F3)
                                                                        : Colors
                                                                            .grey,
                                                                  ),
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8)),
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    role =
                                                                        'user';
                                                                  });
                                                                },
                                                                child: Text(
                                                                  'User',
                                                                  style:
                                                                      TextStyle(
                                                                    color: role ==
                                                                            'user'
                                                                        ? const Color(
                                                                            0xFF2196F3)
                                                                        : Colors
                                                                            .grey,
                                                                    fontWeight: role ==
                                                                            'user'
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .normal,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child:
                                                                  OutlinedButton(
                                                                style: OutlinedButton
                                                                    .styleFrom(
                                                                  backgroundColor: role ==
                                                                          'admin'
                                                                      ? const Color(
                                                                              0xFF2196F3)
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : null,
                                                                  side:
                                                                      BorderSide(
                                                                    color: role ==
                                                                            'admin'
                                                                        ? const Color(
                                                                            0xFF2196F3)
                                                                        : Colors
                                                                            .grey,
                                                                  ),
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8)),
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    role =
                                                                        'admin';
                                                                  });
                                                                },
                                                                child: Text(
                                                                  'Admin',
                                                                  style:
                                                                      TextStyle(
                                                                    color: role ==
                                                                            'admin'
                                                                        ? const Color(
                                                                            0xFF2196F3)
                                                                        : Colors
                                                                            .grey,
                                                                    fontWeight: role ==
                                                                            'admin'
                                                                        ? FontWeight
                                                                            .bold
                                                                        : FontWeight
                                                                            .normal,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  top: 12.0),
                                                          child: Text(
                                                            'Selected: $role',
                                                            style: TextStyle(
                                                              color: role ==
                                                                      'admin'
                                                                  ? const Color(
                                                                      0xFF2196F3)
                                                                  : Colors
                                                                      .green,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 24),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: TextButton(
                                                                style: TextButton
                                                                    .styleFrom(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8)),
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator
                                                                        .pop(
                                                                            ctx),
                                                                child: const Text(
                                                                    'Cancel',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .grey)),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child:
                                                                  ElevatedButton(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                          0xFF2196F3),
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8)),
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  if (uCtrl.text
                                                                      .trim()
                                                                      .isNotEmpty) {
                                                                    await db.addUser(
                                                                        uCtrl
                                                                            .text
                                                                            .trim(),
                                                                        pCtrl
                                                                            .text
                                                                            .trim(),
                                                                        role);
                                                                    await db.insertAuditLog(
                                                                        widget.user[
                                                                            'username'],
                                                                        'add_user: ${uCtrl.text.trim()}');
                                                                    Navigator
                                                                        .pop(
                                                                            ctx);
                                                                    await _loadAll();
                                                                  }
                                                                },
                                                                child: const Text(
                                                                    'Create User'),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.person_add,
                                            size: 18),
                                        label: const Text('Add New User'),
                                      ),
                                    ),
                                    Expanded(
                                      child: users.isEmpty
                                          ? const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.people_outline,
                                                      size: 64,
                                                      color: Colors.grey),
                                                  SizedBox(height: 16),
                                                  Text('No users found',
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color: Colors.grey)),
                                                ],
                                              ),
                                            )
                                          : ListView.separated(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              itemCount: users.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(height: 8),
                                              itemBuilder: (_, i) {
                                                final user = users[i];
                                                return Card(
                                                  elevation: 1,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                  child: ListTile(
                                                    leading: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: user['role'] ==
                                                                'admin'
                                                            ? const Color(
                                                                    0xFFFFA000)
                                                                .withOpacity(
                                                                    0.1)
                                                            : const Color(
                                                                    0xFF2196F3)
                                                                .withOpacity(
                                                                    0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Icon(
                                                        user['role'] == 'admin'
                                                            ? Icons
                                                                .admin_panel_settings
                                                            : Icons.person,
                                                        color: user['role'] ==
                                                                'admin'
                                                            ? const Color(
                                                                0xFFFFA000)
                                                            : const Color(
                                                                0xFF2196F3),
                                                        size: 20,
                                                      ),
                                                    ),
                                                    title: Text(
                                                        user['username']
                                                            as String,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                    subtitle: Text(
                                                      'Role: ${user['role']}',
                                                      style: TextStyle(
                                                        color: user['role'] ==
                                                                'admin'
                                                            ? const Color(
                                                                0xFFFFA000)
                                                            : const Color(
                                                                0xFF2196F3),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    trailing: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        // Change Password Button
                                                        if (user['username'] !=
                                                            'admin') // Prevent changing admin's password
                                                          IconButton(
                                                            icon: Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                        0xFF4CAF50)
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                              ),
                                                              child: const Icon(
                                                                  Icons
                                                                      .lock_reset,
                                                                  color: Color(
                                                                      0xFF4CAF50),
                                                                  size: 16),
                                                            ),
                                                            onPressed: () =>
                                                                _changeUserPassword(
                                                                    user),
                                                            tooltip:
                                                                'Change Password',
                                                          ),
                                                        // Delete User Button
                                                        if (user['username'] !=
                                                            'admin')
                                                          IconButton(
                                                            icon: Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .withOpacity(
                                                                        0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                              ),
                                                              child: const Icon(
                                                                  Icons
                                                                      .delete_outline,
                                                                  color: Colors
                                                                      .red,
                                                                  size: 16),
                                                            ),
                                                            onPressed:
                                                                () async {
                                                              await db.deleteUser(
                                                                  user['id']
                                                                      as int);
                                                              await db.insertAuditLog(
                                                                  widget.user[
                                                                      'username'],
                                                                  'delete_user: ${user['username']}');
                                                              await _loadAll();
                                                            },
                                                            tooltip:
                                                                'Delete User',
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Profile Dropdown Widget using PopupMenuButton
  Widget _buildProfileDropdown() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'notes':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotesPage(user: widget.user)),
            );
            break;
          case 'calendar':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CalendarPage(user: widget.user)),
            );
            break;
          case 'change_password':
            _changeOwnPassword();
            break;
          case 'logout':
            _logout();
            break;
        }
      },
      itemBuilder: (context) => [
        // User Info Header
        PopupMenuItem<String>(
          enabled: false,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user['username'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Role: ${widget.user['role']?.toString().toUpperCase() ?? 'USER'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),

        // Notes Option
        const PopupMenuItem<String>(
          value: 'notes',
          child: Row(
            children: [
              Icon(Icons.note_add, size: 18, color: Colors.grey),
              SizedBox(width: 12),
              Text('Notes'),
            ],
          ),
        ),

        // Calendar Option
        const PopupMenuItem<String>(
          value: 'calendar',
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              SizedBox(width: 12),
              Text('Calendar'),
            ],
          ),
        ),
        const PopupMenuDivider(),

        // Logout Option
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user['username'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.user['role'] ?? 'user',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// MainLayout state - Simplified
// -------------------------
class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;
  final List<Map<String, dynamic>> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      {'title': 'Dashboard', 'page': Dashboard(user: widget.user)},
      {'title': 'Notes', 'page': NotesPage(user: widget.user)},
      {'title': 'Calendar', 'page': CalendarPage(user: widget.user)},
      {'title': 'Accounts', 'page': AccountsPage(user: widget.user)},
      {'title': 'Audit Logs', 'page': AuditLogsPage(user: widget.user)},
    ]);
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: _pages[selectedIndex]['page'],
    );
  }
}
