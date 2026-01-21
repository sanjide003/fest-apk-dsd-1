// File: lib/screens/dashboard_tab.dart
// Version: 1.0
// Description: Live Scoreboard, Summary Cards, and Detailed breakdown per Team/Category.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final db = FirebaseFirestore.instance;

  // Data Containers
  List<DocumentSnapshot> _students = [];
  List<DocumentSnapshot> _events = [];
  List<DocumentSnapshot> _results = [];
  List<String> _teams = [];
  List<String> _categories = [];
  Map<String, dynamic> _teamDetails = {}; // Colors etc.

  // Calculated Stats
  Map<String, Map<String, dynamic>> _teamScores = {}; // Team -> {pts, 1st, 2nd, 3rd}
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() {
    // 1. Settings (Teams & Categories)
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _teamDetails = snap.data()?['teamDetails'] ?? {};
        });
        _calculateScores();
      }
    });

    // 2. Students
    db.collection('students').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _students = snap.docs);
        _calculateScores();
      }
    });

    // 3. Events
    db.collection('events').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _events = snap.docs);
        _calculateScores();
      }
    });

    // 4. Results
    db.collection('results').snapshots().listen((snap) {
      if(mounted) {
        setState(() => _results = snap.docs);
        _calculateScores();
      }
    });
  }

  void _calculateScores() {
    // Reset Scores
    Map<String, Map<String, dynamic>> scores = {};
    for (var t in _teams) {
      scores[t] = {'points': 0, '1st': 0, '2nd': 0, '3rd': 0};
    }

    // Process Results
    for (var res in _results) {
      var data = res.data() as Map<String, dynamic>;
      var pts = data['points'] ?? {'first': 5, 'second': 3, 'third': 1}; // Fallback default
      var winners = data['winners'] ?? {};

      // Helper to award points
      void award(dynamic winnerId, int p, String rankKey) {
        if (winnerId == null) return;
        String teamName = "";
        
        // Find Team from Student ID or if it's a Team Name (Group Event)
        // Check if winnerId matches a known team name directly (Group event logic)
        if (_teams.contains(winnerId)) {
          teamName = winnerId;
        } else {
          // Look up student
          try {
            var student = _students.firstWhere((s) => s.id == winnerId);
            teamName = student['teamId'];
          } catch (e) {
            // Student deleted or not found
            return;
          }
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
            // 1. SUMMARY CARDS
            _buildSummaryGrid(),
            const SizedBox(height: 20),

            // 2. LIVE SCOREBOARD
            const Text("Live House Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            _buildScoreboard(),
            const SizedBox(height: 24),

            // 3. DETAILED BREAKDOWN
            const Text("Detailed Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            _buildDetailedStats(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. SUMMARY GRID ---
  Widget _buildSummaryGrid() {
    int totalStudents = _students.length;
    int totalEvents = _events.length;
    int published = _results.length;
    int pending = totalEvents - published;

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      childAspectRatio: 1.6,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard("Total Students", "$totalStudents", Icons.people, Colors.blue),
        _statCard("Total Events", "$totalEvents", Icons.emoji_events, Colors.purple),
        _statCard("Published", "$published", Icons.check_circle, Colors.green),
        _statCard("Pending", "$pending", Icons.pending_actions, Colors.orange),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- 2. LIVE SCOREBOARD ---
  Widget _buildScoreboard() {
    // Sort teams by points
    var sortedTeams = _teamScores.entries.toList()..sort((a, b) => b.value['points'].compareTo(a.value['points']));

    if (sortedTeams.isEmpty) return const Text("No teams configured.");

    return Column(
      children: sortedTeams.map((entry) {
        String teamName = entry.key;
        var stats = entry.value;
        int colorVal = (_teamDetails[teamName]?['color']) ?? 0xFF2196F3;
        
        bool isLeader = sortedTeams.indexOf(entry) == 0 && stats['points'] > 0;

        return Card(
          elevation: isLeader ? 4 : 1,
          shadowColor: isLeader ? Colors.amber.withOpacity(0.4) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isLeader ? const BorderSide(color: Colors.amber, width: 1.5) : BorderSide.none),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank/Icon
                isLeader 
                  ? const Icon(Icons.emoji_events, color: Colors.amber, size: 32)
                  : CircleAvatar(backgroundColor: Color(colorVal), radius: 6),
                const SizedBox(width: 16),
                
                // Name & Medal Counts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _medalCount("🥇", stats['1st']),
                          const SizedBox(width: 10),
                          _medalCount("🥈", stats['2nd']),
                          const SizedBox(width: 10),
                          _medalCount("🥉", stats['3rd']),
                        ],
                      )
                    ],
                  ),
                ),
                
                // Total Points
                Text("${stats['points']} Pts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(colorVal)))
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _medalCount(String icon, int count) {
    return Text("$icon $count", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54));
  }

  // --- 3. DETAILED STATS (NESTED) ---
  Widget _buildDetailedStats() {
    return Column(
      children: _teams.map((team) {
        int colorVal = (_teamDetails[team]?['color']) ?? 0xFF9E9E9E;
        // Count total students in this team
        int teamTotalStuds = _students.where((s) => s['teamId'] == team).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(backgroundColor: Color(colorVal), child: Text(team[0], style: const TextStyle(color: Colors.white))),
            title: Text(team, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$teamTotalStuds Students registered"),
            childrenPadding: const EdgeInsets.all(16),
            children: [
              // Table Header
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text("Students", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const Divider(),
              
              // Categories breakdown
              ..._categories.map((cat) {
                // Count students in this Team + Category
                int count = _students.where((s) => s['teamId'] == team && s['categoryId'] == cat).length;
                if (count == 0) return const SizedBox();

                // Check gender split (Optional display)
                int boys = _students.where((s) => s['teamId'] == team && s['categoryId'] == cat && (s.data() as Map).containsKey('gender') && s['gender'] == 'Male').length;
                int girls = _students.where((s) => s['teamId'] == team && s['categoryId'] == cat && (s.data() as Map).containsKey('gender') && s['gender'] == 'Female').length;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat, style: const TextStyle(fontSize: 13)),
                      Row(
                        children: [
                          if(boys > 0) Text("M:$boys ", style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                          if(girls > 0) Text("F:$girls ", style: TextStyle(fontSize: 11, color: Colors.pink.shade700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}