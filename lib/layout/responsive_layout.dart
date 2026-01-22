// File: lib/layout/responsive_layout.dart
// Version: 12.0
// Description: Original Design Restored. Added Search support for Registrations Tab (Index 3).

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart';
import '../screens/students_tab.dart';
import '../screens/events_tab.dart';
import '../screens/dashboard_tab.dart';
import '../screens/publish_tab.dart';
import '../screens/registrations_tab.dart';

// Global ValueNotifier for Search
final ValueNotifier<String> globalSearchQuery = ValueNotifier("");

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});
  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> with TickerProviderStateMixin {
  int _idx = 0; 
  bool _isMenuOpen = false;
  bool _isSearchExpanded = false;
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  late AnimationController _menuAnimCtrl;

  final List<Widget> _screens = [
    const DashboardTab(),
    const StudentsTab(),
    const EventsTab(),
    const RegistrationsTab(),
    const PublishTab(),
    const WebConfigView(),
    const SettingsView(),
  ];

  final List<String> _titles = ["Dashboard", "Students", "Events", "Registrations", "Publish", "Web Config", "Settings"];
  final List<IconData> _icons = [Icons.dashboard, Icons.people, Icons.emoji_events, Icons.how_to_reg, Icons.emoji_events_outlined, Icons.language, Icons.settings];

  @override
  void initState() {
    super.initState();
    _menuAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _menuAnimCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
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
      if (_isSearchExpanded) _closeSearch();
    });
  }

  void _openSearch() {
    setState(() {
      _isSearchExpanded = true;
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchExpanded = false;
      _searchCtrl.clear();
      globalSearchQuery.value = "";
      _searchFocus.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildFloatingHeader(isWeb),
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
                top: 80,
                left: 16,
                child: Material(
                  elevation: 8, borderRadius: BorderRadius.circular(16), color: Colors.white,
                  child: Container(
                    width: 200, padding: const EdgeInsets.symmetric(vertical: 8),
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
              Positioned(top: 80, left: 220, right: 0, bottom: 0, child: GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.transparent)))
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHeader(bool isWeb) {
    // UPDATED: Added index 3 (Registrations) to allow search
    bool allowSearch = (_idx == 1 || _idx == 2 || _idx == 3 || _idx == 4); 

    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('settings').doc('home_config').snapshots(),
        builder: (context, snap) {
          var data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : {};
          String festName = data['festName1'] ?? 'FEST ADMIN';
          String tagline = data['tagline'] ?? '';
          String logoUrl = data['logoUrl'] ?? '';

          return Row(
            children: [
              const SizedBox(width: 8),
              if (!isWeb)
                IconButton(icon: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _menuAnimCtrl, color: Colors.indigo), onPressed: _toggleMenu),

              Expanded(
                child: _isSearchExpanded
                  ? _buildSearchBar() 
                  : _buildNormalHeaderContent(festName, tagline, allowSearch),
              ),

              if (logoUrl.isNotEmpty)
                Padding(padding: const EdgeInsets.only(right: 12, left: 8), child: CircleAvatar(backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage(logoUrl), radius: 18))
              else
                const Padding(padding: EdgeInsets.only(right: 12, left: 8), child: Icon(Icons.school, color: Colors.grey, size: 28)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNormalHeaderContent(String festName, String tagline, bool allowSearch) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 16),
          child: Text(_titles[_idx].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(festName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              if(tagline.isNotEmpty) Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.grey)),
            ],
          ),
        ),
        if (allowSearch)
          IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: _openSearch, tooltip: "Search"),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.indigo.withOpacity(0.3))),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        decoration: InputDecoration(hintText: "Search...", border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), isDense: true, suffixIcon: IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: _closeSearch)),
        onChanged: (v) => globalSearchQuery.value = v.toLowerCase(),
      ),
    );
  }
}
