// File: lib/screens/events_tab.dart
// Version: 6.0
// Description: Restored Badges, Category Icons, and Search Optimization.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../layout/responsive_layout.dart'; 

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final db = FirebaseFirestore.instance;
  final List<StreamSubscription> _streams = [];
  Timer? _debounceTimer;
  String _currentSearch = "";

  // Filters
  String? _filterCategory;
  String? _filterType;
  String? _filterStage;
  String? _filterPart;
  
  // Data
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<String> _categories = [];
  bool _isMixedMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
    globalSearchQuery.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    globalSearchQuery.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    for (var s in _streams) s.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentSearch = globalSearchQuery.value.toLowerCase();
        _applyFilters();
      });
    });
  }

  void _initData() {
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    }));

    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    _streams.add(db.collection('events').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _allEvents = snap.docs;
          _isLoading = false;
        });
        _applyFilters();
      }
    }));
  }

  void _applyFilters() {
    setState(() {
      _filteredEvents = _allEvents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (_filterCategory != null && data['category'] != _filterCategory) return false;
        if (_filterType != null && data['type'] != _filterType) return false;
        if (_filterStage != null && data['stage'] != _filterStage) return false;
        if (_filterPart != null && data['participation'] != _filterPart) return false;
        
        if (_currentSearch.isNotEmpty) {
          if (!data['name'].toString().toLowerCase().contains(_currentSearch)) return false;
        }
        return true;
      }).toList();
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
            _buildAdvancedFilterBar(),
            const SizedBox(height: 12),
            Expanded(child: _buildEventsList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventDialog(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW EVENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 1. ADVANCED FILTER BAR
  Widget _buildAdvancedFilterBar() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _styledDropdown(value: _filterCategory, hint: "Category", items: ["General", ..._categories], onChanged: (v){ _filterCategory=v; _applyFilters(); })),
                const SizedBox(width: 10),
                Expanded(child: _styledDropdown(value: _filterType, hint: "Type", items: ["Single", "Group"], onChanged: (v){ _filterType=v?.toLowerCase(); _applyFilters(); })),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _styledDropdown(value: _filterStage, hint: "Stage", items: ["On-Stage", "Off-Stage"], onChanged: (v){ _filterStage=v; _applyFilters(); })),
                const SizedBox(width: 10),
                if(_isMixedMode)
                   Expanded(child: _styledDropdown(value: _filterPart, hint: "Gender", items: ["Open", "Boys", "Girls"], displayItems: ["Common", "Boys Only", "Girls Only"], onChanged: (v){ _filterPart=v?.toLowerCase(); _applyFilters(); }))
                else
                   const Spacer(),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _styledDropdown({required String? value, required String hint, required List<String> items, List<String>? displayItems, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value, hint: Text("All $hint", style: const TextStyle(fontSize: 12)),
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        filled: true, fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text("All $hint", style: const TextStyle(color: Colors.grey))),
        ...items.asMap().entries.map((e) => DropdownMenuItem(value: e.value, child: Text((displayItems!=null && displayItems.length>e.key)?displayItems[e.key]:e.value, overflow: TextOverflow.ellipsis)))
      ],
      onChanged: onChanged,
    );
  }

  // 2. EVENTS LIST
  Widget _buildEventsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events found."));

    return ListView.builder(
      itemCount: _filteredEvents.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        var data = _filteredEvents[index].data() as Map<String, dynamic>;
        String docId = _filteredEvents[index].id;
        
        bool isGroup = data['type'] == 'group';
        bool onStage = data['stage'] == 'On-Stage';
        String part = data['participation'] ?? 'open';
        List pts = data['points'] ?? [0,0,0];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(data['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _openEventDialog(id: docId, data: data), child: const CircleAvatar(backgroundColor: Colors.blue, radius: 14, child: Icon(Icons.edit, size: 16, color: Colors.white))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => _deleteEvent(docId, data['name']), child: const CircleAvatar(backgroundColor: Colors.red, radius: 14, child: Icon(Icons.delete, size: 16, color: Colors.white))),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                    _infoBadge(data['category'], Colors.blueGrey, Icons.category),
                    _infoBadge(isGroup ? "Group" : "Single", isGroup ? Colors.purple : Colors.blue, isGroup ? Icons.groups : Icons.person),
                    _infoBadge(onStage ? "On-Stage" : "Off-Stage", Colors.orange.shade800, Icons.mic),
                    if(_isMixedMode) _infoBadge(part == 'open' ? "Common" : "${part.toUpperCase()} Only", part == 'girls' ? Colors.pink : (part == 'boys' ? Colors.blue.shade800 : Colors.teal), part == 'girls' ? Icons.female : (part == 'boys' ? Icons.male : Icons.wc)),
                ]),
                const Divider(height: 24),
                Row(children: [
                  const Icon(Icons.emoji_events, size: 16, color: Colors.amber), 
                  const SizedBox(width: 6),
                  Text("1st: ${pts[0]}   2nd: ${pts[1]}   3rd: ${pts[2]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
                  const Spacer(),
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(isGroup ? "Limit: ${data['limits']['maxTeams']} Teams" : "Limit: ${data['limits']['maxParticipants']} Students", style: const TextStyle(fontSize: 12, color: Colors.grey))
                ])
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))]),
    );
  }

  // 3. DIALOG
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

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
          void onTypeChanged(String? v) {
            if(v == null) return;
            setDialogState(() {
              selType = v;
              if (v == 'single') { p1Ctrl.text = '5'; p2Ctrl.text = '3'; p3Ctrl.text = '1'; limit1Ctrl.text = '3'; } 
              else { p1Ctrl.text = '10'; p2Ctrl.text = '8'; p3Ctrl.text = '5'; limit1Ctrl.text = '2'; limit2Ctrl.text = '5'; }
            });
          }

          return AlertDialog(
            title: Text(id == null ? "New Event" : "Edit Event"),
            scrollable: true,
            content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name", filled: true)), const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: selCategory, hint: const Text("Category"), items: [const DropdownMenuItem(value: "General", child: Text("General")), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))], onChanged: (v) => setDialogState(() => selCategory = v), decoration: const InputDecoration(labelText: "Category", filled: true)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField(value: selType, items: const [DropdownMenuItem(value: "single", child: Text("Single")), DropdownMenuItem(value: "group", child: Text("Group"))], onChanged: onTypeChanged, decoration: const InputDecoration(labelText: "Type", filled: true))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField(value: selStage, items: const [DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")), DropdownMenuItem(value: "On-Stage", child: Text("On-Stage"))], onChanged: (v) => setDialogState(() => selStage = v!), decoration: const InputDecoration(labelText: "Stage", filled: true))),
                ]),
                if (_isMixedMode) ...[const SizedBox(height: 10), DropdownButtonFormField(value: selPart, items: const [DropdownMenuItem(value: "open", child: Text("Common")), DropdownMenuItem(value: "boys", child: Text("Boys Only")), DropdownMenuItem(value: "girls", child: Text("Girls Only"))], onChanged: (v) => setDialogState(() => selPart = v!), decoration: const InputDecoration(labelText: "Participation", filled: true))],
                const SizedBox(height: 10),
                const Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number))]),
                const SizedBox(height: 10),
                const Text("Limits", style: TextStyle(fontWeight: FontWeight.bold)),
                if (selType == 'single') TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Participants", filled: true))
                else Row(children: [Expanded(child: TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Teams", filled: true))), const SizedBox(width: 10), Expanded(child: TextField(controller: limit2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Size/Team", filled: true)))])
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