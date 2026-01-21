// File: lib/layout/responsive_layout.dart
// Version: 3.1
// Description: സെർച്ച് ബാർ Students ടാബിൽ മാത്രം കാണിക്കുന്നു.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart';
import '../screens/students_tab.dart';

// Global Search Notifier
final ValueNotifier<String> globalSearchQuery = ValueNotifier("");

// Placeholders
class DashboardTab extends StatelessWidget { const DashboardTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Dashboard Coming Soon")); }
class EventsTab extends StatelessWidget { const EventsTab({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Events Tab Coming Soon")); }

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});
  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> with SingleTickerProviderStateMixin {
  int _idx = 0; // 0:Dash, 1:Students, 2:Events, 3:Web, 4:Settings
  bool _isMenuOpen = false;
  bool _isSearchExpanded = false;
  final _searchCtrl = TextEditingController();
  late AnimationController _menuAnimCtrl;

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
  void initState() {
    super.initState();
    _menuAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _menuAnimCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) _menuAnimCtrl.forward(); else _menuAnimCtrl.reverse();
    });
  }

  void _selectTab(int index) {
    setState(() {
      _idx = index;
      _isMenuOpen = false;
      _menuAnimCtrl.reverse();
      // ടാബ് മാറുമ്പോൾ സെർച്ച് റീസെറ്റ് ചെയ്യുന്നു
      _isSearchExpanded = false;
      _searchCtrl.clear();
      globalSearchQuery.value = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isWeb),
              Expanded(
                child: Row(
                  children: [
                    if (isWeb)
                      NavigationRail(
                        selectedIndex: _idx,
                        onDestinationSelected: _selectTab,
                        labelType: NavigationRailLabelType.all,
                        destinations: _titles.asMap().entries.map((e) => NavigationRailDestination(icon: Icon(_icons[e.key]), label: Text(e.value))).toList(),
                      ),
                    Expanded(child: _screens[_idx]),
                  ],
                ),
              ),
            ],
          ),
          if (_isMenuOpen && !isWeb)
            Positioned(
              top: 70, left: 10,
              child: Material(
                elevation: 8, borderRadius: BorderRadius.circular(12), color: Colors.white,
                child: Container(
                  width: 250, padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_titles.length, (i) => ListTile(
                        dense: true,
                        leading: Icon(_icons[i], color: _idx == i ? Colors.indigo : Colors.grey),
                        title: Text(_titles[i], style: TextStyle(fontWeight: _idx == i ? FontWeight.bold : FontWeight.normal, color: _idx == i ? Colors.indigo : Colors.black87)),
                        selected: _idx == i, selectedTileColor: Colors.indigo.shade50,
                        onTap: () => _selectTab(i),
                      )),
                  ),
                ),
              ),
            ),
          if (_isMenuOpen && !isWeb)
            Positioned(top: 70, left: 270, right: 0, bottom: 0, child: GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.transparent)))
        ],
      ),
    );
  }

  Widget _buildHeader(bool isWeb) {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc('home_config').snapshots(),
        builder: (context, snap) {
          var data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : {};
          String festName = data['festName1'] ?? 'FEST ADMIN';
          String tagline = data['tagline'] ?? '';
          String logoUrl = data['logoUrl'] ?? '';

          return Row(
            children: [
              if (!isWeb)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: IconButton(icon: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _menuAnimCtrl, size: 28, color: Colors.indigo), onPressed: _toggleMenu)),

              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Text(_titles[_idx].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              ),

              Expanded(
                child: _isSearchExpanded
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search...",
                      border: InputBorder.none,
                      suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: (){
                        setState(() { _isSearchExpanded = false; _searchCtrl.clear(); globalSearchQuery.value = ""; });
                      })
                    ),
                    onChanged: (v) => globalSearchQuery.value = v.toLowerCase(),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(festName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      if(tagline.isNotEmpty) Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey)),
                    ],
                  ),
              ),

              // SEARCH ICON (Only visible if idx == 1 i.e., Students Tab)
              if (!_isSearchExpanded && _idx == 1)
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  onPressed: () => setState(() => _isSearchExpanded = true),
                ),

              if (logoUrl.isNotEmpty)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CircleAvatar(backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage(logoUrl), radius: 20))
              else
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Icon(Icons.school, color: Colors.grey, size: 30)),
            ],
          );
        },
      ),
    );
  }
}