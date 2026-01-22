// File: lib/screens/registrations_tab.dart
// Version: 5.0
// Description: Mobile Grid set to 2 columns, Filter UI fixed (Labels visible), Full Details in Cards.

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
  String? _selectedEventId; 
  DocumentSnapshot? _selectedEventDoc;

  // Filters
  String _filterCategory = "All";
  String _filterStage = "All";
  String _filterType = "All"; 

  // Data
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<DocumentSnapshot> _registrations = [];
  List<String> _categories = [];
  List<String> _teams = []; 
  Map<String, dynamic> _teamDetails = {}; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // 1. Load Settings (Categories & Teams)
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _teamDetails = snap.data()?['teamDetails'] ?? {};
        });
      }
    });

    // 2. Load Events
    db.collection('events').orderBy('name').snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _allEvents = snap.docs;
          _applyFilters();
        });
      }
    });

    // 3. Load Registrations
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

        // Type Filter (Case insensitive check)
        String type = (data['type'] ?? '').toString().toLowerCase();
        if (_filterType != "All" && type != _filterType.toLowerCase()) return false;

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterCategory = "All";
      _filterStage = "All";
      _filterType = "All";
      _applyFilters();
    });
  }

  Color _getTeamColor(String teamName) {
    if (_teamDetails.containsKey(teamName)) {
      int val = _teamDetails[teamName]['color'] ?? 0xFF9E9E9E;
      return Color(val);
    }
    return Colors.grey;
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
    bool hasFilter = _filterCategory!="All" || _filterStage!="All" || _filterType!="All";

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.filter_list, color: Colors.indigo),
            const SizedBox(width: 12),
            // Expanded Scrollable Row for filters
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterDropdown(
                      label: "Category", 
                      value: _filterCategory, 
                      items: ["All", ..._categories], 
                      onChanged: (v) { _filterCategory = v!; _applyFilters(); }
                    ),
                    const SizedBox(width: 10),
                    _filterDropdown(
                      label: "Type", 
                      value: _filterType, 
                      items: ["All", "Single", "Group"], 
                      onChanged: (v) { _filterType = v!; _applyFilters(); }
                    ),
                    const SizedBox(width: 10),
                    _filterDropdown(
                      label: "Stage", 
                      value: _filterStage, 
                      items: ["All", "On-Stage", "Off-Stage"], 
                      onChanged: (v) { _filterStage = v!; _applyFilters(); }
                    ),
                  ],
                ),
              ),
            ),
            
            // Clear Button
            if (hasFilter)
              IconButton(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off, color: Colors.red),
                tooltip: "Clear Filters",
              )
          ],
        ),
      ),
    );
  }

  // Increased Width & Layout fix for visibility
  Widget _filterDropdown({required String label, required String value, required List<String> items, required Function(String?) onChanged}) {
    return SizedBox(
      width: 160, // Increased width to show text completely
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : "All",
        isExpanded: true, // Prevents overflow
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // More padding
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          filled: true, fillColor: Colors.grey.shade50,
          isDense: true,
        ),
        items: items.map((c) => DropdownMenuItem(
          value: c, 
          child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ==================== 2. EVENT GRID VIEW (DETAILED) ====================

  Widget _buildEventGrid() {
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events match filters."));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Logic: 2 columns on mobile (< 800px), 4 columns on Desktop (> 800px)
          int cols = constraints.maxWidth > 800 ? 4 : 2; 
          // Aspect Ratio logic: Taller cards on mobile (0.75) to fit details, Wider on desktop (1.1)
          double ratio = constraints.maxWidth > 800 ? 1.1 : 0.75; 

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: ratio, 
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
    bool isGroup = data['type'] == 'group';
    
    // Get all registrations for this event
    var eventRegs = _registrations.where((r) => r['eventId'] == eid).toList();
    int totalRegs = eventRegs.length;
    
    // Limits
    int limit = isGroup 
        ? (data['limits']?['maxTeams'] ?? 0)
        : (data['limits']?['maxParticipants'] ?? 0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedEventId = eid;
            _selectedEventDoc = doc;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10), // Compact padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER: Name & Count
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      data['name'], 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14) // Slightly smaller font for mobile fit
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: totalRegs > 0 ? Colors.indigo.shade50 : Colors.grey.shade100, shape: BoxShape.circle),
                    child: Text("$totalRegs", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: totalRegs > 0 ? Colors.indigo : Colors.grey)),
                  )
                ],
              ),
              
              const SizedBox(height: 8),

              // 2. BADGES ROW
              Wrap(
                spacing: 4, runSpacing: 4,
                children: [
                  _miniBadge(data['category'], Colors.blue.shade50, Colors.blue.shade700),
                  _miniBadge(isGroup ? "Group" : "Single", Colors.purple.shade50, Colors.purple.shade700),
                  _miniBadge(data['stage'] ?? 'Off-Stage', Colors.orange.shade50, Colors.orange.shade800),
                ],
              ),
              
              const Divider(height: 12),

              // 3. TEAM BREAKDOWN (Who participated?)
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4, runSpacing: 4,
                    children: _teams.map((team) {
                      int count = eventRegs.where((r) => r['teamId'] == team).length;
                      if (count == 0) return const SizedBox();
                      Color tc = _getTeamColor(team);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: tc.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                          color: tc.withOpacity(0.05)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: tc),
                            const SizedBox(width: 3),
                            Text("$team: $count", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tc)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. FOOTER: Limit Info
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Limit: $limit ${isGroup ? 'Teams' : 'Entries'}", 
                      style: const TextStyle(fontSize: 10, color: Colors.grey)
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
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
                String team = rData['teamId'] ?? 'Unknown';
                Color tc = _getTeamColor(team);
                
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: tc.withOpacity(0.1),
                      child: Text("${index + 1}", style: TextStyle(color: tc, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(isGroup ? team : (rData['studentName'] ?? "Unknown"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: isGroup 
                       ? Text("Team: $team", style: const TextStyle(fontSize: 12))
                       : Text("Chest No: ${rData['chestNo'] ?? '-'} • Team: $team", style: const TextStyle(fontSize: 12)),
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

      batch.delete(db.collection('registrations').doc(docId));

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
