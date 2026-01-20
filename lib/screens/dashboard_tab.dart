import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _countCard(db, 'students', 'Students', Colors.blue, Icons.people)),
            const SizedBox(width: 10),
            Expanded(child: _countCard(db, 'events', 'Events', Colors.orange, Icons.event)),
            const SizedBox(width: 10),
            Expanded(child: _countCard(db, 'results', 'Published', Colors.green, Icons.check_circle)),
          ]),
          const SizedBox(height: 20),
          const Text("Live House Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildLiveScoreboard(db),
        ],
      ),
    );
  }

  // ലൈവ് സ്കോർ കണക്കാക്കുന്ന ലോജിക് (Result Collection അടിസ്ഥാനമാക്കി)
  Widget _buildLiveScoreboard(FirebaseFirestore db) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('teams').snapshots(),
      builder: (context, teamSnap) {
        if (!teamSnap.hasData) return const LinearProgressIndicator();
        
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('results').where('status', isEqualTo: 'published').snapshots(),
          builder: (context, resSnap) {
            if (!resSnap.hasData) return const SizedBox();

            // സ്കോർ കാൽക്കുലേഷൻ
            Map<String, int> scores = {};
            // ടീമുകളെ 0 സ്കോറിൽ Initialize ചെയ്യുന്നു
            for (var t in teamSnap.data!.docs) { scores[t['name']] = 0; }

            for (var r in resSnap.data!.docs) {
              var data = r.data() as Map<String, dynamic>;
              var pts = data['points'] ?? {'first': 0, 'second': 0, 'third': 0};
              var winners = data['winners'] ?? {};
              
              // Helper to add points based on winner format (String or List)
              void addPts(dynamic winnerData, int p) {
                if (winnerData == null) return;
                List wList = (winnerData is List) ? winnerData : [winnerData];
                for (var w in wList) {
                   // ഗ്രൂപ്പ് ഇവന്റ് ആണെങ്കിൽ ടീം പേര് നേരിട്ടുണ്ടാകും, അല്ലെങ്കിൽ സ്റ്റുഡന്റ് ഐഡി വെച്ച് ടീം കണ്ടുപിടിക്കണം.
                   // ലളിതമാക്കാൻ: റിസൾട്ട് സേവ് ചെയ്യുമ്പോൾ നമ്മൾ ടീം നെയിം കൂടി സേവ് ചെയ്യുന്നുണ്ടെന്ന് ഉറപ്പാക്കണം.
                   // ഇവിടെ ലളിതമായ ടീം നെയിം മാച്ചിംഗ് ഉപയോഗിക്കുന്നു.
                   if (scores.containsKey(w)) {
                     scores[w] = (scores[w] ?? 0) + p;
                   }
                }
              }

              addPts(winners['first'], pts['first']);
              addPts(winners['second'], pts['second']);
              addPts(winners['third'], pts['third']);
            }

            // സോർട്ടിംഗ്
            var sortedTeams = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            return Column(
              children: sortedTeams.map((e) {
                var teamData = teamSnap.data!.docs.firstWhere((t) => t['name'] == e.key, orElse: () => teamSnap.data!.docs.first);
                Color tColor = Color(teamData['color']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: tColor, child: Text(e.key[0], style: const TextStyle(color: Colors.white))),
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text("${e.value} Pts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _countCard(FirebaseFirestore db, String coll, String label, Color color, IconData icon) {
    return StreamBuilder<AggregateQuerySnapshot>(
      stream: db.collection(coll).count().get().asStream(),
      builder: (c, s) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [Icon(icon, color: color), const SizedBox(height: 5), Text(s.hasData ? "${s.data!.count}" : "...", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 10, color: color))]),
      ),
    );
  }
}
