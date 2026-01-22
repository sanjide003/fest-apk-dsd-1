// File: lib/screens/registrations_tab.dart
// Version: 7.0
// Description: Mobile Grid (2 Cols), Global Search Integration, Pop-up Details, Explicit "Not Participated" Status.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../layout/responsive_layout.dart'; // Import for globalSearchQuery

class RegistrationsTab extends StatefulWidget {
  const RegistrationsTab({super.key});
  @override
  State<RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<RegistrationsTab> {
  final db = FirebaseFirestore.instance;

  // Filters
  String _filterCategory = "All";
  String _filterStage = "All";
  String _filterType = "All"; 
  String _currentSearch = "";

  // Data
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<DocumentSnapshot> _registrations = [];
  List<String> _categories = [];
  List<String> _teams = []; 
  Map<String, dynamic> _teamDetails = {}; 
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initData();
    // Listen to global search
    globalSearchQuery.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    globalSearchQuery.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if(mounted) {
        setState(() {
          _currentSearch = globalSearchQuery.value.toLowerCase();
          _applyFilters();
        });
      }
    });
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
    }));

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
        
        // Text Search
        if (_currentSearch.isNotEmpty) {
          if (!data['name'].toString().toLowerCase().contains(_currentSearch)) return false;
        }

        // Category Filter
        if (_filterCategory != "All" && data['category'] != _filterCategory) return false;
        
        // Stage Filter
        if (_filterStage != "All" && data['stage'] != _filterStage) return false;

        // Type Filter
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
      _currentSearch = "";
      // Reset global search text if possible or just ignore local logic
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
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(child: _buildEventGrid()),
        ],
      ),
    );
  }

  // ==================== 1. FILTER HEADER ====================

  Widget _buildFilterHeader() {
    bool hasFilter = _filterCategory!="All" || _filterStage!="All" || _filterType!="All";

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: Colors.indigo, size: 24),
          const SizedBox(width: 12),
          // Expanded Scrollable Row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterDropdown(label: "Category", value: _filterCategory, items: ["All", ..._categories], onChanged: (v) { _filterCategory = v!; _applyFilters(); }),
                  const SizedBox(width: 8),
                  _filterDropdown(label: "Type", value: _filterType, items: ["All", "Single", "Group"], onChanged: (v) { _filterType = v!; _applyFilters(); }),
                  const SizedBox(width: 8),
                  _filterDropdown(label: "Stage", value: _filterStage, items: ["All", "On-Stage", "Off-Stage"], onChanged: (v) { _filterStage = v!; _applyFilters(); }),
                ],
              ),
            ),
          ),
          
          if (hasFilter)
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.highlight_off, color: Colors.red),
              tooltip: "Clear Filters",
            )
        ],
      ),
    );
  }

  Widget _filterDropdown({required String label, required String value, required List<String> items, required Function(String?) onChanged}) {
    return SizedBox(
      width: 130, 
      height: 45, 
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          floatingLabelBehavior: FloatingLabelBehavior.always, 
          filled: true, fillColor: Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : "All",
            isDense: true, isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
            items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // ==================== 2. EVENT GRID VIEW ====================

  Widget _buildEventGrid() {
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events found."));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile: 2 Cols, Desktop: 4 Cols
          int cols = constraints.maxWidth > 800 ? 4 : 2; 
          // Ratio adjustment for content
          double ratio = constraints.maxWidth > 800 ? 0.8 : 0.55; 

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
    
    var eventRegs = _registrations.where((r) => r['eventId'] == eid).toList();
    int totalRegs = eventRegs.length;
    
    int limit = isGroup 
        ? (data['limits']?['maxTeams'] ?? 0)
        : (data['limits']?['maxParticipants'] ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEventDetailsDialog(doc), // Pop-up on click
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(data['name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(8)),
                      child: Text("$totalRegs", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B4DB7), fontSize: 12)),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                // 2. BADGES
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    _htmlTag(data['category'], Colors.blue.shade50, Colors.blue.shade700),
                    _htmlTag(isGroup ? "Group" : "Single", Colors.purple.shade50, Colors.purple.shade700),
                  ],
                ),
                
                const Divider(height: 16),

                // 3. TEAM STATUS (Explicit)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _teams.map((team) {
                        int count = eventRegs.where((r) => r['teamId'] == team).length;
                        Color tc = _getTeamColor(team);
                        bool participated = count > 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(participated ? Icons.check_circle : Icons.circle_outlined, size: 10, color: participated ? tc : Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  team, 
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: participated ? Colors.black87 : Colors.grey)
                                ),
                              ),
                              Text(
                                participated ? "$count Entries" : "Not Participated",
                                style: TextStyle(fontSize: 10, color: participated ? tc : Colors.grey, fontWeight: participated ? FontWeight.bold : FontWeight.normal)
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                // 4. LIMIT
                Text("Limit: $limit ${isGroup ? 'Teams' : 'Entries'}", style: const TextStyle(fontSize: 10, color: Colors.grey))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _htmlTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ==================== 3. POP-UP DETAIL DIALOG ====================

  void _showEventDetailsDialog(DocumentSnapshot eventDoc) {
    var eData = eventDoc.data() as Map<String, dynamic>;
    String eid = eventDoc.id;
    var eventRegs = _registrations.where((r) => r['eventId'] == eid).toList();
    bool isGroup = eData['type'] == 'group';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${eventRegs.length} Total Registrations", style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: eventRegs.isEmpty
              ? const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox, size: 40, color: Colors.grey), Text("No registrations yet")])
              : ListView.builder(
                  shrinkWrap: true,
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
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        leading: CircleAvatar(
                          backgroundColor: tc.withOpacity(0.1),
                          radius: 14,
                          child: Text("${index + 1}", style: TextStyle(color: tc, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        title: Text(isGroup ? team : (rData['studentName'] ?? "Unknown"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(isGroup ? "Team Event" : "Chest: ${rData['chestNo']} • $team", style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.block, size: 18, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context); // Close dialog first to avoid context issues
                            _confirmReject(regId, rData['teamId'], eData['name'], isGroup);
                          },
                          tooltip: "Reject",
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  // ==================== 4. REJECT LOGIC ====================

  Future<void> _confirmReject(String docId, String? teamId, String eventName, bool isGroup) async {
    final reasonCtrl = TextEditingController();
    
    String title = isGroup ? "Reject Team?" : "Reject Student?";
    String warning = isGroup ? "Remove team '$teamId' from '$eventName'?" : "Remove student from '$eventName'?";

    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Reason", border: OutlineInputBorder()),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Reject"),
          )
        ],
      )
    );

    if (confirm == true) {
      String reason = reasonCtrl.text.isEmpty ? "Admin Decision" : reasonCtrl.text;
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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Rejected")));
    }
  }
}
