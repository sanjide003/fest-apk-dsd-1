// File: lib/screens/registrations_tab.dart
// Version: 1.0
// Description: ഇവന്റ് രജിസ്ട്രേഷൻ മാനേജ്മെന്റ്. ടീമുകളെ നിരീക്ഷിക്കാനും, എൻട്രികൾ ക്യാൻസൽ ചെയ്യാനും, നോട്ടിഫിക്കേഷൻ അയക്കാനും സാധിക്കുന്നു.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationsTab extends StatefulWidget {
  const RegistrationsTab({super.key});
  @override
  State<RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<RegistrationsTab> {
  final db = FirebaseFirestore.instance;

  // Filters
  String? _selectedCategory;
  String _selectedStage = "All"; // All, On-Stage, Off-Stage
  String? _selectedEventId;
  String? _selectedEventName; // For notification

  // Data
  List<String> _categories = [];
  List<String> _teams = [];
  List<DocumentSnapshot> _events = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // Load Settings (Cats & Teams)
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
        });
      }
    });

    // Load Events
    db.collection('events').snapshots().listen((snap) {
      if (mounted) {
        setState(() => _events = snap.docs);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. FILTERS HEADER
          _buildFilterSection(),
          
          // 2. MAIN CONTENT
          Expanded(
            child: _selectedEventId == null
                ? _buildEmptyState()
                : _buildTeamGrid(),
          ),
        ],
      ),
    );
  }

  // --- 1. FILTER SECTION ---
  Widget _buildFilterSection() {
    // Filter Events based on Category & Stage
    List<DocumentSnapshot> filteredEvents = _events.where((e) {
      var data = e.data() as Map<String, dynamic>;
      bool catMatch = _selectedCategory == null || data['category'] == _selectedCategory;
      bool stageMatch = _selectedStage == "All" || 
                        (_selectedStage == "On-Stage" && data['stage'] == "On-Stage") ||
                        (_selectedStage == "Off-Stage" && data['stage'] != "On-Stage");
      return catMatch && stageMatch;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Category Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: "Category", isDense: true, border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() { _selectedCategory = v; _selectedEventId = null; }),
                ),
              ),
              const SizedBox(width: 10),
              // Stage Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: const InputDecoration(labelText: "Stage", isDense: true, border: OutlineInputBorder()),
                  items: const ["All", "On-Stage", "Off-Stage"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() { _selectedStage = v!; _selectedEventId = null; }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Event Selector
          DropdownButtonFormField<String>(
            value: _selectedEventId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: "Select Event", 
              prefixIcon: Icon(Icons.event_available),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.indigoAccent
            ), // Light tint? No, maybe keep simple
            hint: const Text("Choose an event to view registrations"),
            items: filteredEvents.map((e) {
              var d = e.data() as Map<String, dynamic>;
              return DropdownMenuItem(value: e.id, child: Text(d['name'], overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (v) {
              var evt = filteredEvents.firstWhere((e) => e.id == v);
              setState(() {
                _selectedEventId = v;
                _selectedEventName = (evt.data() as Map)['name'];
              });
            },
          ),
        ],
      ),
    );
  }

  // --- 2. EMPTY STATE ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("Select Category & Event to view status", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  // --- 3. TEAM GRID ---
  Widget _buildTeamGrid() {
    // Fetch Registrations for this Event
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('registrations').where('eventId', isEqualTo: _selectedEventId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        var regs = snap.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Adjust for larger screens if needed
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _teams.length,
          itemBuilder: (context, index) {
            String team = _teams[index];
            // Get registrations for this team
            var teamRegs = regs.where((r) => r['teamId'] == team).toList();
            bool isRegistered = teamRegs.isNotEmpty;

            return _buildTeamCard(team, teamRegs, isRegistered);
          },
        );
      },
    );
  }

  // --- TEAM CARD ---
  Widget _buildTeamCard(String team, List<DocumentSnapshot> teamRegs, bool isRegistered) {
    return Card(
      elevation: isRegistered ? 3 : 0,
      color: isRegistered ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isRegistered ? Colors.green.withOpacity(0.5) : Colors.transparent, width: 2)
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isRegistered ? Colors.green.shade50 : Colors.grey.shade200,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Text(team, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRegistered ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(
                    isRegistered ? "REGISTERED (${teamRegs.length})" : "NOT REGISTERED",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          
          // Body (Student List)
          Expanded(
            child: isRegistered
                ? ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: teamRegs.length,
                    separatorBuilder: (c,i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      var data = teamRegs[i].data() as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(data['studentName'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(data['chestNo']?.toString() ?? '', style: const TextStyle(fontSize: 10)),
                        trailing: InkWell(
                          onTap: () => _rejectEntry(teamRegs[i].id, team, data['studentName'], false),
                          child: const Icon(Icons.close, color: Colors.red, size: 16),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.person_off, color: Colors.grey),
                  ),
          ),

          // Footer (Reject Team)
          if (isRegistered)
            InkWell(
              onTap: () => _rejectEntry(null, team, "Entire Team", true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: const Text("REJECT TEAM", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
        ],
      ),
    );
  }

  // --- LOGIC: REJECT / REMOVE ---
  Future<void> _rejectEntry(String? docId, String team, String targetName, bool isTeamReject) async {
    final reasonCtrl = TextEditingController();
    
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isTeamReject ? "Reject Team?" : "Remove Student?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("You are about to remove '$targetName' from $_selectedEventName."),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Reason (Optional)", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Confirm Reject"),
          )
        ],
      )
    );

    if (confirm == true) {
      String reason = reasonCtrl.text.isEmpty ? "Administrative Decision" : reasonCtrl.text;
      var batch = db.batch();

      if (isTeamReject) {
        // Delete all docs for this team in this event
        var snap = await db.collection('registrations')
            .where('eventId', isEqualTo: _selectedEventId)
            .where('teamId', isEqualTo: team)
            .get();
        
        for (var doc in snap.docs) {
          batch.delete(doc.reference);
        }
      } else if (docId != null) {
        // Delete single doc
        batch.delete(db.collection('registrations').doc(docId));
      }

      // Add Notification
      var notifRef = db.collection('notifications').doc();
      batch.set(notifRef, {
        'teamId': team, // Target Team
        'title': 'Registration Rejected',
        'message': 'Your entry for $_selectedEventName ($targetName) was rejected. Reason: $reason',
        'type': 'alert',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false
      });

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Removed & Notification Sent")));
    }
  }
}