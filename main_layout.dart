// lib/main_layout.dart
import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'notes_page.dart';
import 'calendar_page.dart';
import 'audit_logs_page.dart';
import 'accounts_page.dart';
import 'login_page.dart';

class MainLayout extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainLayout({Key? key, required this.user}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Only show Accounts if user is admin
    _pages = [
      Dashboard(user: widget.user),
      AuditLogsPage(user: widget.user),
      if (widget.user['role'] == 'admin') AccountsPage(user: widget.user),
      CalendarPage(user: widget.user),
      NotesPage(user: widget.user),
    ];
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.user['role'] == 'admin';

    // Titles for navigation items (align with _pages)
    final navItems = [
      {'icon': Icons.folder, 'label': 'Documents'},
      {'icon': Icons.list_alt, 'label': 'Audit Logs'},
      if (isAdmin) {'icon': Icons.people, 'label': 'Accounts'},
      {'icon': Icons.calendar_today, 'label': 'Calendar'},
      {'icon': Icons.note, 'label': 'Notes'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DigiDocs'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          // Header navigation buttons
          for (int i = 0; i < navItems.length; i++)
            TextButton.icon(
              onPressed: () => _onNavTap(i),
              icon: Icon(
                navItems[i]['icon'] as IconData,
                color: _selectedIndex == i ? Colors.white : Colors.white70,
              ),
              label: Text(
                navItems[i]['label'] as String,
                style: TextStyle(
                  color: _selectedIndex == i ? Colors.white : Colors.white70,
                  fontWeight:
                      _selectedIndex == i ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          const SizedBox(width: 16),
          // Logout button
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }
}
