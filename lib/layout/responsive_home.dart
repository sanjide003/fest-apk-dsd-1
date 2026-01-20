import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:fest_manager/screens/dashboard_tab.dart';
import 'package:fest_manager/screens/events_tab.dart';
import 'package:fest_manager/screens/students_tab.dart';
import 'package:fest_manager/screens/settings_tab.dart';

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});
  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  int _idx = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const DashboardTab(),
    const EventsView(),
    const RegistrationView(),
    const SettingsView(),
  ];

  final List<String> _titles = ["Dashboard", "Events Management", "Student Registry", "Settings"];

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && MediaQuery.of(context).size.width > 600) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 90), 
              child: Row(
                children: [
                   Expanded(child: _screens[_idx]),
                ],
              ),
            ),
            
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                constraints: const BoxConstraints(maxWidth: 1200),
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    const Icon(Icons.school, color: Colors.indigo),
                    const SizedBox(width: 12),
                    Text(_titles[_idx], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Spacer(),
                    _webNavItem(0, Icons.dashboard_rounded, "Dash"),
                    _webNavItem(1, Icons.emoji_events_rounded, "Events"),
                    _webNavItem(2, Icons.people_alt_rounded, "Students"),
                    _webNavItem(3, Icons.settings_rounded, "Settings"),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } 
    
    else {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_titles[_idx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: (){}),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.indigo),
                accountName: Text("Fest Admin"),
                accountEmail: Text("admin@college.edu"),
                currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.indigo)),
              ),
              ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () { setState(()=>_idx=0); Navigator.pop(context); }),
              ListTile(leading: const Icon(Icons.emoji_events), title: const Text("Events"), onTap: () { setState(()=>_idx=1); Navigator.pop(context); }),
              ListTile(leading: const Icon(Icons.people), title: const Text("Students"), onTap: () { setState(()=>_idx=2); Navigator.pop(context); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () { setState(()=>_idx=3); Navigator.pop(context); }),
            ],
          ),
        ),
        body: _screens[_idx],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          backgroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black12,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dash'),
            NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Events'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Students'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
          ],
        ),
      );
    }
  }

  Widget _webNavItem(int index, IconData icon, String label) {
    bool isSel = _idx == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _idx = index),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? Colors.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isSel ? Colors.white : Colors.grey.shade600),
                if (isSel) ...[
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
