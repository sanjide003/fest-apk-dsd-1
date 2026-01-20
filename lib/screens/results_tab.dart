import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResultsPublishView extends StatefulWidget {
  const ResultsPublishView({super.key});
  @override
  State<ResultsPublishView> createState() => _ResultsPublishViewState();
}

class _ResultsPublishViewState extends State<ResultsPublishView> {
  final db = FirebaseFirestore.instance;
  String? _selectedEvent;
  String? _first, _second, _third;
  
  // Points (Default loaded, but editable)
  final _p1 = TextEditingController(text: "5");
  final _p2 = TextEditingController(text: "3");
  final _p3 = TextEditingController(text: "1");

  // Load event details when selected
  void _onEventSelect(DocumentSnapshot doc) {
    setState(() {
      _selectedEvent = doc.id;
      // Set default points based on type
      if (doc['type'] == 'group') {
        _p1.text = "10"; _p2.text = "7"; _p3.text = "5";
      } else {
        _p1.text = "5"; _p2.text = "3"; _p3.text = "1";
      }
    });
  }

  Future<void> _publish(bool archive) async {
    if (_selectedEvent == null) return;
    
    // 1. Get Team Names from Student/Reg IDs (Simplified logic)
    // In real app, you fetch student doc to get team name.
    // Here we assume the Dropdown value IS the Team Name for simplicity in Groups,
    // or we fetch it.
    
    await db.collection('results').doc(_selectedEvent).set({
      'eventId': _selectedEvent,
      'status': archive ? 'archived' : 'published', // Archive or Publish
      'points': {'first': int.parse(_p1.text), 'second': int.parse(_p2.text), 'third': int.parse(_p3.text)},
      'winners': {'first': _first, 'second': _second, 'third': _third},
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!archive) {
      // Add Notification
      await db.collection('notifications').add({
        'title': 'Result Announced',
        'message': 'Results for event published.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(archive ? "Saved to Archive" : "PUBLISHED LIVE!")));
    setState(() { _selectedEvent = null; _first = null; _second = null; _third = null; });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(tabs: [Tab(text: "New Entry"), Tab(text: "Published History")]),
        body: TabBarView(
          children: [
            _buildEntryForm(),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Event to Publish", style: TextStyle(fontWeight: FontWeight.bold)),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('events').snapshots(),
            builder: (c, s) {
              if(!s.hasData) return const SizedBox();
              // Filter out already published ones if needed
              return DropdownButtonFormField(
                value: _selectedEvent,
                items: s.data!.docs.map((e) => DropdownMenuItem(value: e.id, onTap: ()=>_onEventSelect(e), child: Text(e['name']))).toList(),
                onChanged: (v) {}, // Handled in onTap
                hint: const Text("Choose Event"),
              );
            }
          ),
          
          if (_selectedEvent != null) ...[
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextField(controller: _p1, decoration: const InputDecoration(labelText: "1st Pts"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _p2, decoration: const InputDecoration(labelText: "2nd Pts"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _p3, decoration: const InputDecoration(labelText: "3rd Pts"), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 20),
            
            // Participants Dropdown (Winners)
            // Fetch Registrations for this event
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('registrations').where('eventId', isEqualTo: _selectedEvent).snapshots(),
              builder: (c, rSnap) {
                if (!rSnap.hasData) return const Text("Loading Participants...");
                var items = rSnap.data!.docs.map((r) => DropdownMenuItem(value: r['teamId'], child: Text("${r['studentName']} (${r['teamId']})"))).toList();
                
                return Column(children: [
                   DropdownButtonFormField(value: _first, items: items, onChanged: (v)=>setState(()=>_first=v as String?), decoration: const InputDecoration(labelText: "First Prize", prefixIcon: Icon(Icons.emoji_events, color: Colors.amber))),
                   const SizedBox(height: 10),
                   DropdownButtonFormField(value: _second, items: items, onChanged: (v)=>setState(()=>_second=v as String?), decoration: const InputDecoration(labelText: "Second Prize", prefixIcon: Icon(Icons.emoji_events, color: Colors.grey))),
                   const SizedBox(height: 10),
                   DropdownButtonFormField(value: _third, items: items, onChanged: (v)=>setState(()=>_third=v as String?), decoration: const InputDecoration(labelText: "Third Prize", prefixIcon: Icon(Icons.emoji_events, color: Colors.brown))),
                ]);
              }
            ),
            
            const SizedBox(height: 30),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _publish(true), child: const Text("Save to Archive"))),
              const SizedBox(width: 20),
              Expanded(child: ElevatedButton(onPressed: () => _publish(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("PUBLISH NOW"))),
            ])
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('results').orderBy('timestamp', descending: true).snapshots(),
      builder: (c, s) {
        if(!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: s.data!.docs.length,
          itemBuilder: (c, i) {
            var d = s.data!.docs[i];
            bool isArchived = d['status'] == 'archived';
            return ListTile(
              title: Text("Event ID: ${d['eventId']}"), // In real app, fetch Event Name
              subtitle: Text(isArchived ? "Archived" : "Published"),
              trailing: isArchived ? IconButton(icon: const Icon(Icons.send, color: Colors.green), onPressed: (){ /* Publish Logic */ }) : const Icon(Icons.check, color: Colors.green),
            );
          },
        );
      },
    );
  }
}
