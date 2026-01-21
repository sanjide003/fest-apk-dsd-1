// File: lib/screens/events_tab.dart
// Version: 4.0
// Description: Highlighted Dropdowns, Detailed Event Cards showing ALL info.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../layout/responsive_layout.dart'; // For globalSearchQuery

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final db = FirebaseFirestore.instance;

  // Filters
  String? _filterCategory;
  String? _filterType; // Single/Group
  
  // Data Caches
  List<DocumentSnapshot> _allEvents = [];
  List<String> _categories = [];
  bool _isMixedMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // 1. Categories Listener
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    // 2. Mode Listener
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    // 3. Events Listener (Real-time updates)
    db.collection('events').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _allEvents = snap.docs;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- FILTERS ---
            _buildAdvancedFilterBar(),
            const SizedBox(height: 12),
            
            // --- EVENTS LIST ---
            Expanded(child: _buildEventsList()),
          ],
        ),
      ),
      
      // --- ADD BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventDialog(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW EVENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 1. HIGHLIGHTED FILTER BAR
  Widget _buildAdvancedFilterBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                const Text("Filters:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                // Clear Button
                if (_filterCategory != null || _filterType != null)
                  InkWell(
                    onTap: () => setState(() { _filterCategory = null; _filterType = null; }),
                    child: const Row(children: [Icon(Icons.clear_all, size: 16, color: Colors.red), Text("Reset", style: TextStyle(color: Colors.red, fontSize: 11))]),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Category Filter
                Expanded(child: _styledDropdown(value: _filterCategory, hint: "Category", items: ["General", ..._categories], onChanged: (v)=>setState(()=>_filterCategory=v))),
                const SizedBox(width: 10),
                // Type Filter
                Expanded(child: _styledDropdown(value: _filterType, hint: "Type", items: ["Single", "Group"], onChanged: (v)=>setState(()=>_filterType=v?.toLowerCase()))),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Custom Dropdown with Selection Highlight
  Widget _styledDropdown({required String? value, required String hint, required List<String> items, required Function(String?) onChanged}) {
    bool isSelected = value != null;
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.shade50 : Colors.white, // Active Background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.indigo : Colors.grey.shade300, // Active Border
          width: isSelected ? 1.5 : 1
        )
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text("Select $hint", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: isSelected ? Colors.indigo : Colors.grey),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item, 
              child: Text(
                item, 
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: value == item ? FontWeight.bold : FontWeight.normal,
                  color: value == item ? Colors.indigo : Colors.black87
                ), 
                overflow: TextOverflow.ellipsis
              )
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // 2. EVENTS LIST
  Widget _buildEventsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_allEvents.isEmpty) return const Center(child: Text("No events found."));

    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        
        final filteredDocs = _allEvents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filters
          if (_filterCategory != null && data['category'] != _filterCategory) return false;
          if (_filterType != null && data['type'] != _filterType) return false;
          
          // Search
          if (searchQuery.isNotEmpty) {
            if (!data['name'].toString().toLowerCase().contains(searchQuery)) return false;
          }
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("No matching events."));

        return ListView.builder(
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            String docId = filteredDocs[index].id;
            return _buildDetailedEventCard(docId, data);
          },
        );
      },
    );
  }

  // --- DETAILED EVENT CARD ---
  Widget _buildDetailedEventCard(String docId, Map<String, dynamic> data) {
    bool isGroup = data['type'] == 'group';
    bool onStage = data['stage'] == 'On-Stage';
    String part = data['participation'] ?? 'open';
    List pts = data['points'] ?? [0,0,0];
    Map limits = data['limits'] ?? {};

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    data['name'], 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit Icon
                InkWell(onTap: () => _openEventDialog(id: docId, data: data), child: const CircleAvatar(backgroundColor: Colors.blue, radius: 14, child: Icon(Icons.edit, size: 16, color: Colors.white))),
                const SizedBox(width: 8),
                // Delete Icon
                InkWell(onTap: () => _deleteEvent(docId, data['name']), child: const CircleAvatar(backgroundColor: Colors.red, radius: 14, child: Icon(Icons.delete, size: 16, color: Colors.white))),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Tags Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoBadge(data['category'], Colors.blueGrey, Icons.category),
                _infoBadge(isGroup ? "Group Item" : "Single Item", isGroup ? Colors.purple : Colors.blue, isGroup ? Icons.groups : Icons.person),
                _infoBadge(onStage ? "On-Stage" : "Off-Stage", Colors.orange.shade800, Icons.mic),
                if(_isMixedMode) 
                  _infoBadge(
                    part == 'open' ? "Common" : "${part.toUpperCase()} Only", 
                    part == 'girls' ? Colors.pink : (part == 'boys' ? Colors.blue.shade800 : Colors.teal),
                    part == 'girls' ? Icons.female : (part == 'boys' ? Icons.male : Icons.wc)
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Details Grid (Points & Limits)
            Row(
              children: [
                // Points Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("POINTS DISTRIBUTION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text("1st: ${pts[0]}  2nd: ${pts[1]}  3rd: ${pts[2]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                // Vertical Divider
                Container(height: 30, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 16),
                // Limits Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PARTICIPATION LIMITS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            isGroup ? "Max ${limits['maxTeams']} Teams (${limits['teamSize']}/Team)" : "Max ${limits['maxParticipants']} Students",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color), 
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 3. ADD / EDIT DIALOG
  void _openEventDialog({String? id, Map<String, dynamic>? data}) {
    final nameCtrl = TextEditingController(text: data?['name']);
    final p1Ctrl = TextEditingController(text: data != null ? data['points'][0].toString() : '5');
    final p2Ctrl = TextEditingController(text: data != null ? data['points'][1].toString() : '3');
    final p3Ctrl = TextEditingController(text: data != null ? data['points'][2].toString() : '1');
    final limit1Ctrl = TextEditingController(text: data != null ? (data['type']=='group' ? data['limits']['maxTeams'].toString() : data['limits']['maxParticipants'].toString()) : '3');
    final limit2Ctrl = TextEditingController(text: data != null && data['type']=='group' ? data['limits']['teamSize'].toString() : '5');

    String selType = data?['type'] ?? 'single';
    String? selCategory = data?['category'];
    String selStage = data?['stage'] ?? 'Off-Stage';
    String selPart = data?['participation'] ?? 'open';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          void onTypeChanged(String? v) {
            if(v == null) return;
            setDialogState(() {
              selType = v;
              if (v == 'single') {
                p1Ctrl.text = '5'; p2Ctrl.text = '3'; p3Ctrl.text = '1';
                limit1Ctrl.text = '3';
              } else {
                p1Ctrl.text = '10'; p2Ctrl.text = '8'; p3Ctrl.text = '5';
                limit1Ctrl.text = '2'; 
                limit2Ctrl.text = '5';
              }
            });
          }

          return AlertDialog(
            title: Text(id == null ? "New Event" : "Edit Event"),
            scrollable: true,
            content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name")),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: selCategory, hint: const Text("Category"), items: [const DropdownMenuItem(value: "General", child: Text("General")), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))], onChanged: (v) => setDialogState(() => selCategory = v), decoration: const InputDecoration(labelText: "Category")),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField(value: selType, items: const [DropdownMenuItem(value: "single", child: Text("Single")), DropdownMenuItem(value: "group", child: Text("Group"))], onChanged: onTypeChanged, decoration: const InputDecoration(labelText: "Type"))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField(value: selStage, items: const [DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")), DropdownMenuItem(value: "On-Stage", child: Text("On-Stage"))], onChanged: (v) => setDialogState(() => selStage = v!), decoration: const InputDecoration(labelText: "Stage"))),
                ]),
                if (_isMixedMode) ...[const SizedBox(height: 10), DropdownButtonFormField(value: selPart, items: const [DropdownMenuItem(value: "open", child: Text("Common")), DropdownMenuItem(value: "boys", child: Text("Boys Only")), DropdownMenuItem(value: "girls", child: Text("Girls Only"))], onChanged: (v) => setDialogState(() => selPart = v!), decoration: const InputDecoration(labelText: "Participation"))],
                const SizedBox(height: 10),
                const Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number))]),
                const SizedBox(height: 10),
                const Text("Limits", style: TextStyle(fontWeight: FontWeight.bold)),
                if (selType == 'single') TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Participants per House"))
                else Row(children: [Expanded(child: TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Teams"))), const SizedBox(width: 10), Expanded(child: TextField(controller: limit2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Size/Team")))])
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(onPressed: () async {
                  if (nameCtrl.text.isEmpty || selCategory == null) return;
                  Map<String, dynamic> d = { 'name': nameCtrl.text.trim(), 'category': selCategory, 'type': selType, 'stage': selStage, 'participation': _isMixedMode ? selPart : 'boys', 'points': [int.tryParse(p1Ctrl.text) ?? 0, int.tryParse(p2Ctrl.text) ?? 0, int.tryParse(p3Ctrl.text) ?? 0], 'limits': selType == 'single' ? { 'maxParticipants': int.tryParse(limit1Ctrl.text) ?? 3 } : { 'maxTeams': int.tryParse(limit1Ctrl.text) ?? 2, 'teamSize': int.tryParse(limit2Ctrl.text) ?? 5 }, 'createdAt': FieldValue.serverTimestamp() };
                  if (id == null) await db.collection('events').add(d); else { d.remove('createdAt'); await db.collection('events').doc(id).update(d); }
                  if(mounted) Navigator.pop(ctx);
              }, child: Text(id == null ? "Create" : "Update"))
            ],
          );
        }
      ),
    );
  }

  Future<void> _deleteEvent(String id, String name) async {
    if(await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete?"), content: Text(name), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false) {
      await db.collection('events').doc(id).delete();
    }
  }
}