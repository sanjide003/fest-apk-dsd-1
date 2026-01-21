// File: lib/screens/publish_tab.dart
// Version: 1.0
// Description: Result Publishing System (Pending, Published, Simulation). No Photo Upload.

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
  List<String> _categories = [];
  
  // Filter for Pending Tab
  String? _filterCategory;

  // Simulation State
  Map<String, int> _simulatedExtraPoints = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 Tabs
    _initData();
  }

  void _initData() {
    // 1. Settings (Teams & Categories)
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          // Init Simulation Map
          for (var t in _teams) { _simulatedExtraPoints[t] = 0; }
        });
      }
    });

    // 2. Events
    db.collection('events').orderBy('createdAt').snapshots().listen((snap) {
      if(mounted) setState(() => _events = snap.docs);
    });

    // 3. Results
    db.collection('results').snapshots().listen((snap) {
      if(mounted) setState(() => _results = snap.docs);
    });

    // 4. Students
    db.collection('students').orderBy('chestNo').snapshots().listen((snap) {
      if(mounted) setState(() => _students = snap.docs);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "PENDING"),
              Tab(text: "PUBLISHED"),
              Tab(text: "SIMULATION"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildPublishedTab(),
          _buildSimulationTab(),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 1: PENDING EVENTS (ENTRY)
  // ==============================================================================
  Widget _buildPendingTab() {
    // Logic: Find events that are NOT in results
    List<String> publishedIds = _results.map((r) => r.id).toList();
    List<DocumentSnapshot> pending = _events.where((e) => !publishedIds.contains(e.id)).toList();

    // Apply Category Filter
    if (_filterCategory != null) {
      pending = pending.where((e) => e['category'] == _filterCategory).toList();
    }

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: _filterCategory,
                  hint: const Text("Filter by Category"),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Categories")),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  ],
                  onChanged: (v) => setState(() => _filterCategory = v),
                ),
              ),
            ],
          ),
        ),
        
        // List
        Expanded(
          child: pending.isEmpty 
            ? const Center(child: Text("No pending events found."))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: pending.length,
                separatorBuilder: (c,i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var data = pending[index].data() as Map<String, dynamic>;
                  return _buildEventCard(pending[index].id, data, isPending: true);
                },
              ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 2: PUBLISHED EVENTS (HISTORY)
  // ==============================================================================
  Widget _buildPublishedTab() {
    // Logic: Find events that ARE in results
    List<String> publishedIds = _results.map((r) => r.id).toList();
    List<DocumentSnapshot> published = _events.where((e) => publishedIds.contains(e.id)).toList();

    return published.isEmpty 
      ? const Center(child: Text("No results published yet."))
      : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: published.length,
          separatorBuilder: (c,i) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var data = published[index].data() as Map<String, dynamic>;
            return _buildEventCard(published[index].id, data, isPending: false);
          },
        );
  }

  // --- SHARED EVENT CARD ---
  Widget _buildEventCard(String docId, Map<String, dynamic> data, {required bool isPending}) {
    bool isGroup = data['type'] == 'group';
    
    // For Published: Get Winner Info
    String winnerText = "";
    if (!isPending) {
      try {
        var res = _results.firstWhere((r) => r.id == docId);
        var rData = res.data() as Map<String, dynamic>;
        var w = rData['winners']['first'];
        if (isGroup) {
          winnerText = "1st: $w"; // Team Name
        } else {
          // Find student name
          var s = _students.firstWhere((s) => s.id == w, orElse: () => _students[0]); // Safety
          winnerText = s.id == w ? "1st: ${s['name']} (${s['chestNo']})" : "1st: Unknown";
        }
      } catch (e) { winnerText = "Error loading result"; }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange.shade50 : Colors.green.shade50,
          child: Icon(isGroup ? Icons.groups : Icons.person, color: isPending ? Colors.orange : Colors.green),
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${data['category']} • ${data['type'].toString().toUpperCase()}"),
            if(!isPending) Text(winnerText, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
          ],
        ),
        trailing: isPending 
          ? ElevatedButton(
              onPressed: () => _openPublishDialog(docId, data),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text("Publish"),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openPublishDialog(docId, data, isEdit: true)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResult(docId)),
              ],
            ),
      ),
    );
  }

  // ==============================================================================
  // TAB 3: SIMULATION (PLAYGROUND)
  // ==============================================================================
  Widget _buildSimulationTab() {
    // 1. Calculate Real Scores
    Map<String, int> realScores = {};
    for (var t in _teams) realScores[t] = 0;

    for (var res in _results) {
      var d = res.data() as Map<String, dynamic>;
      var pts = d['points'] ?? {'first': 5, 'second': 3, 'third': 1};
      var wins = d['winners'] ?? {};
      
      void add(dynamic w, int p) {
        if(w==null) return;
        if(_teams.contains(w)) {
          realScores[w] = (realScores[w] ?? 0) + p;
        } else {
          try {
            var s = _students.firstWhere((s) => s.id == w);
            String t = s['teamId'];
            realScores[t] = (realScores[t] ?? 0) + p;
          } catch(e){}
        }
      }
      add(wins['first'], pts['first'] is int ? pts['first'] : 5);
      add(wins['second'], pts['second'] is int ? pts['second'] : 3);
      add(wins['third'], pts['third'] is int ? pts['third'] : 1);
    }

    // 2. Combine with Simulation
    Map<String, int> totalSimScores = {};
    for (var t in _teams) {
      totalSimScores[t] = (realScores[t] ?? 0) + (_simulatedExtraPoints[t] ?? 0);
    }

    // 3. Sort
    var sorted = totalSimScores.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple.shade50,
          child: const Row(children: [Icon(Icons.science, color: Colors.purple), SizedBox(width: 10), Expanded(child: Text("Simulation Mode: Add points here to test ranking changes. This does NOT affect real results.", style: TextStyle(fontSize: 12, color: Colors.purple)))]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (c,i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              String team = sorted[index].key;
              int score = sorted[index].value;
              int real = realScores[team] ?? 0;
              int sim = _simulatedExtraPoints[team] ?? 0;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text("${index+1}")),
                  title: Text(team, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Real: $real + Sim: $sim", style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _simulatedExtraPoints[team] = (_simulatedExtraPoints[team]! - 1))),
                      Text("$score", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => setState(() => _simulatedExtraPoints[team] = (_simulatedExtraPoints[team]! + 5))), // Adds 5 pts as example
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: () => setState(() { for(var t in _teams) _simulatedExtraPoints[t] = 0; }), icon: const Icon(Icons.refresh), label: const Text("Reset Simulation")),
          ),
        )
      ],
    );
  }

  // ==============================================================================
  // PUBLISH MODAL (THE CORE)
  // ==============================================================================
  void _openPublishDialog(String eventId, Map<String, dynamic> eventData, {bool isEdit = false}) {
    bool isGroup = eventData['type'] == 'group';
    
    // Default Points
    int defP1 = 5, defP2 = 3, defP3 = 1;
    if (isGroup) { defP1 = 10; defP2 = 8; defP3 = 5; }

    // If Edit, Load existing
    Map<String, dynamic>? existingRes;
    if (isEdit) {
      existingRes = _results.firstWhere((r) => r.id == eventId).data() as Map<String, dynamic>;
    }

    final p1Ctrl = TextEditingController(text: existingRes?['points']['first'].toString() ?? defP1.toString());
    final p2Ctrl = TextEditingController(text: existingRes?['points']['second'].toString() ?? defP2.toString());
    final p3Ctrl = TextEditingController(text: existingRes?['points']['third'].toString() ?? defP3.toString());

    String? first = existingRes?['winners']['first'];
    String? second = existingRes?['winners']['second'];
    String? third = existingRes?['winners']['third'];

    // Generate Dropdown Items
    List<DropdownMenuItem<String>> items = [];
    
    if (isGroup) {
      // Teams
      items = _teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList();
    } else {
      // Students (Filtered)
      String cat = eventData['category'];
      String part = eventData['participation'] ?? 'open';
      
      var filtered = _students.where((s) {
        var d = s.data() as Map<String, dynamic>;
        if (d['categoryId'] != cat && cat != "General") return false;
        if (part == 'boys' && d['gender'] == 'Female') return false;
        if (part == 'girls' && d['gender'] == 'Male') return false;
        return true;
      }).toList();

      items = filtered.map((s) {
        var d = s.data() as Map<String, dynamic>;
        return DropdownMenuItem(value: s.id, child: Text("${d['chestNo']} - ${d['name']} (${d['teamId']})", overflow: TextOverflow.ellipsis));
      }).toList();
    }

    // Add "None" option
    items.insert(0, const DropdownMenuItem(value: null, child: Text("None", style: TextStyle(color: Colors.grey))));

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: Text(isEdit ? "Edit Result" : "Publish Result"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eventData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              // Points
              Row(children: [
                Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "1st Pts"))), const SizedBox(width: 5),
                Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "2nd Pts"))), const SizedBox(width: 5),
                Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "3rd Pts"))),
              ]),
              const SizedBox(height: 15),
              // Winners
              DropdownButtonFormField(value: first, items: items, onChanged: (v)=>setDialogState(()=>first=v), decoration: const InputDecoration(labelText: "🥇 First Prize")),
              const SizedBox(height: 10),
              DropdownButtonFormField(value: second, items: items, onChanged: (v)=>setDialogState(()=>second=v), decoration: const InputDecoration(labelText: "🥈 Second Prize")),
              const SizedBox(height: 10),
              DropdownButtonFormField(value: third, items: items, onChanged: (v)=>setDialogState(()=>third=v), decoration: const InputDecoration(labelText: "🥉 Third Prize")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            if (first == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First Prize is required"))); return; }
            
            await db.collection('results').doc(eventId).set({
              'eventId': eventId,
              'eventName': eventData['name'],
              'category': eventData['category'],
              'type': eventData['type'],
              'points': { 'first': int.parse(p1Ctrl.text), 'second': int.parse(p2Ctrl.text), 'third': int.parse(p3Ctrl.text) },
              'winners': { 'first': first, 'second': second, 'third': third },
              'publishedAt': FieldValue.serverTimestamp()
            });
            if(mounted) Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Published!")));
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("PUBLISH"))
        ],
      );
    }));
  }

  Future<void> _deleteResult(String id) async {
    if(await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete?"), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false) {
      await db.collection('results').doc(id).delete();
    }
  }
}