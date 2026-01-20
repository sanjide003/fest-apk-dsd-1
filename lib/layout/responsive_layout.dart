// File: lib/layout/responsive_layout.dart
// Version: 1.2
// Description: വെബ്ബിലും മൊബൈലിലും പ്രവർത്തിക്കുന്ന ലേഔട്ട്. ഹെഡറിൽ ഫെസ്റ്റ് ലോഗോയും പേരും കാണിക്കുന്നു.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart';

// Placeholder Widgets (ഇവ പിന്നീട് യഥാർത്ഥ ഫയലുകൾ വെച്ച് മാറ്റാം)
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
  
  // സ്ക്രീനുകളുടെ ലിസ്റ്റ്
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        // ടാബിന്റെ പേര് ഇടതുവശത്ത് ചെറുതായി കാണിക്കുന്നു
        title: Text(
          _titles[_idx].toUpperCase(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.indigo),
        ),
        // വലതുവശത്ത് ഫെസ്റ്റ് പേരും ലോഗോയും (Firebase-ൽ നിന്ന്)
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('home_config').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
              
              String festName = data['festName1'] ?? 'FEST ADMIN';
              String logoUrl = data['logoUrl'] ?? '';

              return Row(
                children: [
                  Text(festName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(width: 12),
                  if (logoUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: NetworkImage(logoUrl),
                        radius: 18,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.school, color: Colors.grey),
                    ),
                ],
              );
            },
          )
        ],
      ),
      drawer: !isWeb ? _buildDrawer() : null, // മൊബൈലിൽ മാത്രം ഡ്രോയർ
      body: Row(
        children: [
          // വെബ്ബിൽ സൈഡ് മെനു (Optional - ഇവിടെ ലളിതമായ ഡിസൈൻ നൽകുന്നു)
          if (isWeb)
            NavigationRail(
              selectedIndex: _idx,
              onDestinationSelected: (i) => setState(() => _idx = i),
              labelType: NavigationRailLabelType.all,
              destinations: _titles.asMap().entries.map((e) {
                return NavigationRailDestination(
                  icon: Icon(_icons[e.key]),
                  label: Text(e.value),
                );
              }).toList(),
            ),
            
          // പ്രധാന കണ്ടെന്റ്
          Expanded(child: _screens[_idx]),
        ],
      ),
    );
  }

  // മൊബൈൽ ഡ്രോയർ
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
