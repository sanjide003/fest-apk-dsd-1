// File: lib/screens/events_tab.dart
// Version: 5.2
// Description: Compact Detailed Cards (All Info Visible, Less Height), Active Filter Display.

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
  String? _filterType;
  String? _filterStage;
  String? _filterPart;
  
  // Data
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
    // Categories
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    // Mode
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    // Events
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
      body: Column(
        children: [
          // Filter Bar (Compact)
          _buildFilterBar(),
          
          // Events List
          Expanded(child: _buildEventsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventDialog(),
        backgroundColor: Colors.indigo,
        mini: true, // Small FAB
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 1. COMPACT FILTER BAR
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _compactDropdown(value: _filterCategory, hint: "Category", items: ["General", ..._categories], onChanged: (v)=>setState(()=>_filterCategory=v))),
              const SizedBox(width: 6),
              Expanded(child: _compactDropdown(value: _filterType, hint: "Type", items: ["Single", "Group"], onChanged: (v)=>setState(()=>_filterType=v?.toLowerCase()))),
              const SizedBox(width: 6),
              Expanded(child: _compactDropdown(value: _filterStage, hint: "Stage", items: ["On-Stage", "Off-Stage"], onChanged: (v)=>setState(()=>_filterStage=v))),
            ],
          ),
          if(_isMixedMode) ...[
            const SizedBox(height: 6),
            Row(children: [
               Expanded(child: _compactDropdown(value: _filterPart, hint: "Participation", items: ["Open", "Boys", "Girls"], displayItems: ["Common", "Boys Only", "Girls Only"], onChanged: (v)=>setState(()=>_filterPart=v?.toLowerCase()))),
               const Spacer(flex: 2), // Empty space
               // Reset Icon
               if (_filterCategory!=null || _filterType!=null || _filterStage!=null || _filterPart!=null)
                 InkWell(
                   onTap: ()=>setState((){ _filterCategory=null; _filterType=null; _filterStage=null; _filterPart=null; }), 
                   child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.clear_all, color: Colors.red, size: 20))
                 )
            ])
          ]
        ],
      ),
    );
  }

  Widget _compactDropdown({required String? value, required String hint, required List<String> items, List<String>? displayItems, required Function(String?) onChanged}) {
    bool isActive = value != null;
    return Container(
      height: 34, // Reduced Height
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.indigo.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? Colors.indigo : Colors.grey.shade300)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          icon: Icon(Icons.arrow_drop_down, size: 16, color: isActive ? Colors.indigo : Colors.grey),
          items: [
            DropdownMenuItem(value: null, child: Text("All $hint", style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ...items.asMap().entries.map((e) {
              String val = e.value;
              String txt = (displayItems != null && displayItems.length > e.key) ? displayItems[e.key] : val;
              return DropdownMenuItem(value: val, child: Text(txt, style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: isActive && value==val ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis));
            })
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // 2. EVENTS LIST
  Widget _buildEventsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        final filteredDocs = _allEvents.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          if (_filterCategory != null && d['category'] != _filterCategory) return false;
          if (_filterType != null && d['type'] != _filterType) return false;
          if (_filterStage != null && d['stage'] != _filterStage) return false;
          if (_filterPart != null && d['participation'] != _filterPart) return false;
          if (searchQuery.isNotEmpty && !d['name'].toString().toLowerCase().contains(searchQuery)) return false;
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("No events found."));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            return _buildCompactDetailCard(filteredDocs[index].id, data);
          },
        );
      },
    );
  }

  // --- COMPACT DETAILED CARD ---
  Widget _buildCompactDetailCard(String id, Map<String, dynamic> data) {
    bool isGroup = data['type'] == 'group';
    bool onStage = data['stage'] == 'On-Stage';
    String part = data['participation'] ?? 'open';
    List pts = data['points'] ?? [0,0,0];
    Map limits = data['limits'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Minimal gap
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1))]
      ),
      child: InkWell(
        onTap: () => _openEventDialog(id: id, data: data),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8), // Tight padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: Name, Category, Icons
              Row(
                children: [
                  // Type Icon
                  Icon(isGroup ? Icons.groups : Icons.person, size: 14, color: isGroup ? Colors.purple : Colors.blue),
                  const SizedBox(width: 6),
                  // Name & Category
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: "${data['name']}  ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                          TextSpan(text: "(${data['category']})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ]
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Actions
                  InkWell(onTap: ()=>_openEventDialog(id:id, data:data), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.edit, size: 16, color: Colors.blue))),
                  InkWell(onTap: ()=>_deleteEvent(id, data['name']), child: const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.delete, size: 16, color: Colors.red))),
                ],
              ),
              
              const SizedBox(height: 4), // Tiny gap
              
              // ROW 2: Badges (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tinyBadge(isGroup ? "Group" : "Single", isGroup ? Colors.purple : Colors.blue),
                    const SizedBox(width: 4),
                    _tinyBadge(onStage ? "On-Stage" : "Off-Stage", Colors.orange.shade800),
                    if(_isMixedMode) ...[
                      const SizedBox(width: 4),
                      _tinyBadge(part=='open' ? "Common" : "${part.substring(0,1).toUpperCase()}${part.substring(1)} Only", part=='girls'?Colors.pink:(part=='boys'?Colors.blue.shade900:Colors.teal)),
                    ]
                  ],
                ),
              ),
              
              const SizedBox(height: 4), // Tiny gap
              
              // ROW 3: Points & Limits (Footer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pts: ${pts[0]}-${pts[1]}-${pts[2]}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text(
                      isGroup ? "Limit: ${limits['maxTeams']} Teams (${limits['teamSize']}/Team)" : "Limit: ${limits['maxParticipants']} Ppl",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700)
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5)
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // 3. DIALOG (Same Logic)
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name")), const SizedBox(height: 10),
                DropdownButtonFormField<String>(value: selCategory, hint: const Text("Category"), items: [const DropdownMenuItem(value: "General", child: Text("General")), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))], onChanged: (v) => setDialogState(() => selCategory = v), decoration: const InputDecoration(labelText: "Category")),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField(value: selType, items: const [DropdownMenuItem(value: "single", child: Text("Single")), DropdownMenuItem(value: "group", child: Text("Group"))], onChanged: onTypeChanged, decoration: const InputDecoration(labelText: "Type"))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField(value: selStage, items: const [DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")), DropdownMenuItem(value: "On-Stage", child: Text("On-Stage"))], onChanged: (v) => setDialogState(() => selStage = v!), decoration: const InputDecoration(labelText: "Stage"))),
                ]),
                if (_isMixedMode) ...[const SizedBox(height: 10), DropdownButtonFormField(value: selPart, items: const [DropdownMenuItem(value: "open", child: Text("Common")), DropdownMenuItem(value: "boys", child: Text("Boys Only")), DropdownMenuItem(value: "girls", child: Text("Girls Only"))], onChanged: (v) => setDialogState(() => selPart = v!), decoration: const InputDecoration(labelText: "Participation"))],
                const SizedBox(height: 10),
                const Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number))]),
                const SizedBox(height: 10),
                const Text("Limits", style: TextStyle(fontWeight: FontWeight.bold)),
                if (selType == 'single') TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Participants"))
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