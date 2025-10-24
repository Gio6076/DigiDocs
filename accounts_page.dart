// lib/accounts_page.dart
import 'package:flutter/material.dart';
import 'db_service.dart';

class AccountsPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const AccountsPage({Key? key, required this.user}) : super(key: key);

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final db = DatabaseService.instance;
  List<Map<String, dynamic>> users = [];
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  String selectedRole = 'user';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    users = await db.getUsers();
    setState(() {});
  }

  Future<void> _addUser() async {
    final username = usernameCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    await db.addUser(username, password, selectedRole);
    await db.insertAuditLog(widget.user['username'], 'add_user:$username');

    usernameCtrl.clear();
    passwordCtrl.clear();
    selectedRole = 'user';
    _loadUsers();
  }

  Future<void> _deleteUser(int id, String username) async {
    await db.deleteUser(id);
    await db.insertAuditLog(widget.user['username'], 'delete_user:$username');
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts Management')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text('Add New User', style: TextStyle(fontSize: 18)),
            TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username')),
            TextField(
                controller: passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password')),
            DropdownButton<String>(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: 'user', child: Text('User')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => selectedRole = v!),
            ),
            ElevatedButton(onPressed: _addUser, child: const Text('Add User')),
            const SizedBox(height: 16),
            const Text('Existing Users', style: TextStyle(fontSize: 18)),
            Expanded(
              child: ListView(
                children: users.map((u) {
                  return Card(
                    child: ListTile(
                      title: Text(u['username'] ?? ''),
                      subtitle: Text('Role: ${u['role'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: u['username'] == 'admin'
                            ? null
                            : () => _deleteUser(u['id'] as int, u['username']),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
