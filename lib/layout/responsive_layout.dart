// File: lib/layout/responsive_layout.dart
// Version: 10.0
// Description: Global Search Logic implemented. Expanding Search Bar in AppBar.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Imports for screens
import '../screens/dashboard_tab.dart';
import '../screens/students_tab.dart';
import '../screens/events_tab.dart';
import '../screens/registrations_tab.dart';
import '../screens/publish_tab.dart';
import '../screens/web_config_tab.dart';
import '../screens/settings_tab.dart';

// Global ValueNotifier for Search
final ValueNotifier<String> globalSearchQuery = ValueNotifier("");

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});

  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  // Navigation State
  int _selectedIndex = 0;
  bool _isMenuExpanded = true; // For Desktop
  
  // Search State
  bool _isSearchExpanded = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Data
  String _festName = "Fest Manager";
  String _tagline = "";

  @override
  void initState() {
    super.initState();
    _loadConfig();
    
    // Listener to update global query
    _searchCtrl.addListener(() {
      globalSearchQuery.value = _searchCtrl.text;
    });
  }

  void _loadConfig() {
    FirebaseFirestore.instance.collection('web_config').doc('main').snapshots().listen((snap) {
      if (snap.exists) {
        if (mounted) {
          setState(() {
            _festName = snap.data()?['festName'] ?? "Fest Manager";
            _tagline = snap.data()?['tagline'] ?? "";
          });
        }
      }
    });
  }

  // List of Screens
  final List<Widget> _screens = const [
    DashboardTab(),
    StudentsTab(),
    EventsTab(),
    RegistrationsTab(),
    PublishTab(),
    WebConfigView(),
    SettingsView(),
  ];

  final List<String> _titles = [
    "Dashboard",
    "Students",
    "Events",
    "Registrations",
    "Publish",
    "Web Config",
    "Settings"
  ];

  final List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.event_note_rounded,
    Icons.how_to_reg_rounded,
    Icons.publish_rounded,
    Icons.web_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      body: Row(
        children: [
          // 1. SIDEBAR (Desktop)
          if (!isMobile)
            _buildSidebar(),

          // 2. MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                // APP BAR
                _buildTopBar(isMobile),
                
                // BODY
                Expanded(
                  child: _screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      // DRAWER (Mobile)
      drawer: isMobile ? _buildDrawer() : null,
    );
  }

  // --- TOP BAR ---
  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: Row(
        children: [
          // Menu Icon (Mobile)
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          
          const SizedBox(width: 8),

          // TITLE or SEARCH BAR
          Expanded(
            child: _isSearchExpanded
                ? _buildSearchBar()
                : _buildTitleArea(),
          ),

          // SEARCH TOGGLE
          if (!_isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.indigo),
              tooltip: "Search",
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
                _searchFocus.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTitleArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        if (_tagline.isNotEmpty && _selectedIndex == 0)
          Text(
            _tagline,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.indigo.withOpacity(0.2))
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: "Search in ${_titles[_selectedIndex]}...",
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              setState(() {
                _isSearchExpanded = false;
                _searchCtrl.clear();
                globalSearchQuery.value = "";
              });
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  // --- NAVIGATION (Sidebar & Drawer) ---
  
  Widget _buildSidebar() {
    return Container(
      width: _isMenuExpanded ? 240 : 70,
      color: Colors.white,
      child: Column(
        children: [
          // Logo Area
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: _isMenuExpanded 
                ? Text(_festName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo), overflow: TextOverflow.ellipsis)
                : const Icon(Icons.school, color: Colors.indigo),
          ),
          
          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _screens.length,
              itemBuilder: (context, index) {
                bool isSel = _selectedIndex == index;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.indigo.shade50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(_icons[index], color: isSel ? Colors.indigo : Colors.grey.shade600, size: 22),
                        if (_isMenuExpanded) ...[
                          const SizedBox(width: 16),
                          Text(_titles[index], style: TextStyle(color: isSel ? Colors.indigo : Colors.grey.shade800, fontWeight: isSel ? FontWeight.bold : FontWeight.normal))
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Collapse Button
          IconButton(
            icon: Icon(_isMenuExpanded ? Icons.chevron_left : Icons.chevron_right),
            onPressed: () => setState(() => _isMenuExpanded = !_isMenuExpanded),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            accountName: Text(_festName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Admin Panel"),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, color: Colors.indigo)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _screens.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(_icons[index], color: _selectedIndex == index ? Colors.indigo : Colors.grey),
                  title: Text(_titles[index], style: TextStyle(color: _selectedIndex == index ? Colors.indigo : Colors.black87, fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal)),
                  selected: _selectedIndex == index,
                  selectedTileColor: Colors.indigo.shade50,
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
