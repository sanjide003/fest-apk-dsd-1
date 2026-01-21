// File: lib/screens/dashboard_tab.dart
// Version: 2.0
// Description: Memory Leak Fixed, Modern UI with Score Bars and Animated Cards.

import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final db = FirebaseFirestore.instance;

  // Stream Subscriptions (To fix memory leaks)
  final List<StreamSubscription> _streams = [];

  // Data Containers
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
    // Cancel all streams when leaving the page
    for (var s in _streams) {
      s.cancel();
    }
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
      var pts = data['points'] ?? {'first': 5, 'second': 3, 'third': 1};
      var winners = data['winners'] ?? {};

      void award(dynamic winnerId, int p, String rankKey) {
        if (winnerId == null) return;
        String teamName = "";
        
        if (_teams.contains(winnerId)) {
          teamName = winnerId;
        } else {
          try {
            var student = _students.firstWhere((s) => s.id == winnerId);
            teamName = student['teamId'];
          } catch (e) { return; }
        }

        if (scores.containsKey(teamName)) {
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
            // 1. HEADER & SUMMARY
            const Text("Dashboard Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 16),
            _buildSummaryGrid(),
            const SizedBox(height: 30),

            // 2. LIVE SCOREBOARD (Modern UI)
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text("Live Standings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 16),
            _buildModernScoreboard(),
            const SizedBox(height: 30),

            // 3. DETAILED BREAKDOWN
            const Text("Team Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildDetailedStats(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. MODERN SUMMARY CARDS ---
  Widget _buildSummaryGrid() {
    int totalStudents = _students.length;
    int totalEvents = _events.length;
    int published = _results.length;
    int pending = totalEvents - published;

    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        childAspectRatio: 1.5,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _modernStatCard("Students", "$totalStudents", Icons.people_alt, Colors.blue),
          _modernStatCard("Events", "$totalEvents", Icons.event, Colors.purple),
          _modernStatCard("Published", "$published", Icons.check_circle_outline, Colors.green),
          _modernStatCard("Pending", "$pending", Icons.hourglass_empty, Colors.orange),
        ],
      );
    });
  }

  Widget _modernStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Stack(
        children: [
          Positioned(right: -10, top: -10, child: Icon(icon, size: 80, color: color.withOpacity(0.1))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. MODERN SCOREBOARD (Bar Chart Style) ---
  Widget _buildModernScoreboard() {
    var sortedTeams = _teamScores.entries.toList()..sort((a, b) => b.value['points'].compareTo(a.value['points']));
    
    if (sortedTeams.isEmpty) return const Text("No teams configured.");
    
    // Find max score for progress bar calculation
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 28, height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade400 : (index == 2 ? Colors.brown.shade300 : Colors.grey.shade100)),
                      shape: BoxShape.circle,
                    ),
                    child: Text("#${index+1}", style: TextStyle(fontWeight: FontWeight.bold, color: index < 3 ? Colors.white : Colors.black54, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text("${stats['points']} Pts", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              const SizedBox(height: 8),
              // Medals Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _medalPill("🥇", stats['1st'], Colors.amber.withOpacity(0.2), Colors.amber.shade800),
                  const SizedBox(width: 6),
                  _medalPill("🥈", stats['2nd'], Colors.grey.shade200, Colors.grey.shade700),
                  const SizedBox(width: 6),
                  _medalPill("🥉", stats['3rd'], Colors.brown.withOpacity(0.1), Colors.brown),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _medalPill(String icon, int count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text("$icon $count", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // --- 3. BREAKDOWN ---
  Widget _buildDetailedStats() {
    return Column(
      children: _teams.map((team) {
        int colorVal = (_teamDetails[team]?['color']) ?? 0xFF9E9E9E;
        int teamTotalStuds = _students.where((s) => s['teamId'] == team).length;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: ExpansionTile(
            shape: Border.all(color: Colors.transparent),
            leading: CircleAvatar(backgroundColor: Color(colorVal), radius: 14, child: Text(team[0], style: const TextStyle(color: Colors.white, fontSize: 12))),
            title: Text(team, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            trailing: Chip(label: Text("$teamTotalStuds Students"), backgroundColor: Colors.grey.shade100, labelStyle: const TextStyle(fontSize: 10)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(),
              ..._categories.map((cat) {
                 int count = _students.where((s) => s['teamId'] == team && s['categoryId'] == cat).length;
                 if (count == 0) return const SizedBox();
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 4),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(cat, style: const TextStyle(fontSize: 13, color: Colors.black87)),
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