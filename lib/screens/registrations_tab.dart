// File: lib/screens/registrations_tab.dart
// Version: 11.0
// Description: Global Search Integration (Expanding Icon Style), Mobile Grid (2 Cols), Detailed Cards, Pop-up Details.

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
    // 1. Initialize search with current value from Global Search
    _currentSearch = globalSearchQuery.value.toLowerCase();
    
    _initData();
    
    // 2. Listen to global search changes
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
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if(mounted) {
        setState(() {
          _currentSearch = globalSearchQuery.value.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  void _initData() {
    // 1. Load Settings
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
          _applyFilters();
        });
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredEvents = _allEvents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        String eid = doc.id;
        
        // 1. Text Search (Name, Team, or Student) using Global Search Query
        if (_currentSearch.isNotEmpty) {
          bool nameMatch = data['name'].toString().toLowerCase().contains(_currentSearch);
          bool contentMatch = false;

          if (!nameMatch) {
             var eventRegs = _registrations.where((r) => r['eventId'] == eid);
             for (var r in eventRegs) {
               var rData = r.data() as Map<String, dynamic>;
               String tId = (rData['teamId'] ?? '').toString().toLowerCase();
               String sName = (rData['studentName'] ?? '').toString().toLowerCase();
               if (tId.contains(_currentSearch) || sName.contains(_currentSearch)) {
                 contentMatch = true;
                 break;
               }
             }
          }
          
          if (!nameMatch && !contentMatch) return false;
        }

        if (_filterCategory != "All" && data['category'] != _filterCategory) return false;
        if (_filterStage != "All" && data['stage'] != _filterStage) return false;

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
      // We don't clear global search from here to maintain consistency
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

  // ==================== 1. FILTER HEADER (Compact) ====================

  Widget _buildFilterHeader() {
    bool hasFilter = _filterCategory!="All" || _filterStage!="All" || _filterType!="All";

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
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
      height: 40, 
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          filled: true, fillColor: Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : "All",
            isDense: true, isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
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
          int cols = constraints.maxWidth > 800 ? 4 : 2; 
          double ratio = constraints.maxWidth > 800 ? 0.6 : 0.55; 

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
              return _buildDetailedEventCard(_filteredEvents[index]);
            },
          );
        }
      ),
    );
  }

  Widget _buildDetailedEventCard(DocumentSnapshot doc) {
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showEventDetailsDialog(doc),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP ROW: Name & Limit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['name'], 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.1)
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: Text("Limit: $limit", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                // 2. MIDDLE ROW: Badges
                Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    _miniBadge(data['category'], Colors.blue.shade50, Colors.blue.shade700),
                    _miniBadge(isGroup ? "Group" : "Single", Colors.purple.shade50, Colors.purple.shade700),
                    _miniBadge(data['stage'] ?? 'Off-Stage', Colors.orange.shade50, Colors.orange.shade800),
                    if((data['participation'] ?? 'open') != 'open')
                       _miniBadge(data['participation'].toString().toUpperCase(), Colors.pink.shade50, Colors.pink.shade700),
                  ],
                ),
                
                const Divider(height: 16),

                // 3. BOTTOM ROW: Team Breakdown
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _teams.map((team) {
                        int count = eventRegs.where((r) => r['teamId'] == team).length;
                        Color tc = _getTeamColor(team);
                        bool participated = count > 0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Team Name with Color Dot
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: tc),
                                  const SizedBox(width: 6),
                                  Text(team, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              // Status
                              participated 
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: tc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                    child: Text("$count Entries", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc))
                                  )
                                : const Text("പങ്കെടുത്തിട്ടില്ല", style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ==================== 3. POP-UP DETAIL DIALOG ====================

  void _showEventDetailsDialog(DocumentSnapshot eventDoc) {
    var eData = eventDoc.data() as Map<String, dynamic>;
    String eid = eventDoc.id;
    bool isGroup = eData['type'] == 'group';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            var eventRegs = _registrations.where((r) {
              var rData = r.data() as Map<String, dynamic>;
              if (r['eventId'] != eid) return false;
              if (_currentSearch.isNotEmpty) {
                String t = (rData['teamId'] ?? '').toString().toLowerCase();
                String s = (rData['studentName'] ?? '').toString().toLowerCase();
                String c = (rData['chestNo'] ?? '').toString().toLowerCase();
                if (!t.contains(_currentSearch) && !s.contains(_currentSearch) && !c.contains(_currentSearch)) {
                  return false;
                }
              }
              return true;
            }).toList();

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("${eventRegs.length} Matches Found", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: eventRegs.isEmpty
                    ? const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox, size: 40, color: Colors.grey), Text("No matching registrations")])
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
                                  Navigator.pop(context); 
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
            );
          }
        );
      },
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
