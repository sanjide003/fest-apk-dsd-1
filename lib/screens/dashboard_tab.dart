// File: lib/screens/dashboard_tab.dart
// Version: 3.0
// Description: Restored Trophy/Medal Icons, Accurate Counters, and Material 3 Design.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final db = FirebaseFirestore.instance;
  final List<StreamSubscription> _streams = [];

  // Data
  List<DocumentSnapshot> _students = [];
  List<DocumentSnapshot> _events = [];
  List<DocumentSnapshot> _results = [];
  List<String> _teams = [];
  List<String> _categories = [];
  Map<String, dynamic> _teamDetails = {}; 

  // Calculated Stats
  Map<String, Map<String, dynamic>> _teamScores = {}; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  @override
  void dispose() {
    for (var s in _streams) s.cancel();
    super.dispose();
  }

  void _initListeners() {
    // 1. Settings
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _teamDetails = snap.data()?['teamDetails'] ?? {};
        });
        _calculateScores();
      }
    }));

    // 2. Students
    _streams.add(db.collection('students').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _students = snap.docs);
        _calculateScores();
      }
    }));

    // 3. Events
    _streams.add(db.collection('events').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _events = snap.docs);
        _calculateScores();
      }
    }));

    // 4. Results
    _streams.add(db.collection('results').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _results = snap.docs);
        _calculateScores();
      }
    }));
  }

  void _calculateScores() {
    Map<String, Map<String, dynamic>> scores = {};
    for (var t in _teams) {
      scores[t] = {'points': 0, '1st': 0, '2nd': 0, '3rd': 0};
    }

    for (var res in _results) {
      var data = res.data() as Map<String, dynamic>;
      // Default points: 1st=5, 2nd=3, 3rd=1
      var pts = data['points'] ?? {'first': 5, 'second': 3, 'third': 1};
      var winners = data['winners'] ?? {};

      void award(dynamic winnerId, int p, String rankKey) {
        if (winnerId == null) return;
        String teamName = "";
        
        // Check if winner is a Team Name (Group Event)
        if (_teams.contains(winnerId)) {
          teamName = winnerId;
        } else {
          // Check if winner is a Student ID
          try {
            var student = _students.firstWhere((s) => s.id == winnerId, orElse: () => _students.first); 
            // Note: orElse returns a dummy to prevent crash, but we check ID match below
            if(student.id == winnerId) {
               teamName = student['teamId'];
            }
          } catch (e) { return; }
        }

        if (teamName.isNotEmpty && scores.containsKey(teamName)) {
          scores[teamName]!['points'] += p;
          scores[teamName]![rankKey] += 1;
        }
      }

      award(winners['first'], pts['first'] is int ? pts['first'] : 5, '1st');
      award(winners['second'], pts['second'] is int ? pts['second'] : 3, '2nd');
      award(winners['third'], pts['third'] is int ? pts['third'] : 1, '3rd');
    }

    if (mounted) {
      setState(() {
        _teamScores = scores;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DASHBOARD HEADER
            Row(
              children: [
                const Icon(Icons.dashboard_rounded, color: Colors.indigo, size: 28),
                const SizedBox(width: 10),
                const Text("Dashboard Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 16),
            
            // 2. SUMMARY CARDS
            _buildSummaryGrid(),
            const SizedBox(height: 30),

            // 3. LIVE SCOREBOARD
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                const Text("Live Standings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 16),
            _buildScoreboard(),
            const SizedBox(height: 30),

            // 4. DETAILED BREAKDOWN
            const Row(children: [
               Icon(Icons.analytics_outlined, color: Colors.grey),
               SizedBox(width: 8),
               Text("Detailed Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            ]),
            const SizedBox(height: 12),
            _buildDetailedStats(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. SUMMARY GRID (With Big Icons) ---
  Widget _buildSummaryGrid() {
    int totalStudents = _students.length;
    int totalEvents = _events.length;
    int published = _results.length;
    int pending = totalEvents - published;
    if(pending < 0) pending = 0;

    return LayoutBuilder(builder: (context, constraints) {
      int cols = constraints.maxWidth > 800 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        childAspectRatio: 1.4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _summaryCard("Students", "$totalStudents", Icons.groups_rounded, Colors.blue),
          _summaryCard("Events", "$totalEvents", Icons.local_activity_rounded, Colors.purple),
          _summaryCard("Published", "$published", Icons.verified_rounded, Colors.green),
          _summaryCard("Pending", "$pending", Icons.pending_actions_rounded, Colors.orange),
        ],
      );
    });
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Stack(
        children: [
          Positioned(right: -15, top: -15, child: Icon(icon, size: 90, color: color.withOpacity(0.08))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SCOREBOARD (With Trophies & Medals) ---
  Widget _buildScoreboard() {
    var sortedTeams = _teamScores.entries.toList()..sort((a, b) => b.value['points'].compareTo(a.value['points']));
    
    if (sortedTeams.isEmpty) return const Text("No teams configured.");
    
    // Max score for progress bar
    int maxScore = sortedTeams.isNotEmpty ? sortedTeams.first.value['points'] : 1;
    if(maxScore == 0) maxScore = 1;

    return Column(
      children: sortedTeams.asMap().entries.map((entry) {
        int index = entry.key;
        String teamName = entry.value.key;
        var stats = entry.value.value;
        int colorVal = (_teamDetails[teamName]?['color']) ?? 0xFF2196F3;
        Color teamColor = Color(colorVal);
        double progress = stats['points'] / maxScore;
        bool isLeader = index == 0 && stats['points'] > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isLeader ? Border.all(color: Colors.amber.withOpacity(0.5), width: 2) : Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))]
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Rank Icon
                  if (isLeader)
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 32)
                  else
                    Container(
                      width: 28, height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                      child: Text("${index+1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    ),
                  
                  const SizedBox(width: 12),
                  // Team Name
                  Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  // Total Points
                  Text("${stats['points']} Pts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: teamColor)),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress, 
                  minHeight: 8, 
                  backgroundColor: Colors.grey.shade100, 
                  valueColor: AlwaysStoppedAnimation(teamColor)
                ),
              ),
              const SizedBox(height: 10),
              // Medals Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   _medalCount("🥇", stats['1st'], Colors.amber),
                   const SizedBox(width: 10),
                   _medalCount("🥈", stats['2nd'], Colors.grey),
                   const SizedBox(width: 10),
                   _medalCount("🥉", stats['3rd'], Colors.brown),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _medalCount(String emoji, int count, Color c) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 4),
      Text("$count", style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13))
    ]);
  }

  // --- 3. BREAKDOWN ---
  Widget _buildDetailedStats() {
    return Column(
      children: _teams.map((team) {
        int colorVal = (_teamDetails[team]?['color']) ?? 0xFF9E9E9E;
        int teamTotalStuds = _students.where((s) => s['teamId'] == team).length;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
          child: ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Color(colorVal).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.shield, color: Color(colorVal), size: 18),
            ),
            title: Text(team, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            trailing: Chip(
              avatar: const Icon(Icons.person, size: 14, color: Colors.grey),
              label: Text("$teamTotalStuds"), 
              backgroundColor: Colors.grey.shade50, 
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(right: 8),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._categories.map((cat) {
                 int count = _students.where((s) => s['teamId'] == team && s['categoryId'] == cat).length;
                 if (count == 0) return const SizedBox();
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 4),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(children: [
                         const Icon(Icons.label_important, size: 16, color: Colors.grey),
                         const SizedBox(width: 8),
                         Text(cat, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                       ]),
                       Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                     ],
                   ),
                 );
              })
            ],
          ),
        );
      }).toList(),
    );
  }
}