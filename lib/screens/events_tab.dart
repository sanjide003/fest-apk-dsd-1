// File: lib/screens/events_tab.dart
// Version: 3.0
// Description: Updated Points Logic (10,8,5), Edit Icon, Search Integration, Active Dropdown Highlight.

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
    // 1. Categories
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    // 2. Mode
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    // 3. Events Listener (For Search & Filter)
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
            _buildFilterBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildEventsList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEventDialog(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW EVENT", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 1. FILTER BAR (Enhanced)
  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.filter_list, color: Colors.grey),
            const SizedBox(width: 10),
            
            // Category Filter
            Expanded(
              child: _styledDropdown(
                value: _filterCategory,
                label: "Category",
                items: ["General", ..._categories], // 'General' added manually
                onChanged: (v) => setState(() => _filterCategory = v),
              ),
            ),
            const SizedBox(width: 10),
            
            // Type Filter
            Expanded(
              child: _styledDropdown(
                value: _filterType,
                label: "Type",
                items: ["Single", "Group"],
                onChanged: (v) => setState(() => _filterType = v?.toLowerCase()),
              ),
            ),

            // Clear Button
            if (_filterCategory != null || _filterType != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: "Clear Filters",
                onPressed: () => setState(() { _filterCategory = null; _filterType = null; }),
              )
          ],
        ),
      ),
    );
  }

  // Custom Dropdown with Active Highlight
  Widget _styledDropdown({required String? value, required String label, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true, fillColor: Colors.white,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text("All ${label}s", style: const TextStyle(color: Colors.grey))),
        ...items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            // Active Item Highlight (Bold & Color)
            style: TextStyle(
              fontWeight: value == item ? FontWeight.bold : FontWeight.normal,
              color: value == item ? Colors.indigo : Colors.black87,
            ),
          ),
        ))
      ],
      onChanged: onChanged,
      selectedItemBuilder: (context) {
        return [
          const Text("All", style: TextStyle(color: Colors.grey)),
          ...items.map((item) => Text(item, style: const TextStyle(fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)))
        ];
      },
    );
  }

  // 2. EVENTS LIST (With Search & Edit Icon)
  Widget _buildEventsList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_allEvents.isEmpty) return const Center(child: Text("No events created yet."));

    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        
        final filteredDocs = _allEvents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Filters
          if (_filterCategory != null && data['category'] != _filterCategory) return false;
          if (_filterType != null && data['type'] != _filterType) return false;
          
          // Search (Name)
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
                          // Edit & Delete Icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _openEventDialog(id: docId, data: data),
                                tooltip: "Edit",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteEvent(docId, data['name']),
                                tooltip: "Delete",
                              ),
                            ],
                          )
                        ],
                      ),
                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTag(isGroup ? "GROUP" : "SINGLE", isGroup ? Colors.purple : Colors.blue),
                          _buildTag(data['category'], Colors.grey.shade700),
                          if(onStage) _buildTag("ON-STAGE", Colors.orange.shade800),
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

  // 3. ADD / EDIT DIALOG (Updated Points)
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
                // NEW POINTS LOGIC: 10, 8, 5
                p1Ctrl.text = '10'; p2Ctrl.text = '8'; p3Ctrl.text = '5';
                limit1Ctrl.text = '2'; 
                limit2Ctrl.text = '5';
              }
            });
          }

          return AlertDialog(
            title: Text(id == null ? "New Event" : "Edit Event"),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (_isMixedMode) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    value: selPart,
                    items: const [
                      DropdownMenuItem(value: "open", child: Text("Common")),
                      DropdownMenuItem(value: "boys", child: Text("Boys Only")),
                      DropdownMenuItem(value: "girls", child: Text("Girls Only")),
                    ],
                    onChanged: (v) => setDialogState(() => selPart = v!),
                    decoration: const InputDecoration(labelText: "Participation"),
                  )
                ],
                const SizedBox(height: 10),
                const Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 5),
                  Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 5),
                  Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                const Text("Limits", style: TextStyle(fontWeight: FontWeight.bold)),
                if (selType == 'single')
                  TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Participants per House"))
                else
                  Row(children: [
                    Expanded(child: TextField(controller: limit1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Max Teams"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: limit2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Size/Team"))),
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
                    'participation': _isMixedMode ? selPart : 'boys',
                    'points': [
                      int.tryParse(p1Ctrl.text) ?? 0,
                      int.tryParse(p2Ctrl.text) ?? 0,
                      int.tryParse(p3Ctrl.text) ?? 0,
                    ],
                    'limits': selType == 'single' 
                      ? { 'maxParticipants': int.tryParse(limit1Ctrl.text) ?? 3 }
                      : { 'maxTeams': int.tryParse(limit1Ctrl.text) ?? 2, 'teamSize': int.tryParse(limit2Ctrl.text) ?? 5 },
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  if (id == null) {
                    await db.collection('events').add(saveData);
                  } else {
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