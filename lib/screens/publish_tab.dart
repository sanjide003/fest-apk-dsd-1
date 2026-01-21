// File: lib/screens/publish_tab.dart
// Version: 1.0
// Description: Result Entry & Publishing System. Handles Single (Student Select) & Group (Team Select).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  void _initData() {
    // 1. Teams from Settings
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _teams = List<String>.from(snap.data()?['teams'] ?? []));
      }
    });

    // 2. Events
    db.collection('events').snapshots().listen((snap) {
      if(mounted) setState(() => _events = snap.docs);
    });

    // 3. Results
    db.collection('results').snapshots().listen((snap) {
      if(mounted) setState(() => _results = snap.docs);
    });

    // 4. Students (For Single Event Selection)
    db.collection('students').snapshots().listen((snap) {
      if(mounted) setState(() { _students = snap.docs; _isLoading = false; });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Separate Pending & Published
    List<String> publishedIds = _results.map((r) => r.id).toList();
    List<DocumentSnapshot> pendingEvents = _events.where((e) => !publishedIds.contains(e.id)).toList();
    List<DocumentSnapshot> publishedEvents = _events.where((e) => publishedIds.contains(e.id)).toList();

    // Sort published by timestamp (latest first) logic requires joining, 
    // simpler to just list them. We can refine sorting later.

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TabBar(
        controller: _tabController,
        labelColor: Colors.indigo,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.indigo,
        tabs: [
          Tab(text: "PENDING (${pendingEvents.length})"),
          Tab(text: "PUBLISHED (${publishedEvents.length})"),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(pendingEvents),
          _buildPublishedList(publishedEvents),
        ],
      ),
    );
  }

  // --- 1. PENDING LIST ---
  Widget _buildPendingList(List<DocumentSnapshot> events) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (events.isEmpty) return const Center(child: Text("No pending events! All published.", style: TextStyle(color: Colors.green)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        var data = events[index].data() as Map<String, dynamic>;
        bool isGroup = data['type'] == 'group';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isGroup ? Colors.purple.shade50 : Colors.blue.shade50,
              child: Icon(isGroup ? Icons.groups : Icons.person, color: isGroup ? Colors.purple : Colors.blue),
            ),
            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${data['category']} • ${data['stage'] ?? 'Off-Stage'}"),
            trailing: ElevatedButton.icon(
              onPressed: () => _openPublishDialog(events[index].id, data),
              icon: const Icon(Icons.emoji_events, size: 16),
              label: const Text("Publish"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            ),
          ),
        );
      },
    );
  }

  // --- 2. PUBLISHED LIST ---
  Widget _buildPublishedList(List<DocumentSnapshot> events) {
    if (events.isEmpty) return const Center(child: Text("No results published yet."));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        var data = events[index].data() as Map<String, dynamic>;
        String eventId = events[index].id;
        
        // Find Result Data
        var resDoc = _results.firstWhere((r) => r.id == eventId, orElse: () => _results[0]);
        var resData = resDoc.data() as Map<String, dynamic>;
        var winners = resData['winners'] ?? {};

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("1st: ${_getWinnerName(winners['first'])}"),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _resultRow("First", winners['first'], resData['points']['first']),
                    _resultRow("Second", winners['second'], resData['points']['second']),
                    _resultRow("Third", winners['third'], resData['points']['third']),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openPublishDialog(eventId, data, editData: resData),
                          icon: const Icon(Icons.edit), 
                          label: const Text("Edit Result")
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: () => _deleteResult(eventId),
                          icon: const Icon(Icons.delete, color: Colors.red), 
                          label: const Text("Delete", style: TextStyle(color: Colors.red))
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _resultRow(String rank, dynamic winner, dynamic pts) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rank, style: const TextStyle(color: Colors.grey)),
          Text(_getWinnerName(winner), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("$pts Pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        ],
      ),
    );
  }

  // --- HELPER: GET WINNER NAME ---
  // If Group, returns Team Name. If Single, returns Student Name (Chest No).
  String _getWinnerName(dynamic winnerId) {
    if (winnerId == null) return "-";
    if (_teams.contains(winnerId)) return winnerId; // It's a team name
    
    // Try finding student
    try {
      var s = _students.firstWhere((doc) => doc.id == winnerId);
      return "${s['name']} (${s['chestNo']})";
    } catch (e) {
      return "Unknown ($winnerId)";
    }
  }

  // ==============================================================================
  // 3. PUBLISH DIALOG (THE CORE LOGIC)
  // ==============================================================================
  void _openPublishDialog(String eventId, Map<String, dynamic> eventData, {Map<String, dynamic>? editData}) {
    bool isGroup = eventData['type'] == 'group';
    
    // Points Controllers
    final p1Ctrl = TextEditingController(text: editData != null ? editData['points']['first'].toString() : eventData['points'][0].toString());
    final p2Ctrl = TextEditingController(text: editData != null ? editData['points']['second'].toString() : eventData['points'][1].toString());
    final p3Ctrl = TextEditingController(text: editData != null ? editData['points']['third'].toString() : eventData['points'][2].toString());

    // Selected Winners (ID for students, Name for Teams)
    String? first = editData?['winners']['first'];
    String? second = editData?['winners']['second'];
    String? third = editData?['winners']['third'];

    // Filter Eligible Candidates
    List<Map<String, String>> candidates = [];
    
    if (isGroup) {
      // Teams
      candidates = _teams.map((t) => {'id': t, 'label': t}).toList();
    } else {
      // Students (Filtered by Category & Gender)
      String cat = eventData['category'];
      String part = eventData['participation'] ?? 'open'; // boys, girls, open
      
      var filtered = _students.where((s) {
        var d = s.data() as Map<String, dynamic>;
        if (d['categoryId'] != cat && cat != "General") return false; // General allows all? Usually specific.
        
        // Gender Check
        if (part == 'boys' && d['gender'] == 'Female') return false;
        if (part == 'girls' && d['gender'] == 'Male') return false;
        
        return true;
      }).toList();

      candidates = filtered.map((s) {
        var d = s.data() as Map<String, dynamic>;
        return {'id': s.id, 'label': "${d['chestNo']} - ${d['name']} (${d['teamId']})"};
      }).toList();
      
      // Sort by Chest No
      candidates.sort((a,b) => a['label']!.compareTo(b['label']!));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(editData == null ? "Publish Result" : "Edit Result"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eventData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                  Text("Category: ${eventData['category']} | Type: ${eventData['type']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Divider(),
                  
                  // Points
                  const Text("Points", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(children: [
                    Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "1st Pts"))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "2nd Pts"))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "3rd Pts"))),
                  ]),
                  const SizedBox(height: 15),

                  // Winners
                  _winnerDropdown("First Prize 🥇", first, candidates, (v) => setDialogState(() => first = v)),
                  const SizedBox(height: 10),
                  _winnerDropdown("Second Prize 🥈", second, candidates, (v) => setDialogState(() => second = v)),
                  const SizedBox(height: 10),
                  _winnerDropdown("Third Prize 🥉", third, candidates, (v) => setDialogState(() => third = v)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (first == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First Prize is mandatory")));
                    return;
                  }

                  Map<String, dynamic> resultData = {
                    'eventId': eventId,
                    'eventName': eventData['name'],
                    'category': eventData['category'],
                    'type': eventData['type'],
                    'points': {
                      'first': int.tryParse(p1Ctrl.text) ?? 0,
                      'second': int.tryParse(p2Ctrl.text) ?? 0,
                      'third': int.tryParse(p3Ctrl.text) ?? 0,
                    },
                    'winners': {
                      'first': first,
                      'second': second,
                      'third': third,
                    },
                    'publishedAt': FieldValue.serverTimestamp(),
                  };

                  await db.collection('results').doc(eventId).set(resultData);
                  
                  if(mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Result Published Successfully!")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("PUBLISH"),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _winnerDropdown(String label, String? value, List<Map<String, String>> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem(value: null, child: Text("None")),
        ...items.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['label']!, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _deleteResult(String eventId) async {
    if(await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Result?"), content: const Text("This will move the event back to Pending list."), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Delete"))])) ?? false) {
      await db.collection('results').doc(eventId).delete();
    }
  }
}