// File: lib/layout/responsive_layout.dart
// Version: 2.0
// Description: സ്മൂത്ത് ആനിമേറ്റഡ് ഹാംബർഗർ മെനു, കസ്റ്റം ഡ്രോപ്പ് ഡൗൺ, സെൻട്രലൈസ്ഡ് ഹെഡർ.

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

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> with SingleTickerProviderStateMixin {
  int _idx = 0;
  bool _isMenuOpen = false; // മെനു തുറന്നിട്ടുണ്ടോ എന്ന് നോക്കാൻ
  late AnimationController _menuAnimCtrl; // ഹാംബർഗർ ആനിമേഷൻ കൺട്രോളർ

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
    // ആനിമേഷൻ കൺട്രോളർ സെറ്റ് ചെയ്യുന്നു (300ms സമയം)
    _menuAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _menuAnimCtrl.dispose();
    super.dispose();
  }

  // മെനു തുറക്കാനും അടയ്ക്കാനും ഉള്ള ഫംഗ്ഷൻ
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuAnimCtrl.forward(); // Play Animation (Menu -> X)
      } else {
        _menuAnimCtrl.reverse(); // Reverse Animation (X -> Menu)
      }
    });
  }

  // ടാബ് മാറ്റുമ്പോൾ മെനു അടയ്ക്കുന്നു
  void _selectTab(int index) {
    setState(() {
      _idx = index;
      _isMenuOpen = false;
      _menuAnimCtrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. MAIN CONTENT LAYER
          Column(
            children: [
              // --- HEADER SECTION ---
              _buildHeader(isWeb),
              
              // --- BODY SECTION ---
              Expanded(
                child: Row(
                  children: [
                    // വെബ്ബിൽ മാത്രം സൈഡ് ബാർ (Optional)
                    if (isWeb)
                      NavigationRail(
                        selectedIndex: _idx,
                        onDestinationSelected: _selectTab,
                        labelType: NavigationRailLabelType.all,
                        destinations: _titles.asMap().entries.map((e) => NavigationRailDestination(icon: Icon(_icons[e.key]), label: Text(e.value))).toList(),
                      ),
                    
                    // Main Screen Content
                    Expanded(child: _screens[_idx]),
                  ],
                ),
              ),
            ],
          ),

          // 2. DROPDOWN MENU OVERLAY (Mobile Only)
          // മെനു തുറക്കുമ്പോൾ മാത്രം ഇത് കാണിക്കും
          if (_isMenuOpen && !isWeb)
            Positioned(
              top: 70, // ഹെഡറിന് തൊട്ടു താഴെ
              left: 10,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  width: 250, // ഡ്രോപ്പ് ഡൗൺ വീതി
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // ലിസ്റ്റിന്റെ നീളം മാത്രം എടുക്കുക
                    children: List.generate(_titles.length, (i) {
                      bool isSelected = _idx == i;
                      return ListTile(
                        dense: true,
                        leading: Icon(_icons[i], color: isSelected ? Colors.indigo : Colors.grey),
                        title: Text(
                          _titles[i], 
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.indigo : Colors.black87
                          )
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.indigo.shade50,
                        onTap: () => _selectTab(i),
                      );
                    }),
                  ),
                ),
              ),
            ),
            
          // പുറത്ത് ക്ലിക്ക് ചെയ്താൽ മെനു പോകാൻ ഒരു സുതാര്യമായ ലെയർ (Optional UX enhancement)
          if (_isMenuOpen && !isWeb)
            Positioned(
              top: 70, left: 270, right: 0, bottom: 0,
              child: GestureDetector(onTap: _toggleMenu, child: Container(color: Colors.transparent)),
            )
        ],
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(bool isWeb) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
              // 1. HAMBURGER MENU (Left) - Only on Mobile
              if (!isWeb)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton(
                    icon: AnimatedIcon(
                      icon: AnimatedIcons.menu_close, // Menu മാറുന്ന X
                      progress: _menuAnimCtrl,
                      size: 28,
                      color: Colors.indigo,
                    ),
                    onPressed: _toggleMenu,
                  ),
                ),

              // 2. TAB NAME (Small, Left side)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Text(
                  _titles[_idx].toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                ),
              ),

              // 3. CENTER INFO (Fest Name & Tagline)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(festName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                    if(tagline.isNotEmpty)
                      Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.grey)),
                  ],
                ),
              ),

              // 4. LOGO (Right)
              if (logoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: NetworkImage(logoUrl),
                    radius: 20,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.school, color: Colors.grey, size: 30),
                ),
            ],
          );
        },
      ),
    );
  }
}
