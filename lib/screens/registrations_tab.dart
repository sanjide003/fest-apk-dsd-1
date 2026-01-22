// File: lib/screens/registrations_tab.dart
// Version: 6.0
// Description: UI matched to user's HTML replica. Mobile Grid: 2 Cols. Team Breakdown included. Filters Fixed.

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
      backgroundColor: const Color(0xFFF7F8FA), // Matched HTML background
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

  // ==================== 1. FILTER HEADER (FIXED UI) ====================

  Widget _buildFilterHeader() {
    bool hasFilter = _filterCategory!="All" || _filterStage!="All" || _filterType!="All";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: Colors.indigo, size: 28),
          const SizedBox(width: 16),
          // Expanded Scrollable Row
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
                  const SizedBox(width: 12),
                  _filterDropdown(
                    label: "Type", 
                    value: _filterType, 
                    items: ["All", "Single", "Group"], 
                    onChanged: (v) { _filterType = v!; _applyFilters(); }
                  ),
                  const SizedBox(width: 12),
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
      width: 140, 
      height: 48, // Fixed height to prevent label cutting
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          floatingLabelBehavior: FloatingLabelBehavior.always, // Keeps label on border
          filled: true,
          fillColor: Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : "All",
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
            items: items.map((c) => DropdownMenuItem(
              value: c, 
              child: Text(c, overflow: TextOverflow.ellipsis)
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // ==================== 2. EVENT GRID VIEW (2 COLUMNS MOBILE) ====================

  Widget _buildEventGrid() {
    if (_filteredEvents.isEmpty) return const Center(child: Text("No events match filters.", style: TextStyle(color: Colors.grey)));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Mobile: 2 Cols, Desktop: 4 Cols
          int cols = constraints.maxWidth > 800 ? 4 : 2; 
          // Ratio optimized for card content
          double ratio = constraints.maxWidth > 800 ? 0.9 : 0.65; 

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
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
        borderRadius: BorderRadius.circular(18), // HTML style radius
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedEventId = eid;
              _selectedEventDoc = doc;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TITLE & BADGE
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        data['name'], 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2)
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30, height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(15)),
                      child: Text("$totalRegs", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B4DB7), fontSize: 13)),
                    )
                  ],
                ),
                
                const SizedBox(height: 12),

                // 2. TAGS ROW
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    _htmlTag(data['category'], const Color(0xFFE6F4FF), const Color(0xFF2B7CD3)),
                    _htmlTag(isGroup ? "Group" : "Single", const Color(0xFFF3E6FF), const Color(0xFF8B3BD3)),
                    _htmlTag(data['stage'] ?? 'Off-Stage', const Color(0xFFFFF0D9), const Color(0xFFE58A00)),
                  ],
                ),
                
                const Spacer(),
                const Divider(height: 20, color: Color(0xFFE5E7EB)),

                // 3. TEAM BREAKDOWN (Participating Teams & Count)
                // Using Wrap to fit in small cards
                if (eventRegs.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 4, runSpacing: 4,
                        children: _teams.map((team) {
                          int count = eventRegs.where((r) => r['teamId'] == team).length;
                          if (count == 0) return const SizedBox();
                          Color tc = _getTeamColor(team);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: tc.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tc.withOpacity(0.2))
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: tc),
                                const SizedBox(width: 4),
                                Text("$team: $count", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tc)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else
                   const Text("No Entries Yet", style: TextStyle(fontSize: 11, color: Colors.grey)),
                
                const SizedBox(height: 8),

                // 4. LIMIT INFO
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      "Limit: $limit ${isGroup ? 'Teams' : 'Entries'}", 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _htmlTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
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
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() { _selectedEventId = null; _selectedEventDoc = null; }),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
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
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), const Text("No registrations found.", style: TextStyle(color: Colors.grey))])) 
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: eventRegs.length,
              itemBuilder: (context, index) {
                var r = eventRegs[index];
                var rData = r.data() as Map<String, dynamic>;
                String regId = r.id;
                String team = rData['teamId'] ?? 'Unknown';
                Color tc = _getTeamColor(team);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: tc.withOpacity(0.1),
                      child: Text("${index + 1}", style: TextStyle(color: tc, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(isGroup ? team : (rData['studentName'] ?? "Unknown"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if(!isGroup) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text("Chest: ${rData['chestNo'] ?? '-'}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text("Team: $team", style: TextStyle(fontSize: 12, color: tc, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: () => _confirmReject(regId, rData['teamId'], eData['name'], isGroup),
                      icon: const Icon(Icons.block, size: 20, color: Colors.red),
                      tooltip: "Reject",
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
    
    String title = isGroup ? "Reject Team?" : "Reject Student?";
    String warning = isGroup 
        ? "Remove team '$teamId' from '$eventName'?" 
        : "Remove student from '$eventName'?";

    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warning, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Reason",
                hintText: "e.g. Document mismatch",
                border: OutlineInputBorder(),
                isDense: true
              ),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Reject"),
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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Rejected"), backgroundColor: Colors.red));
    }
  }
}
