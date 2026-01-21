// File: lib/screens/publish_tab.dart
// Version: 2.0
// Description: Advanced Publishing System. Supports Multiple Winners, Live Ticker, Archive, Simulation.

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
  
  // Filter
  String? _filterCategory;

  // Simulation Selection
  Set<String> _selectedForSimulation = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  void _initData() {
    // 1. Settings
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    // 2. Events & Results & Students
    db.collection('events').orderBy('createdAt').snapshots().listen((snap) { if(mounted) setState(() => _events = snap.docs); });
    db.collection('results').snapshots().listen((snap) { if(mounted) setState(() => _results = snap.docs); });
    db.collection('students').snapshots().listen((snap) { if(mounted) setState(() => _students = snap.docs); });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- HELPER: Calculate Scores ---
  // returns { "Red": 120, "Blue": 110 }
  Map<String, int> _calculateScores({List<DocumentSnapshot>? customResults}) {
    Map<String, int> scores = { for (var t in _teams) t: 0 };
    List<DocumentSnapshot> targetResults = customResults ?? _results.where((r) => r['status'] == 'published').toList();

    for (var res in targetResults) {
      var d = res.data() as Map<String, dynamic>;
      var pts = d['points'] ?? {'first': 5, 'second': 3, 'third': 1};
      var winners = d['winners'] ?? {};

      // Helper to add points (Supports List for Multiple Winners)
      void addPoints(dynamic winnerData, int points) {
        if (winnerData == null) return;
        List list = (winnerData is List) ? winnerData : [winnerData];
        
        for (var w in list) {
          if (_teams.contains(w)) {
            scores[w] = (scores[w] ?? 0) + points;
          } else {
            // Find student's team
            try {
              var s = _students.firstWhere((st) => st.id == w);
              String t = s['teamId'];
              scores[t] = (scores[t] ?? 0) + points;
            } catch (e) {}
          }
        }
      }

      addPoints(winners['first'], pts['first']);
      addPoints(winners['second'], pts['second']);
      addPoints(winners['third'], pts['third']);
    }
    return scores;
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
            tabs: const [Tab(text: "PENDING"), Tab(text: "PUBLISHED"), Tab(text: "ARCHIVE")],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildPublishedTab(),
          _buildArchiveTab(),
        ],
      ),
    );
  }

  // ==============================================================================
  // TAB 1: PENDING (New Entry)
  // ==============================================================================
  Widget _buildPendingTab() {
    List<String> resultIds = _results.map((r) => r.id).toList();
    List<DocumentSnapshot> pending = _events.where((e) => !resultIds.contains(e.id)).toList();

    if (_filterCategory != null) pending = pending.where((e) => e['category'] == _filterCategory).toList();

    return Column(
      children: [
        // Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: DropdownButton<String>(
            value: _filterCategory,
            hint: const Text("Filter Category"),
            isExpanded: true,
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem(value: null, child: Text("All Categories")),
              ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
            ],
            onChanged: (v) => setState(() => _filterCategory = v),
          ),
        ),
        Expanded(
          child: pending.isEmpty 
           ? const Center(child: Text("No pending events."))
           : ListView.builder(
               padding: const EdgeInsets.all(12),
               itemCount: pending.length,
               itemBuilder: (c, i) => _buildEventCard(pending[i], status: 'pending'),
             ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 2: PUBLISHED (With Ticker)
  // ==============================================================================
  Widget _buildPublishedTab() {
    List<DocumentSnapshot> published = _results.where((r) => r['status'] == 'published').toList();
    Map<String, int> liveScores = _calculateScores();
    var sortedScores = liveScores.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // LIVE TICKER
        Container(
          height: 50,
          color: Colors.indigo.shade900,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedScores.length,
            separatorBuilder: (c,i) => const VerticalDivider(color: Colors.white24, width: 20),
            itemBuilder: (c, i) {
              var entry = sortedScores[i];
              return Center(
                child: Row(
                  children: [
                    Text("#${i+1} ", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    Text("${entry.key}: ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("${entry.value} pts", style: const TextStyle(color: Colors.white)),
                  ],
                ),
              );
            },
          ),
        ),
        
        // LIST
        Expanded(
          child: published.isEmpty
           ? const Center(child: Text("No results published."))
           : ListView.builder(
               padding: const EdgeInsets.all(12),
               itemCount: published.length,
               itemBuilder: (c, i) {
                 // Join with Event Data
                 var res = published[i];
                 var evt = _events.firstWhere((e) => e.id == res.id, orElse: () => _events[0]); // Fallback
                 return _buildEventCard(evt, status: 'published', resultDoc: res);
               },
             ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 3: ARCHIVE (Simulation)
  // ==============================================================================
  Widget _buildArchiveTab() {
    List<DocumentSnapshot> archived = _results.where((r) => r['status'] == 'archived').toList();

    return Scaffold( // Nested Scaffold for FAB
      backgroundColor: Colors.transparent,
      floatingActionButton: _selectedForSimulation.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _openSimulationModal,
            icon: const Icon(Icons.analytics),
            label: Text("Simulate (${_selectedForSimulation.length})"),
            backgroundColor: Colors.purple,
          )
        : null,
      body: archived.isEmpty
        ? const Center(child: Text("Archive is empty."))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: archived.length,
            itemBuilder: (c, i) {
              var res = archived[i];
              var evt = _events.firstWhere((e) => e.id == res.id, orElse: () => _events[0]);
              bool isSel = _selectedForSimulation.contains(res.id);

              return Card(
                color: isSel ? Colors.purple.shade50 : null,
                child: ListTile(
                  leading: Checkbox(
                    value: isSel,
                    onChanged: (v) => setState(() {
                      v! ? _selectedForSimulation.add(res.id) : _selectedForSimulation.remove(res.id);
                    }),
                  ),
                  title: Text(evt['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Status: Archived"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openPublishDialog(evt, existingResult: res)),
                      IconButton(icon: const Icon(Icons.publish, color: Colors.green), onPressed: () => _updateStatus(res.id, 'published')),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  // --- EVENT CARD WIDGET ---
  Widget _buildEventCard(DocumentSnapshot evt, {required String status, DocumentSnapshot? resultDoc}) {
    var d = evt.data() as Map<String, dynamic>;
    bool isGroup = d['type'] == 'group';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGroup ? Colors.purple.shade50 : Colors.blue.shade50,
          child: Icon(isGroup ? Icons.groups : Icons.person, color: isGroup ? Colors.purple : Colors.blue, size: 20),
        ),
        title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text("${d['category']} • ${d['stage'] ?? 'Off-Stage'}"),
        trailing: status == 'pending'
          ? ElevatedButton(
              onPressed: () => _openPublishDialog(evt),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text("Enter Result"),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if(status == 'published') IconButton(icon: const Icon(Icons.archive, color: Colors.orange), onPressed: () => _updateStatus(evt.id, 'archived'), tooltip: "Move to Archive"),
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openPublishDialog(evt, existingResult: resultDoc)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResult(evt.id)),
              ],
            ),
      ),
    );
  }

  // ==============================================================================
  // DIALOG: PUBLISH RESULT (MULTIPLE WINNERS)
  // ==============================================================================
  void _openPublishDialog(DocumentSnapshot evt, {DocumentSnapshot? existingResult}) {
    var eData = evt.data() as Map<String, dynamic>;
    bool isGroup = eData['type'] == 'group';
    
    // Initial Points
    var defPts = isGroup ? [10,8,5] : [5,3,1];
    var oldPts = existingResult != null ? existingResult['points'] : null;
    
    final p1Ctrl = TextEditingController(text: (oldPts?['first'] ?? defPts[0]).toString());
    final p2Ctrl = TextEditingController(text: (oldPts?['second'] ?? defPts[1]).toString());
    final p3Ctrl = TextEditingController(text: (oldPts?['third'] ?? defPts[2]).toString());

    // Selected Winners (Lists)
    List<String> firsts = [];
    List<String> seconds = [];
    List<String> thirds = [];

    if (existingResult != null) {
      var w = existingResult['winners'];
      firsts = List<String>.from(w['first'] is List ? w['first'] : [w['first']]);
      seconds = List<String>.from(w['second'] is List ? w['second'] : [w['second']]);
      thirds = List<String>.from(w['third'] is List ? w['third'] : [w['third']]);
      // Remove nulls if any
      firsts.removeWhere((e) => e == null);
      seconds.removeWhere((e) => e == null);
      thirds.removeWhere((e) => e == null);
    }

    // Prepare Candidates List
    List<Map<String, String>> candidates = [];
    if (isGroup) {
      candidates = _teams.map((t) => {'id': t, 'label': t}).toList();
    } else {
      String cat = eData['category'];
      String part = eData['participation'] ?? 'open';
      candidates = _students.where((s) {
        var d = s.data() as Map<String, dynamic>;
        if (d['categoryId'] != cat && cat != "General") return false;
        if (part == 'boys' && d['gender'] == 'Female') return false;
        if (part == 'girls' && d['gender'] == 'Male') return false;
        return true;
      }).map((s) => {'id': s.id, 'label': "${s['chestNo']} - ${s['name']} (${s['teamId']})"}).toList();
      candidates.sort((a,b) => a['label']!.compareTo(b['label']!));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          // Widget for Winner Selection Row
          Widget winnerRow(String title, List<String> currentList, Color color) {
            String? selectedCandidate;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 5),
                // Chips
                Wrap(
                  spacing: 5,
                  children: currentList.map((id) {
                    String label = candidates.firstWhere((c) => c['id'] == id, orElse: () => {'label': id})['label']!;
                    return Chip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setDialogState(() => currentList.remove(id)),
                      backgroundColor: color.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                // Add Dropdown
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCandidate,
                        isDense: true,
                        hint: const Text("Select to Add"),
                        items: candidates.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['label']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) {
                          if (v != null && !currentList.contains(v)) {
                            setDialogState(() => currentList.add(v));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            );
          }

          return AlertDialog(
            title: Text(existingResult == null ? "Publish Result" : "Edit Result"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Points
                    const Text("Points Distribution", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      Expanded(child: TextField(controller: p1Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "1st Pts"))), const SizedBox(width: 5),
                      Expanded(child: TextField(controller: p2Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "2nd Pts"))), const SizedBox(width: 5),
                      Expanded(child: TextField(controller: p3Ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "3rd Pts"))),
                    ]),
                    const Divider(height: 20),
                    // Winners
                    winnerRow("🥇 First Position", firsts, Colors.amber.shade800),
                    winnerRow("🥈 Second Position", seconds, Colors.blueGrey),
                    winnerRow("🥉 Third Position", thirds, Colors.brown),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              OutlinedButton(
                onPressed: () => _saveResult(evt, p1Ctrl, p2Ctrl, p3Ctrl, firsts, seconds, thirds, 'archived', ctx),
                child: const Text("Save to Archive"),
              ),
              ElevatedButton(
                onPressed: () => _saveResult(evt, p1Ctrl, p2Ctrl, p3Ctrl, firsts, seconds, thirds, 'published', ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("PUBLISH NOW"),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveResult(DocumentSnapshot evt, TextEditingController p1, TextEditingController p2, TextEditingController p3, List firsts, List seconds, List thirds, String status, BuildContext ctx) async {
    if (firsts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least one First Prize winner is required.")));
      return;
    }

    Map<String, dynamic> data = {
      'eventId': evt.id,
      'eventName': evt['name'],
      'category': evt['category'],
      'type': evt['type'],
      'status': status,
      'points': { 'first': int.parse(p1.text), 'second': int.parse(p2.text), 'third': int.parse(p3.text) },
      'winners': { 'first': firsts, 'second': seconds, 'third': thirds },
      'publishedAt': FieldValue.serverTimestamp(),
    };

    await db.collection('results').doc(evt.id).set(data);
    if(mounted) Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Result $status successfully!")));
  }

  Future<void> _updateStatus(String id, String status) async {
    await db.collection('results').doc(id).update({'status': status});
  }

  Future<void> _deleteResult(String id) async {
    if(await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Delete?"), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false) {
      await db.collection('results').doc(id).delete();
    }
  }

  // ==============================================================================
  // SIMULATION MODAL
  // ==============================================================================
  void _openSimulationModal() {
    // 1. Current Published Scores
    Map<String, int> current = _calculateScores();
    
    // 2. Projected (Published + Selected Archived)
    List<DocumentSnapshot> simResults = _results.where((r) => r['status'] == 'published' || _selectedForSimulation.contains(r.id)).toList();
    Map<String, int> projected = _calculateScores(customResults: simResults);

    // 3. Prepare Table Data
    List<Map<String, dynamic>> tableData = [];
    for (var t in _teams) {
      int cur = current[t] ?? 0;
      int proj = projected[t] ?? 0;
      tableData.add({ 'team': t, 'current': cur, 'projected': proj, 'diff': proj - cur });
    }
    tableData.sort((a,b) => b['projected'].compareTo(a['projected'])); // Sort by projected

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Standings Simulation"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Projected Impact of ${_selectedForSimulation.length} events:", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              // Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("Team", style: TextStyle(fontWeight: FontWeight.bold))),
                  Text("Current", style: TextStyle(fontSize: 12)),
                  SizedBox(width: 15),
                  Text("New Total", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                ],
              ),
              const Divider(),
              // Rows
              ...tableData.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(d['team'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text("${d['current']}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 15),
                    Row(
                      children: [
                        Text("${d['projected']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if(d['diff'] > 0)
                          Text(" (+${d['diff']})", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))
                      ],
                    )
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Close")),
          ElevatedButton(
            onPressed: () async {
              var batch = db.batch();
              for (var id in _selectedForSimulation) {
                batch.update(db.collection('results').doc(id), {'status': 'published'});
              }
              await batch.commit();
              setState(() => _selectedForSimulation.clear());
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All selected results Published!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("PUBLISH ALL"),
          )
        ],
      ),
    );
  }
}