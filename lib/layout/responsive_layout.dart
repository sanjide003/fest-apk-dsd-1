// File: lib/layout/responsive_layout.dart
// Version: 1.0
// Description: വെബ്ബിലും മൊബൈലിലും പ്രവർത്തിക്കുന്ന നാവിഗേഷൻ ബാർ/ഡ്രോയർ.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart'; // പുതിയ ടാബ്

// താഴെ പറയുന്നവ Placeholder ആണ്. അടുത്ത ഘട്ടത്തിൽ നമ്മൾ ഇവ ഉണ്ടാക്കും.
// തൽക്കാലം എറർ വരാതിരിക്കാൻ ലളിതമായ വിഡ്ജറ്റുകൾ നൽകുന്നു.
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
  
  // എല്ലാ സ്ക്രീനുകളും ഇവിടെ ലിസ്റ്റ് ചെയ്യുന്നു (6 ടാബുകൾ)
  final List<Widget> _screens = [
    const DashboardTab(),
    const StudentsTab(),
    const EventsTab(),
    const WebConfigView(), // Web Config
    const SettingsView(),  // Settings
  ];

  final List<String> _titles = ["Dashboard", "Students", "Events", "Web Config", "Settings"];
  final List<IconData> _icons = [Icons.dashboard, Icons.people, Icons.emoji_events, Icons.language, Icons.settings];

  @override
  Widget build(BuildContext context) {
    bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Padding(padding: const EdgeInsets.only(top: 80), child: _screens[_idx]),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 900),
                height: 60,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)], border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_titles.length, (i) => _webNavItem(i)),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: Text(_titles[_idx], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const UserAccountsDrawerHeader(accountName: Text("Fest Admin"), accountEmail: Text("admin@fest.com"), decoration: BoxDecoration(color: Colors.indigo)),
              ...List.generate(_titles.length, (i) => ListTile(leading: Icon(_icons[i]), title: Text(_titles[i]), selected: _idx == i, selectedColor: Colors.indigo, onTap: () { setState(() => _idx = i); Navigator.pop(context); })),
            ],
          ),
        ),
        body: _screens[_idx],
      );
    }
  }

  Widget _webNavItem(int i) {
    bool sel = _idx == i;
    return InkWell(
      onTap: () => setState(() => _idx = i),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: sel ? Colors.indigo : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [Icon(_icons[i], size: 18, color: sel ? Colors.white : Colors.grey), if (sel) ...[const SizedBox(width: 8), Text(_titles[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]]),
      ),
    );
  }
}
