// File: lib/screens/registrations_tab.dart
// Version: 2.0
// Description: Event Cards Grid View, Click to Manage Registrations, Reject/Delete functionality.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationsTab extends StatefulWidget {
  const RegistrationsTab({super.key});
  @override
  State<RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<RegistrationsTab> {
  final db = FirebaseFirestore.instance;

  // State Management
  String? _selectedEventId; // If null, show Grid. If set, show Details.
  DocumentSnapshot? _selectedEventDoc;

  // Data
  List<DocumentSnapshot> _events = [];
  List<DocumentSnapshot> _registrations = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // 1. Load Categories
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });

    // 2. Load Events
    db.collection('events').orderBy('name').snapshots().listen((snap) {
      if(mounted) setState(() => _events = snap.docs);
    });

    // 3. Load All Registrations (To show counts on cards)
    db.collection('registrations').snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _registrations = snap.docs;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Logic: Show Grid if no event selected, else show Details
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _selectedEventId == null 
          ? _buildEventGrid() 
          : _buildDetailView(),
    );
  }

  // ==================== 1. EVENT GRID VIEW ====================

  Widget _buildEventGrid() {
    if (_events.isEmpty) return const Center(child: Text("No events found."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text("All Events", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = constraints.maxWidth > 800 ? 4 : 2; // Responsive Grid
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.4,
                ),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  return _buildEventCard(_events[index]);
                },
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String eid = doc.id;
    
    // Calculate Registration Count
    int count = _registrations.where((r) => r['eventId'] == eid).length;
    // For group events, this counts teams. For single, students.
    
    bool isGroup = data['type'] == 'group';
    Color catColor = Colors.blueAccent; 

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEventId = eid;
            _selectedEventDoc = doc;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text(data['category'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      Icon(isGroup ? Icons.groups : Icons.person, size: 16, color: Colors.grey.shade400)
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['name'], 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                  ),
                ],
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(isGroup ? "Teams" : "Students", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: count > 0 ? Colors.indigo : Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                     child: Text("$count", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: count > 0 ? Colors.white : Colors.black45)),
                   )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 2. DETAIL VIEW (MANAGE) ====================

  Widget _buildDetailView() {
    if (_selectedEventDoc == null) return const SizedBox();

    var eData = _selectedEventDoc!.data() as Map<String, dynamic>;
    // Filter registrations for this event only
    var eventRegs = _registrations.where((r) => r['eventId'] == _selectedEventId).toList();
    bool isGroup = eData['type'] == 'group';

    return Column(
      children: [
        // Header with Back Button
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => setState(() { _selectedEventId = null; _selectedEventDoc = null; }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("${eventRegs.length} Registrations • ${eData['category']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if(eventRegs.isNotEmpty)
                Chip(label: Text(isGroup ? "Group Event" : "Single Event"), backgroundColor: Colors.indigo.shade50, labelStyle: const TextStyle(color: Colors.indigo, fontSize: 11))
            ],
          ),
        ),
        const Divider(height: 1),
        
        // The List
        Expanded(
          child: eventRegs.isEmpty 
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.inbox, size: 48, color: Colors.grey), const SizedBox(height: 10), const Text("No registrations yet.", style: TextStyle(color: Colors.grey))])) 
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: eventRegs.length,
              itemBuilder: (context, index) {
                var r = eventRegs[index];
                var rData = r.data() as Map<String, dynamic>;
                String regId = r.id;
                
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade50,
                      child: Text("${index + 1}", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(isGroup ? (rData['teamId'] ?? "Unknown Team") : (rData['studentName'] ?? "Unknown"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: isGroup 
                       ? Text("Team ID: ${rData['teamId']}", style: const TextStyle(fontSize: 12))
                       : Text("Chest No: ${rData['chestNo'] ?? '-'} • ${rData['teamId'] ?? ''}", style: const TextStyle(fontSize: 12)),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _confirmReject(regId, rData['teamId'], eData['name'], isGroup),
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text("Reject"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                      ),
                    ),
                  ),
                );
              },
            ),
        ),
      ],
    );
  }

  // ==================== 3. REJECT LOGIC ====================

  Future<void> _confirmReject(String docId, String? teamId, String eventName, bool isGroup) async {
    final reasonCtrl = TextEditingController();
    
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Reject Registration?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This will remove the entry permanently and notify the team."),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Reason for rejection", border: OutlineInputBorder(), hintText: "e.g. Invalid document"),
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

      // Delete the registration
      batch.delete(db.collection('registrations').doc(docId));

      // Add Notification
      if (teamId != null) {
        var notifRef = db.collection('notifications').doc();
        batch.set(notifRef, {
          'teamId': teamId,
          'title': 'Registration Rejected',
          'message': 'Your entry for $eventName was rejected. Reason: $reason',
          'type': 'alert',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false
        });
      }

      await batch.commit();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Removed & Notification Sent")));
    }
  }
}
