// File: lib/screens/publish_tab.dart
// Version: 3.0
// Description: Advanced Publishing System. 'Events' tab shows ALL. Filters for Status, Cat, Gender, Stage. Confirmations added.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../layout/responsive_layout.dart'; // For globalSearchQuery

class PublishTab extends StatefulWidget {
  const PublishTab({super.key});
  @override
  State<PublishTab> createState() => _PublishTabState();
}

class _PublishTabState extends State<PublishTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final db = FirebaseFirestore.instance;

  // Data Caches
  List<DocumentSnapshot> _events = [];
  List<DocumentSnapshot> _results = [];
  List<DocumentSnapshot> _students = [];
  List<String> _teams = [];
  List<String> _categories = [];
  bool _isMixedMode = true;
  bool _isLoading = true;

  // Filters (Global for Events Tab)
  String? _filterStatus; // Pending, Published, Archived
  String? _filterCategory;
  String? _filterGender; // Used for Participation/Gender
  String? _filterStage;

  // Simulation Selection
  Set<String> _selectedForSimulation = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  void _initData() {
    // 1. Settings & Mode
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
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

    // 2. Data Streams
    db.collection('events').orderBy('createdAt', descending: true).snapshots().listen((snap) { if(mounted) setState(() => _events = snap.docs); });
    db.collection('results').snapshots().listen((snap) { if(mounted) setState(() => _results = snap.docs); });
    db.collection('students').snapshots().listen((snap) { if(mounted) setState(() { _students = snap.docs; _isLoading = false; }); });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HELPER: Get Result Status for an Event ---
  Map<String, dynamic>? _getResultData(String eventId) {
    try {
      var res = _results.firstWhere((r) => r.id == eventId);
      return res.data() as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  String _getEventStatus(String eventId) {
    var res = _getResultData(eventId);
    if (res == null) return 'Pending';
    return res['status'] == 'published' ? 'Published' : 'Archived';
  }

  // --- HELPER: Confirmation Dialog ---
  Future<bool> _confirmAction(String title, String content, {bool isDestructive = false}) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.indigo)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? Colors.red : Colors.green, foregroundColor: Colors.white),
            child: Text(isDestructive ? "Delete" : "Confirm"),
          )
        ],
      )
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.indigo,
            tabs: const [Tab(text: "EVENTS (ALL)"), Tab(text: "PUBLISHED"), Tab(text: "ARCHIVE")],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsTab(), // The Main Tab with All Filters
          _buildFilteredListTab('Published'),
          _buildFilteredListTab('Archived'),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 1: EVENTS (MASTER LIST)
  // ==============================================================================
  Widget _buildEventsTab() {
    return Column(
      children: [
        // --- 4-WAY FILTER BAR ---
        _buildFilterBar(),
        
        // --- LIST ---
        Expanded(child: _buildEventList(filterStatus: _filterStatus)), // Pass manual status filter
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // 1. Status Filter
              Expanded(child: _miniDropdown(_filterStatus, "Status", ["Pending", "Published", "Archived"], (v)=>setState(()=>_filterStatus=v))),
              const SizedBox(width: 6),
              // 2. Category Filter
              Expanded(child: _miniDropdown(_filterCategory, "Category", ["General", ..._categories], (v)=>setState(()=>_filterCategory=v))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // 3. Stage Filter
              Expanded(child: _miniDropdown(_filterStage, "Stage", ["On-Stage", "Off-Stage"], (v)=>setState(()=>_filterStage=v))),
              const SizedBox(width: 6),
              // 4. Gender/Part Filter (Mixed Only)
              if(_isMixedMode)
                 Expanded(child: _miniDropdown(_filterGender, "Gender", ["Open", "Boys", "Girls"], (v)=>setState(()=>_filterGender=v?.toLowerCase()), display: ["Common", "Boys Only", "Girls Only"]))
              else
                 const Spacer(), // Empty space
            ],
          ),
          // Reset Button
          if(_filterStatus!=null || _filterCategory!=null || _filterStage!=null || _filterGender!=null)
            InkWell(
              onTap: ()=>setState((){ _filterStatus=null; _filterCategory=null; _filterStage=null; _filterGender=null; }),
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text("Clear All Filters", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
            )
        ],
      ),
    );
  }

  Widget _miniDropdown(String? val, String hint, List<String> items, Function(String?) changed, {List<String>? display}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: val!=null ? Colors.indigo.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: val!=null ? Colors.indigo : Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val, isExpanded: true,
          hint: Text("All $hint", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          items: [
            DropdownMenuItem(value: null, child: Text("All $hint", style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ...items.asMap().entries.map((e) {
              String v = e.value;
              String t = (display!=null && display.length>e.key) ? display[e.key] : v;
              return DropdownMenuItem(value: v, child: Text(t, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis));
            })
          ],
          onChanged: changed,
        ),
      ),
    );
  }

  // ==============================================================================
  // TAB 2 & 3: FILTERED LISTS (PUBLISHED / ARCHIVED)
  // ==============================================================================
  Widget _buildFilteredListTab(String requiredStatus) {
    // This reuses the same list builder but forces the status filter
    return _buildEventList(fixedStatus: requiredStatus);
  }

  // ==============================================================================
  // CORE LIST BUILDER
  // ==============================================================================
  Widget _buildEventList({String? filterStatus, String? fixedStatus}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        
        final filteredDocs = _events.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String currentStatus = _getEventStatus(doc.id); // 'Pending', 'Published', 'Archived'

          // 1. Status Filter
          String targetStatus = fixedStatus ?? filterStatus ?? "All";
          if (targetStatus != "All" && currentStatus != targetStatus) return false;

          // 2. Category Filter
          if (_filterCategory != null && data['category'] != _filterCategory) return false;

          // 3. Stage Filter
          if (_filterStage != null && data['stage'] != _filterStage) return false;

          // 4. Gender Filter
          if (_filterGender != null && data['participation'] != _filterGender) return false;

          // 5. Search
          if (searchQuery.isNotEmpty && !data['name'].toString().toLowerCase().contains(searchQuery)) return false;

          return true;
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("No events found."));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            String id = filteredDocs[index].id;
            String status = _getEventStatus(id);
            Map<String, dynamic>? resData = _getResultData(id);

            return _buildEventCard(id, data, status, resData);
          },
        );
      },
    );
  }

  // --- EVENT CARD ---
  Widget _buildEventCard(String docId, Map<String, dynamic> data, String status, Map<String, dynamic>? resData) {
    bool isGroup = data['type'] == 'group';
    Color statusColor = status == 'Published' ? Colors.green : (status == 'Archived' ? Colors.orange : Colors.grey);
    
    String winnerText = "";
    if (resData != null) {
      dynamic w = resData['winners']['first'];
      // Handle Multiple winners (List)
      if (w is List && w.isNotEmpty) w = w[0];
      if (w != null) winnerText = "1st: ${_getWinnerName(w)}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            status == 'Published' ? Icons.check_circle : (status == 'Archived' ? Icons.archive : Icons.pending),
            color: statusColor,
          ),
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${data['category']} • ${data['stage'] ?? 'Off-Stage'} • $status", style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
            if(winnerText.isNotEmpty) Text(winnerText, style: const TextStyle(color: Colors.black87, fontSize: 12))
          ],
        ),
        trailing: _buildActionButtons(docId, data, status, resData),
      ),
    );
  }

  Widget _buildActionButtons(String docId, Map<String, dynamic> eventData, String status, Map<String, dynamic>? resData) {
    if (status == 'Pending') {
      return ElevatedButton(
        onPressed: () => _openPublishDialog(docId, eventData),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        child: const Text("Enter Result"),
      );
    } else {
      // Published or Archived
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit
          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openPublishDialog(docId, eventData, existingResult: resData, isEdit: true)),
          
          // Toggle Archive/Publish
          if (status == 'Published')
            IconButton(icon: const Icon(Icons.archive, color: Colors.orange), tooltip: "Archive", onPressed: () => _changeStatus(docId, 'archived', "Archive this result?"))
          else
            IconButton(icon: const Icon(Icons.publish, color: Colors.green), tooltip: "Publish", onPressed: () => _changeStatus(docId, 'published', "Publish this result?")),
          
          // Delete
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResult(docId)),
        ],
      );
    }
  }

  // --- ACTIONS ---
  Future<void> _changeStatus(String id, String newStatus, String msg) async {
    if (await _confirmAction("Change Status?", msg)) {
      await db.collection('results').doc(id).update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved to $newStatus")));
    }
  }

  Future<void> _deleteResult(String id) async {
    if (await _confirmAction("Delete Result?", "This will move the event back to 'Pending'.", isDestructive: true)) {
      await db.collection('results').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Result Deleted")));
    }
  }

  String _getWinnerName(dynamic winnerId) {
    if (winnerId == null) return "-";
    if (_teams.contains(winnerId)) return winnerId;
    try {
      var s = _students.firstWhere((doc) => doc.id == winnerId);
      return "${s['name']} (${s['chestNo']})";
    } catch (e) { return "Unknown"; }
  }

  // ==============================================================================
  // PUBLISH DIALOG (With Multiple Winners & Confirmations)
  // ==============================================================================
  void _openPublishDialog(String eventId, Map<String, dynamic> eventData, {Map<String, dynamic>? existingResult, bool isEdit = false}) {
    bool isGroup = eventData['type'] == 'group';
    
    // Default Points
    int defP1 = 5, defP2 = 3, defP3 = 1;
    if (isGroup) { defP1 = 10; defP2 = 8; defP3 = 5; }

    var oldPts = existingResult?['points'];
    final p1Ctrl = TextEditingController(text: (oldPts?['first'] ?? defP1).toString());
    final p2Ctrl = TextEditingController(text: (oldPts?['second'] ?? defP2).toString());
    final p3Ctrl = TextEditingController(text: (oldPts?['third'] ?? defP3).toString());

    // Winners Lists
    List<String> firsts = [];
    List<String> seconds = [];
    List<String> thirds = [];

    if (existingResult != null) {
      var w = existingResult['winners'];
      firsts = List<String>.from(w['first'] is List ? w['first'] : [w['first']])..removeWhere((e)=>e==null);
      seconds = List<String>.from(w['second'] is List ? w['second'] : [w['second']])..removeWhere((e)=>e==null);
      thirds = List<String>.from(w['third'] is List ? w['third'] : [w['third']])..removeWhere((e)=>e==null);
    }

    // Candidates
    List<Map<String, String>> candidates = [];
    if (isGroup) {
      candidates = _teams.map((t) => {'id': t, 'label': t}).toList();
    } else {
      String cat = eventData['category'];
      String part = eventData['participation'] ?? 'open';
      candidates = _students.where((s) {
        var d = s.data() as Map<String, dynamic>;
        if (d['categoryId'] != cat && cat != "General") return false;
        if (part == 'boys' && d['gender'] == 'Female') return false;
        if (part == 'girls' && d['gender'] == 'Male') return false;
        return true;
      }).map((s) => {'id': s.id, 'label': "${s['chestNo']} - ${s['name']} (${s['teamId']})"}).toList();
      candidates.sort((a,b) => a['label']!.compareTo(b['label']!));
    }

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      
      Widget winnerRow(String title, List<String> list, Color c) {
        String? sel;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: c)),
          Wrap(spacing: 5, children: list.map((id) {
             String lb = candidates.firstWhere((can) => can['id'] == id, orElse: () => {'label': id})['label']!;
             return Chip(label: Text(lb, style: const TextStyle(fontSize: 10)), deleteIcon: const Icon(Icons.close, size: 12), onDeleted: ()=>setDialogState(()=>list.remove(id)), backgroundColor: c.withOpacity(0.1));
          }).toList()),
          DropdownButtonFormField<String>(
            value: sel, isDense: true, hint: const Text("Select Winner"),
            items: candidates.map((e)=>DropdownMenuItem(value: e['id'], child: Text(e['label']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) { if(v!=null && !list.contains(v)) setDialogState(()=>list.add(v)); }
          ),
          const SizedBox(height: 10)
        ]);
      }

      return AlertDialog(
        title: Text(isEdit ? "Edit Result" : "Publish Result"),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
           Text(eventData['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
           const Divider(),
           Row(children: [Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "1st Pts"))), const SizedBox(width: 5), Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "2nd Pts"))), const SizedBox(width: 5), Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "3rd Pts")))]),
           const SizedBox(height: 15),
           winnerRow("🥇 First", firsts, Colors.amber.shade800),
           winnerRow("🥈 Second", seconds, Colors.blueGrey),
           winnerRow("🥉 Third", thirds, Colors.brown),
        ]))),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
          OutlinedButton(onPressed: () => _saveWithConfirm(ctx, eventId, eventData, p1Ctrl, p2Ctrl, p3Ctrl, firsts, seconds, thirds, 'archived', isEdit), child: const Text("Archive")),
          ElevatedButton(onPressed: () => _saveWithConfirm(ctx, eventId, eventData, p1Ctrl, p2Ctrl, p3Ctrl, firsts, seconds, thirds, 'published', isEdit), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("Publish"))
        ],
      );
    }));
  }

  Future<void> _saveWithConfirm(BuildContext ctx, String eid, Map edata, TextEditingController p1, TextEditingController p2, TextEditingController p3, List f, List s, List t, String status, bool isEdit) async {
    if (f.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First Prize Required"))); return; }
    
    // Confirmation Check
    String action = isEdit ? "Update" : "Save";
    if (await _confirmAction("$action Result?", "Status will be set to: ${status.toUpperCase()}")) {
       await db.collection('results').doc(eid).set({
         'eventId': eid, 'eventName': edata['name'], 'category': edata['category'], 'type': edata['type'], 'status': status,
         'points': {'first': int.parse(p1.text), 'second': int.parse(p2.text), 'third': int.parse(p3.text)},
         'winners': {'first': f, 'second': s, 'third': t},
         'publishedAt': FieldValue.serverTimestamp()
       });
       if(mounted) Navigator.pop(ctx);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Result $status!")));
    }
  }
}