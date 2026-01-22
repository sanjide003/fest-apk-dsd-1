// File: lib/screens/registrations_tab.dart
// Version: 3.0
// Description: Filters (Category/Stage) restored with 'All' option. Event Cards Grid. Reject Individual/Team with Reason.

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

  // Filters
  String _filterCategory = "All";
  String _filterStage = "All";

  // Data
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
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
      if(mounted) {
        setState(() {
          _allEvents = snap.docs;
          _applyFilters(); // Initial Filter
        });
      }
    });

    // 3. Load All Registrations (For Counts)
    db.collection('registrations').snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _registrations = snap.docs;
          _isLoading = false;
        });
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredEvents = _allEvents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Category Filter
        if (_filterCategory != "All" && data['category'] != _filterCategory) return false;
        
        // Stage Filter
        if (_filterStage != "All" && data['stage'] != _filterStage) return false;

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // SHOW FILTERS ONLY WHEN IN GRID VIEW
          if (_selectedEventId == null) 
            _buildFilterHeader(),
            
          // BODY (GRID OR DETAILS)
          Expanded(
            child: _selectedEventId == null 
                ? _buildEventGrid() 
                : _buildDetailView(),
          ),
        ],
      ),
    );
  }

  // ==================== 1. FILTER HEADER ====================

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Colors.indigo),
          const SizedBox(width: 12),
          // Category Dropdown
          Expanded(
            child: SizedBox(
              height: 40,
              child: DropdownButtonFormField<String>(
                value: _filterCategory,
                decoration: InputDecoration(
                  labelText: "Category",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.grey.shade50
                ),
                items: [
                  const DropdownMenuItem(value: "All", child: Text("All Categories")),
                  ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                ],
                onChanged: (v) {
                  if(v != null) {
                    _filterCategory = v;
                    _applyFilters();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Stage Dropdown
          Expanded(
            child: SizedBox(
              height: 40,
              child: DropdownButtonFormField<String>(
                value: _filterStage,
                decoration: InputDecoration(
                  labelText: "Stage",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.grey.shade50
                ),
                items: const [
                  DropdownMenuItem(value: "All", child: Text("All Stages")),
                  DropdownMenuItem(value: "On-Stage", child: Text("On-Stage")),
                  DropdownMenuItem(value: "Off-Stage", child: Text("Off-Stage")),
                ],
                onChanged: (v) {
                  if(v != null) {
                    _filterStage = v;
                    _applyFilters();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. EVENT GRID VIEW ====================

  Widget _buildEventGrid() {
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events match filters."));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int cols = constraints.maxWidth > 800 ? 4 : 2; 
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: _filteredEvents.length,
            itemBuilder: (context, index) {
              return _buildEventCard(_filteredEvents[index]);
            },
          );
        }
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String eid = doc.id;
    
    // Calculate Count
    int count = _registrations.where((r) => r['eventId'] == eid).length;
    bool isGroup = data['type'] == 'group';

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
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text(data['category'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
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
                   Text(data['stage'] ?? 'Off-Stage', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(color: count > 0 ? Colors.indigo : Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                     child: Text("$count Reg", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: count > 0 ? Colors.white : Colors.black45)),
                   )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 3. DETAIL VIEW (MANAGE) ====================

  Widget _buildDetailView() {
    if (_selectedEventDoc == null) return const SizedBox();

    var eData = _selectedEventDoc!.data() as Map<String, dynamic>;
    var eventRegs = _registrations.where((r) => r['eventId'] == _selectedEventId).toList();
    bool isGroup = eData['type'] == 'group';

    return Column(
      children: [
        // Back Header
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
                    Text("${eventRegs.length} Registrations", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // List of Registrations
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
                       ? Text("Team: ${rData['teamId']}", style: const TextStyle(fontSize: 12))
                       : Text("Chest No: ${rData['chestNo'] ?? '-'} • Team: ${rData['teamId'] ?? ''}", style: const TextStyle(fontSize: 12)),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _confirmReject(regId, rData['teamId'], eData['name'], isGroup),
                      icon: const Icon(Icons.block, size: 16),
                      label: Text(isGroup ? "Reject Team" : "Reject"),
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

  // ==================== 4. REJECT LOGIC ====================

  Future<void> _confirmReject(String docId, String? teamId, String eventName, bool isGroup) async {
    final reasonCtrl = TextEditingController();
    
    // Determine title based on type
    String title = isGroup ? "Reject Team Registration?" : "Reject Student Registration?";
    String warning = isGroup 
        ? "This will remove the entire team '$teamId' from '$eventName'." 
        : "This will remove this student from '$eventName'.";

    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning),
            const SizedBox(height: 16),
            const Text("Reason for Rejection:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: "e.g. Document mismatch / Late entry",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white
              ),
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

      // Delete Logic
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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Rejected & Notification Sent")));
    }
  }
}
