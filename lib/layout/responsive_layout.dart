// File: lib/layout/responsive_layout.dart
// Version: 1.3
// Description: സെൻട്രലൈസ്ഡ് ഹെഡർ (ഫെസ്റ്റ് പേര് + ടാഗ്‌ലൈൻ), ലെഫ്റ്റ് ടാബ് നെയിം, റൈറ്റ് ലോഗോ.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart';

// Placeholder Widgets
class DashboardTab extends StatelessWidget { const DashboardTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Dashboard Coming Soon")); }
class StudentsTab extends StatelessWidget { const StudentsTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Students Tab Coming Soon")); }
class EventsTab extends StatelessWidget { const EventsTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Events Tab Coming Soon")); }

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});
  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  int _idx = 0;
  
  final List<Widget> _screens = [
    const DashboardTab(),
    const StudentsTab(),
    const EventsTab(),
    const WebConfigView(),
    const SettingsView(),
  ];

  final List<String> _titles = ["Dashboard", "Students", "Events", "Web Config", "Settings"];
  final List<IconData> _icons = [Icons.dashboard, Icons.people, Icons.emoji_events, Icons.language, Icons.settings];

  @override
  Widget build(BuildContext context) {
    bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('home_config').snapshots(),
          builder: (context, snap) {
            var data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : {};
            String festName = data['festName1'] ?? 'FEST ADMIN';
            String tagline = data['tagline'] ?? '';
            String logoUrl = data['logoUrl'] ?? '';

            return AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              centerTitle: true,
              
              // ഇടതുവശത്ത് ടാബ് പേര്
              leadingWidth: 120,
              leading: Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    _titles[_idx].toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 1),
                  ),
                ),
              ),

              // നടുവിൽ ഫെസ്റ്റ് പേരും ടാഗ്‌ലൈനും
              title: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(festName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  if(tagline.isNotEmpty)
                    Text(tagline, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
                ],
              ),

              // വലതുവശത്ത് ലോഗോ
              actions: [
                if (logoUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: NetworkImage(logoUrl),
                      radius: 20,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.school, color: Colors.grey, size: 30),
                  ),
              ],
            );
          },
        ),
      ),
      
      drawer: !isWeb ? _buildDrawer() : null,
      
      body: Row(
        children: [
          if (isWeb)
            NavigationRail(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _idx = i),
              labelType: NavigationRailLabelType.all,
              destinations: _titles.asMap().entries.map((e) => NavigationRailDestination(icon: Icon(_icons[e.key]), label: Text(e.value))).toList(),
            ),
          Expanded(child: _screens[_idx]),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text("Fest Admin"),
            accountEmail: Text("Manage your event"),
            decoration: BoxDecoration(color: Colors.indigo),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, color: Colors.indigo)),
          ),
          ...List.generate(_titles.length, (i) => ListTile(
            leading: Icon(_icons[i], color: _idx == i ? Colors.indigo : Colors.grey),
            title: Text(_titles[i], style: TextStyle(fontWeight: _idx == i ? FontWeight.bold : FontWeight.normal, color: _idx == i ? Colors.indigo : Colors.black87)),
            selected: _idx == i,
            tileColor: _idx == i ? Colors.indigo.shade50 : null,
            onTap: () { setState(() => _idx = i); Navigator.pop(context); },
          )),
        ],
      ),
    );
  }
}
