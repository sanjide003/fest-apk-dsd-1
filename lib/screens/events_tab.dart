// File: lib/screens/events_tab.dart
// Version: 2.0
// Description: Event Creation, Editing & Listing with Smart Defaults for Points & Limits.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final db = FirebaseFirestore.instance;

  // Filters & Settings Data
  String? _filterCategory;
  List<String> _categories = [];
  bool _isMixedMode = true; // Default mixed

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // 1. Get Categories from Settings
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists) {
        if(mounted) {
          setState(() {
            _categories = List<String>.from(snap.data()?['categories'] ?? []);
          });
        }
      }
    });

    // 2. Get Fest Mode
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
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
            // --- FILTER BAR ---
            _buildFilterBar(),
            const SizedBox(height: 16),
            
            // --- EVENTS LIST ---
            Expanded(child: _buildEventsList()),
          ],
        ),
      ),
      
      // --- ADD BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventDialog(), // Add New
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW EVENT", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 1. FILTER BAR
  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.filter_list, color: Colors.grey),
            const SizedBox(width: 10),
            const Text("Filter: ", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<String>(
                value: _filterCategory,
                hint: const Text("All Categories"),
                isExpanded: true,
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text("All Categories")),
                  const DropdownMenuItem(value: "General", child: Text("General")), // Static General
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) => setState(() => _filterCategory = v),
              ),
            ),
            if (_filterCategory != null)
              IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setState(() => _filterCategory = null))
          ],
        ),
      ),
    );
  }

  // 2. EVENTS LIST
  Widget _buildEventsList() {
    Query query = db.collection('events').orderBy('createdAt', descending: true);
    
    // Client-side filtering is better for 'General' + Dynamic categories mix
    // but for simple query, we can do this:
    if (_filterCategory != null) {
      query = query.where('category', isEqualTo: _filterCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text("No events created yet."));

        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snap.data!.docs[index].data() as Map<String, dynamic>;
            String docId = snap.data!.docs[index].id;
            
            bool isGroup = data['type'] == 'group';
            bool onStage = data['stage'] == 'On-Stage';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => _openEventDialog(id: docId, data: data), // Edit on Tap
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['name'], 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _deleteEvent(docId, data['name']),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTag(isGroup ? "GROUP" : "SINGLE", isGroup ? Colors.purple : Colors.blue),
                          _buildTag(data['category'], Colors.grey.shade700),
                          if(onStage) _buildTag("ON-STAGE", Colors.orange.shade800),
                          // Participation Tag (Only if Mixed)
                          if(_isMixedMode && data['participation'] != null)
                             _buildTag(data['participation'].toString().toUpperCase(), 
                               data['participation']=='girls' ? Colors.pink : 
                               (data['participation']=='boys' ? Colors.blue.shade800 : Colors.teal)
                             ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isGroup 
                             ? "Teams: ${data['limits']['maxTeams']} (Size: ${data['limits']['teamSize']})"
                             : "Max Participants: ${data['limits']['maxParticipants']}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
                          ),
                          Text(
                            "Pts: ${data['points'][0]}-${data['points'][1]}-${data['points'][2]}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  // ==============================================================================
  // 3. ADD / EDIT EVENT DIALOG
  // ==============================================================================
  void _openEventDialog({String? id, Map<String, dynamic>? data}) {
    // Controllers
    final nameCtrl = TextEditingController(text: data?['name']);
    final p1Ctrl = TextEditingController(text: data != null ? data['points'][0].toString() : '5');
    final p2Ctrl = TextEditingController(text: data != null ? data['points'][1].toString() : '3');
    final p3Ctrl = TextEditingController(text: data != null ? data['points'][2].toString() : '1');
    
    // Limits
    final limit1Ctrl = TextEditingController(text: data != null ? (data['type']=='group' ? data['limits']['maxTeams'].toString() : data['limits']['maxParticipants'].toString()) : '3');
    final limit2Ctrl = TextEditingController(text: data != null && data['type']=='group' ? data['limits']['teamSize'].toString() : '5');

    // State Variables
    String selType = data?['type'] ?? 'single';
    String? selCategory = data?['category'];
    String selStage = data?['stage'] ?? 'Off-Stage';
    String selPart = data?['participation'] ?? 'open'; // open=Common, boys, girls

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          // Logic to update defaults when Type changes
          void onTypeChanged(String? v) {
            if(v == null) return;
            setDialogState(() {
              selType = v;
              if (v == 'single') {
                p1Ctrl.text = '5'; p2Ctrl.text = '3'; p3Ctrl.text = '1';
                limit1Ctrl.text = '3'; // Max Participants
              } else {
                p1Ctrl.text = '10'; p2Ctrl.text = '5'; p3Ctrl.text = '2';
                limit1Ctrl.text = '2'; // Max Teams
                limit2Ctrl.text = '5'; // Team Size
              }
            });
          }

          return AlertDialog(
            title: Text(id == null ? "New Event" : "Edit Event"),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Name & Cat
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Event Name")),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selCategory,
                  hint: const Text("Category"),
                  items: [
                    const DropdownMenuItem(value: "General", child: Text("General")),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ], 
                  onChanged: (v) => setDialogState(() => selCategory = v),
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                const SizedBox(height: 10),

                // 2. Type & Stage
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField(
                      value: selType,
                      items: const [DropdownMenuItem(value: "single", child: Text("Single")), DropdownMenuItem(value: "group", child: Text("Group"))],
                      onChanged: onTypeChanged,
                      decoration: const InputDecoration(labelText: "Type"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField(
                      value: selStage,
                      items: const [DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")), DropdownMenuItem(value: "On-Stage", child: Text("On-Stage"))],
                      onChanged: (v) => setDialogState(() => selStage = v!),
                      decoration: const InputDecoration(labelText: "Stage"),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // 3. Participation (Mixed Mode Only)
                if (_isMixedMode) ...[
                  DropdownButtonFormField(
                    value: selPart,
                    items: const [
                      DropdownMenuItem(value: "open", child: Text("Common (Boys & Girls)")),
                      DropdownMenuItem(value: "boys", child: Text("Boys Only")),
                      DropdownMenuItem(value: "girls", child: Text("Girls Only")),
                    ],
                    onChanged: (v) => setDialogState(() => selPart = v!),
                    decoration: const InputDecoration(labelText: "Participation"),
                  ),
                  const SizedBox(height: 10),
                ],

                // 4. Points
                const Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                Row(children: [
                  Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                  const SizedBox(width: 5),
                  Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                  const SizedBox(width: 5),
                  Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                ]),
                const SizedBox(height: 10),

                // 5. Limits (Dynamic)
                const Text("Limits / Restrictions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                if (selType == 'single')
                  TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Participants per House"))
                else
                  Row(children: [
                    Expanded(child: TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Teams/House"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: limit2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Participants/Team"))),
                  ])
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || selCategory == null) return;

                  Map<String, dynamic> saveData = {
                    'name': nameCtrl.text.trim(),
                    'category': selCategory,
                    'type': selType,
                    'stage': selStage,
                    'participation': _isMixedMode ? selPart : 'boys', // If not mixed, assume boys/open default logic
                    'points': [
                      int.tryParse(p1Ctrl.text) ?? 0,
                      int.tryParse(p2Ctrl.text) ?? 0,
                      int.tryParse(p3Ctrl.text) ?? 0,
                    ],
                    'limits': selType == 'single' 
                      ? { 'maxParticipants': int.tryParse(limit1Ctrl.text) ?? 3 }
                      : { 'maxTeams': int.tryParse(limit1Ctrl.text) ?? 2, 'teamSize': int.tryParse(limit2Ctrl.text) ?? 5 },
                    'createdAt': FieldValue.serverTimestamp(), // Update timestamp on edit too? Usually verify this.
                  };

                  if (id == null) {
                    await db.collection('events').add(saveData);
                  } else {
                    // Don't overwrite created date on edit
                    saveData.remove('createdAt');
                    await db.collection('events').doc(id).update(saveData);
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully")));
                },
                child: Text(id == null ? "Create" : "Update"),
              )
            ],
          );
        }
      ),
    );
  }

  // Delete
  Future<void> _deleteEvent(String id, String name) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Event?"),
      content: Text("Are you sure you want to delete '$name'?"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")),
        ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete"))
      ],
    )) ?? false;

    if(confirm) {
      await db.collection('events').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
    }
  }
}