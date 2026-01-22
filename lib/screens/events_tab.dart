// File: lib/screens/events_tab.dart
// Version: 9.0
// Description: Explicit Filter Labels added, 3-Dot Menu & Visuals Preserved.

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
        if (_filterType != null && data['type'] != _filterType!.toLowerCase()) return false;
        if (_filterStage != null && data['stage'] != _filterStage) return false;
        if (_filterPart != null && data['participation'] != _filterPart!.toLowerCase()) return false;
        if (_currentSearch.isNotEmpty) {
          if (!data['name'].toString().toLowerCase().contains(_currentSearch)) return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterCategory = null; _filterType = null; _filterStage = null; _filterPart = null;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildCompactFilterBar(),
            const SizedBox(height: 10),
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

  Widget _buildCompactFilterBar() {
    bool hasFilter = _filterCategory!=null || _filterType!=null || _filterStage!=null || _filterPart!=null;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 20, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Explicit Labels added
                    _compactDropdown(width: 140, value: _filterCategory, label: "Select Category", items: ["General", ..._categories], onChanged: (v){ _filterCategory=v; _applyFilters(); }),
                    const SizedBox(width: 6),
                    _compactDropdown(width: 110, value: _filterType, label: "Select Type", items: ["Single", "Group"], onChanged: (v){ _filterType=v; _applyFilters(); }),
                    const SizedBox(width: 6),
                    _compactDropdown(width: 110, value: _filterStage, label: "Select Stage", items: ["On-Stage", "Off-Stage"], onChanged: (v){ _filterStage=v; _applyFilters(); }),
                    if(_isMixedMode) ...[
                      const SizedBox(width: 6),
                      _compactDropdown(width: 120, value: _filterPart, label: "Select Gender", items: ["Open", "Boys", "Girls"], displayItems: ["Common", "Boys Only", "Girls Only"], onChanged: (v){ _filterPart=v; _applyFilters(); })
                    ]
                  ],
                ),
              ),
            ),
            if(hasFilter)
              IconButton(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 20), tooltip: "Clear All Filters", constraints: const BoxConstraints(), padding: const EdgeInsets.only(left: 8))
          ],
        ),
      ),
    );
  }

  Widget _compactDropdown({required double width, required String? value, required String label, required List<String> items, List<String>? displayItems, required Function(String?) onChanged}) {
    return SizedBox(
      width: width, height: 40,
      child: DropdownButtonFormField<String>(
        value: value, 
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label, // Explicit Label
          labelStyle: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          floatingLabelBehavior: FloatingLabelBehavior.always, // Always show label on top
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text("All", style: TextStyle(color: Colors.grey.shade600, fontSize: 11))),
          ...items.asMap().entries.map((e) => DropdownMenuItem(value: e.value, child: Text((displayItems!=null && displayItems.length>e.key)?displayItems[e.key]:e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
        ],
        onChanged: onChanged,
      ),
    );
  }

  // 2. EVENTS LIST (RESTORED VISUALS + 3 DOT MENU)
  Widget _buildEventsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events found."));

    return ListView.separated(
      itemCount: _filteredEvents.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (c, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        var data = _filteredEvents[index].data() as Map<String, dynamic>;
        String docId = _filteredEvents[index].id;
        
        bool isGroup = data['type'] == 'group';
        bool onStage = data['stage'] == 'On-Stage';
        String part = data['participation'] ?? 'open';
        List pts = data['points'] ?? [0,0,0];

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(data['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                    // 3-DOT MENU
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      onSelected: (v) {
                        if(v=='edit') _openEventDialog(id: docId, data: data);
                        if(v=='delete') _deleteEvent(docId, data['name']);
                      },
                      itemBuilder: (c) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text("Edit")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete")])),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                
                // BADGES ROW
                Wrap(spacing: 6, runSpacing: 6, children: [
                    _infoBadge(data['category'], Colors.blueGrey, Icons.category),
                    _infoBadge(isGroup ? "Group" : "Single", isGroup ? Colors.purple : Colors.blue, isGroup ? Icons.groups : Icons.person),
                    _infoBadge(onStage ? "On-Stage" : "Off-Stage", Colors.orange.shade800, Icons.mic),
                    if(_isMixedMode) _infoBadge(part == 'open' ? "Common" : "${part.toUpperCase()} Only", part == 'girls' ? Colors.pink : (part == 'boys' ? Colors.blue.shade800 : Colors.teal), part == 'girls' ? Icons.female : (part == 'boys' ? Icons.male : Icons.wc)),
                ]),
                
                const Divider(height: 16),
                
                // FOOTER ROW (Points & Limits)
                Row(children: [
                  const Icon(Icons.emoji_events, size: 14, color: Colors.amber), 
                  const SizedBox(width: 4),
                  Text("1st: ${pts[0]}   2nd: ${pts[1]}   3rd: ${pts[2]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(isGroup ? "Max: ${data['limits']['maxTeams']} Teams" : "Max: ${data['limits']['maxParticipants']} Students", style: const TextStyle(fontSize: 11, color: Colors.grey))
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))
      ]),
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
            contentPadding: const EdgeInsets.all(16),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name", filled: true, isDense: true)), const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: selCategory, hint: const Text("Category"), items: [const DropdownMenuItem(value: "General", child: Text("General")), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))], onChanged: (v) => setDialogState(() => selCategory = v), decoration: const InputDecoration(labelText: "Category", filled: true, isDense: true)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField(value: selType, items: const [DropdownMenuItem(value: "single", child: Text("Single")), DropdownMenuItem(value: "group", child: Text("Group"))], onChanged: onTypeChanged, decoration: const InputDecoration(labelText: "Type", filled: true, isDense: true))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField(value: selStage, items: const [DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")), DropdownMenuItem(value: "On-Stage", child: Text("On-Stage"))], onChanged: (v) => setDialogState(() => selStage = v!), decoration: const InputDecoration(labelText: "Stage", filled: true, isDense: true))),
                ]),
                if (_isMixedMode) ...[const SizedBox(height: 10), DropdownButtonFormField(value: selPart, items: const [DropdownMenuItem(value: "open", child: Text("Common")), DropdownMenuItem(value: "boys", child: Text("Boys Only")), DropdownMenuItem(value: "girls", child: Text("Girls Only"))], onChanged: (v) => setDialogState(() => selPart = v!), decoration: const InputDecoration(labelText: "Participation", filled: true, isDense: true))],
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(height: 4),
                Row(children: [Expanded(child: _miniInput(p1Ctrl, "1st")), const SizedBox(width: 5), Expanded(child: _miniInput(p2Ctrl, "2nd")), const SizedBox(width: 5), Expanded(child: _miniInput(p3Ctrl, "3rd"))]),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: Text("Limits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(height: 4),
                if (selType == 'single') _miniInput(limit1Ctrl, "Max Participants")
                else Row(children: [Expanded(child: _miniInput(limit1Ctrl, "Max Teams")), const SizedBox(width: 10), Expanded(child: _miniInput(limit2Ctrl, "Size/Team"))])
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

  Widget _miniInput(TextEditingController c, String hint) {
    return TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: hint, filled: true, isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));
  }

  // 4. CONFIRM DELETE DIALOG
  Future<void> _deleteEvent(String id, String name) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Event?", style: TextStyle(fontWeight: FontWeight.bold)), 
        content: Text("Are you sure you want to delete '$name'?"), 
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No", style: TextStyle(color: Colors.grey))), 
          ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Yes, Delete"))
        ]
      )
    ) ?? false;

    if (confirm) {
      await db.collection('events').doc(id).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted successfully")));
    }
  }
}