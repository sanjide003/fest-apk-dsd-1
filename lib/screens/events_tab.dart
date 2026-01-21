// File: lib/screens/events_tab.dart
// Version: 5.1
// Description: Compact List View (More items visible), Optimized Filters.

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

  String? _filterCategory;
  String? _filterType;
  String? _filterStage;
  String? _filterPart;
  
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
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

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
          // Filter Section (Compact)
          _buildCompactFilters(),
          
          // Events List (Expanded)
          Expanded(child: _buildCompactList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventDialog(),
        backgroundColor: Colors.indigo,
        mini: true, // Small FAB to save space
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // 1. COMPACT FILTERS
  Widget _buildCompactFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _miniDropdown(_filterCategory, "Cat", ["General", ..._categories], (v)=>setState(()=>_filterCategory=v))),
              const SizedBox(width: 8),
              Expanded(child: _miniDropdown(_filterType, "Type", ["Single", "Group"], (v)=>setState(()=>_filterType=v?.toLowerCase()))),
              const SizedBox(width: 8),
              Expanded(child: _miniDropdown(_filterStage, "Stage", ["On-Stage", "Off-Stage"], (v)=>setState(()=>_filterStage=v))),
            ],
          ),
          if(_isMixedMode) ...[
            const SizedBox(height: 6),
            Row(children: [
               Expanded(child: _miniDropdown(_filterPart, "Gender", ["Open", "Boys", "Girls"], (v)=>setState(()=>_filterPart=v?.toLowerCase()), display: ["Common", "Boys", "Girls"])),
               const Spacer(flex: 2),
               if (_filterCategory!=null || _filterType!=null || _filterStage!=null || _filterPart!=null)
                 InkWell(onTap: ()=>setState((){ _filterCategory=null; _filterType=null; _filterStage=null; _filterPart=null; }), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.clear_all, color: Colors.red)))
            ])
          ]
        ],
      ),
    );
  }

  Widget _miniDropdown(String? val, String hint, List<String> items, Function(String?) changed, {List<String>? display}) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: val != null ? Colors.indigo.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: val != null ? Colors.indigo : Colors.grey.shade300)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          items: [
            DropdownMenuItem(value: null, child: Text("All $hint", style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ...items.asMap().entries.map((e) => DropdownMenuItem(
              value: e.value, 
              child: Text(
                (display != null && display.length > e.key) ? display[e.key] : e.value, 
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), 
                overflow: TextOverflow.ellipsis
              )
            ))
          ],
          onChanged: changed,
        ),
      ),
    );
  }

  // 2. ULTRA COMPACT LIST
  Widget _buildCompactList() {
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

        if (filteredDocs.isEmpty) return const Center(child: Text("No events."));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          itemCount: filteredDocs.length,
          separatorBuilder: (c,i) => const SizedBox(height: 4), // Tiny gap
          itemBuilder: (context, index) {
            var d = filteredDocs[index].data() as Map<String, dynamic>;
            String id = filteredDocs[index].id;
            bool isGrp = d['type'] == 'group';
            
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4), // Shrink height
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                
                // Leading Icon (Type Indicator)
                leading: CircleAvatar(
                  backgroundColor: isGrp ? Colors.purple.shade50 : Colors.blue.shade50,
                  radius: 14,
                  child: Icon(isGrp ? Icons.groups : Icons.person, size: 14, color: isGrp ? Colors.purple : Colors.blue),
                ),
                
                // Title (Name)
                title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                
                // Subtitle (Details in one line)
                subtitle: Row(
                  children: [
                    _txtTag(d['category']),
                    const SizedBox(width: 4),
                    _txtTag(d['stage'] == 'On-Stage' ? 'On' : 'Off', color: Colors.orange.shade800),
                    if(_isMixedMode && d['participation']!=null && d['participation']!='open') ...[
                       const SizedBox(width: 4),
                       _txtTag(d['participation'].toString().toUpperCase().substring(0,1), color: Colors.pink)
                    ],
                    const Spacer(),
                    // Points Preview
                    Text("Pts: ${d['points'][0]}-${d['points'][1]}-${d['points'][2]}", style: const TextStyle(fontSize: 10, color: Colors.grey))
                  ],
                ),
                
                // Edit/Delete
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(onTap: ()=>_openEventDialog(id:id, data:d), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit, size: 16, color: Colors.blue))),
                    InkWell(onTap: ()=>_deleteEvent(id, d['name']), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete, size: 16, color: Colors.red))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _txtTag(String txt, {Color color = Colors.black54}) {
    return Text(txt, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color));
  }

  // 3. DIALOG (Same logic as V5.0)
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