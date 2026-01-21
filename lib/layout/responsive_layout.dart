// File: lib/layout/responsive_layout.dart
// Version: 6.0
// Description: Floating Header with Rounded Corners. Search icon left of Logo, expands to left keeping Tab Name visible.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/settings_tab.dart';
import '../screens/web_config_tab.dart';
import '../screens/students_tab.dart';
import '../screens/events_tab.dart';
import '../screens/dashboard_tab.dart';
import '../screens/publish_tab.dart';

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
  late AnimationController _searchAnimCtrl;
  late Animation<double> _searchWidthAnim;

  final List<Widget> _screens = [
    const DashboardTab(),
    const StudentsTab(),
    const EventsTab(),
    const PublishTab(),
    const WebConfigView(),
    const SettingsView(),
  ];

  final List<String> _titles = ["Dashboard", "Students", "Events", "Publish", "Web Config", "Settings"];
  final List<IconData> _icons = [Icons.dashboard, Icons.people, Icons.emoji_events, Icons.emoji_events_outlined, Icons.language, Icons.settings];

  @override
  void initState() {
    super.initState();
    _menuAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _searchAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _searchWidthAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _searchAnimCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _menuAnimCtrl.dispose();
    _searchAnimCtrl.dispose();
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
      if (_isSearchExpanded) _toggleSearch();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchAnimCtrl.forward();
        _searchFocus.requestFocus();
      } else {
        _searchAnimCtrl.reverse();
        _searchCtrl.clear();
        globalSearchQuery.value = "";
        _searchFocus.unfocus();
      }
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
              // HEADER (Now Floating)
              _buildFloatingHeader(isWeb),
              
              // BODY
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
          
          // DROPDOWN MENU
          if (_isMenuOpen && !isWeb)
            Positioned(
              top: 80, // Adjusted for floating header
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
    );
  }

  Widget _buildFloatingHeader(bool isWeb) {
    bool allowSearch = (_idx == 1 || _idx == 2 || _idx == 3); // Students, Events, Publish

    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8), // FLOATING MARGINS
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), // ROUNDED SHAPE
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
              
              // 1. HAMBURGER (Mobile)
              if (!isWeb)
                IconButton(icon: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: _menuAnimCtrl, color: Colors.indigo), onPressed: _toggleMenu),

              // 2. TAB NAME (Always Visible on Left)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Text(_titles[_idx].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
              ),

              // 3. CENTER AREA (Title <-> Search Bar Animation)
              Expanded(
                child: Stack(
                  alignment: Alignment.centerRight, // Align search to right to expand left
                  children: [
                    // A. Fest Title (Fades out when search opens)
                    AnimatedOpacity(
                      opacity: _isSearchExpanded ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(festName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            if(tagline.isNotEmpty) Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),

                    // B. Search Bar (Expands from Right to Left)
                    if (allowSearch)
                      AnimatedBuilder(
                        animation: _searchWidthAnim,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            widthFactor: _searchWidthAnim.value, // 0 to 1 width
                            alignment: Alignment.centerRight,
                            child: Container(
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.indigo.withOpacity(0.3))
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                decoration: const InputDecoration(
                                  hintText: "Search...",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjusted padding
                                  isDense: true,
                                ),
                                onChanged: (v) => globalSearchQuery.value = v.toLowerCase(),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              // 4. SEARCH ICON (Left of Logo)
              if (allowSearch)
                IconButton(
                  icon: Icon(_isSearchExpanded ? Icons.close : Icons.search, color: Colors.grey.shade700),
                  onPressed: _toggleSearch,
                  tooltip: _isSearchExpanded ? "Close" : "Search",
                ),

              // 5. LOGO (Far Right)
              if (logoUrl.isNotEmpty)
                Padding(padding: const EdgeInsets.only(right: 12, left: 4), child: CircleAvatar(backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage(logoUrl), radius: 18))
              else
                const Padding(padding: EdgeInsets.only(right: 12, left: 4), child: Icon(Icons.school, color: Colors.grey, size: 28)),
            ],
          );
        },
      ),
    );
  }
}