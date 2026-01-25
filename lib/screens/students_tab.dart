// File: lib/screens/students_tab.dart
// Version: 11.0
// Description: Bulk Selection, Bulk Edit (Auto-assigns Chest No based on target group), Smart Chest Auto-fill.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../layout/responsive_layout.dart';
import 'package:fest_manager/utils/export_helper.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final db = FirebaseFirestore.instance;
  
  final List<StreamSubscription> _streams = [];
  Timer? _debounceTimer;
  String _currentSearch = "";

  // Selection Mode State
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};

  // Filters
  String? _filterTeam;
  String? _filterCategory;
  String? _filterGender;
  
  // Data
  List<DocumentSnapshot> _allStudents = [];
  List<DocumentSnapshot> _filteredStudents = [];
  Map<String, dynamic> _chestConfig = {};
  Map<String, dynamic> _teamDetails = {};
  List<String> _teams = [];
  List<String> _categories = [];
  bool _isMixedMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDataListeners();
    globalSearchQuery.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    globalSearchQuery.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    for (var s in _streams) s.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _currentSearch = globalSearchQuery.value.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  void _initDataListeners() {
    // 1. Settings
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _chestConfig = snap.data()?['chestConfig'] ?? {};
          _teamDetails = snap.data()?['teamDetails'] ?? {};
        });
      }
    }));

    // 2. Config
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    // 3. Students
    _streams.add(db.collection('students').orderBy('chestNo').snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _allStudents = snap.docs;
          _isLoading = false;
        });
        _applyFilters();
      }
    }));
  }

  void _applyFilters() {
    setState(() {
      _filteredStudents = _allStudents.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        if (_filterTeam != null && data['teamId'] != _filterTeam) return false;
        if (_filterCategory != null && data['categoryId'] != _filterCategory) return false;
        if (_filterGender != null && data['gender'] != _filterGender) return false;
        
        if (_currentSearch.isNotEmpty) {
          String name = data['name'].toString().toLowerCase();
          String chest = data['chestNo'].toString();
          if (!name.contains(_currentSearch) && !chest.contains(_currentSearch)) return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterTeam = null;
      _filterCategory = null;
      _filterGender = null;
      _applyFilters();
    });
  }

  Color _getTeamColor(String teamName) {
    if (_teamDetails.containsKey(teamName)) {
      int val = _teamDetails[teamName]['color'] ?? 0xFF3F51B5;
      return Color(val);
    }
    return Colors.indigo;
  }

  // --- AUTO CHEST NUMBER LOGIC ---
  int _calculateNextChestNo(String team, String category, String gender) {
    // Key format: Team-Category-Gender
    String key = "$team-$category-$gender"; 
    
    // 1. Get Base Number
    int base = _chestConfig[key] ?? 0;
    if (base == 0) return 0; // Not configured

    // 2. Find current max chest no in this specific group
    int maxCurrent = base;
    for (var doc in _allStudents) {
      var d = doc.data() as Map;
      if (d['teamId'] == team && d['categoryId'] == category && d['gender'] == gender) {
         int cNo = d['chestNo'] ?? 0;
         if (cNo > maxCurrent) maxCurrent = cNo;
      }
    }

    // 3. Return next
    return maxCurrent == base ? base + 1 : maxCurrent + 1; 
  }

  // --- SELECTION ACTIONS ---
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredStudents.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _filteredStudents.map((e) => e.id).toSet();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // TOP BAR: SWITCH BETWEEN FILTERS AND SELECTION BAR
            _isSelectionMode ? _buildSelectionBar() : _buildCompactActionCard(),
            const SizedBox(height: 10),
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _openAddStudentDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 1. SELECTION BAR
  Widget _buildSelectionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200)
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.indigo), onPressed: _exitSelectionMode),
          const SizedBox(width: 8),
          Text("${_selectedIds.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
          const Spacer(),
          TextButton.icon(
            onPressed: _selectAll,
            icon: Icon(_selectedIds.length == _filteredStudents.length ? Icons.check_box : Icons.check_box_outline_blank),
            label: const Text("All"),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: _selectedIds.isEmpty ? null : _showBulkEditDialog,
            tooltip: "Bulk Edit",
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _selectedIds.isEmpty ? null : _showBulkDeleteDialog,
            tooltip: "Bulk Delete",
          ),
        ],
      ),
    );
  }

  // 2. NORMAL FILTER BAR
  Widget _buildCompactActionCard() {
    bool hasFilter = _filterTeam!=null || _filterCategory!=null || _filterGender!=null;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _compactDropdown(width: 150, value: _filterTeam, label: "Select Team", items: _teams, onChanged: (v) { _filterTeam = v; _applyFilters(); }),
                    const SizedBox(width: 8),
                    _compactDropdown(width: 150, value: _filterCategory, label: "Select Category", items: _categories, onChanged: (v) { _filterCategory = v; _applyFilters(); }),
                    if (_isMixedMode) ...[
                      const SizedBox(width: 8),
                      _compactDropdown(width: 120, value: _filterGender, label: "Select Gender", items: ["Male", "Female"], onChanged: (v) { _filterGender = v; _applyFilters(); }),
                    ],
                  ],
                ),
              ),
            ),
            
            if(hasFilter)
              IconButton(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off, color: Colors.red, size: 20), tooltip: "Clear Filters", constraints: const BoxConstraints()),

            const SizedBox(width: 8),
            InkWell(
              onTap: _exportToExcel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: const Icon(Icons.table_chart, size: 18, color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactDropdown({required double width, required String? value, required String label, required List<String> items, required Function(String?) onChanged}) {
    return SizedBox(
      width: width,
      height: 40,
      child: DropdownButtonFormField<String>(
        value: value, isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text("All", style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
          ...items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
        ],
        onChanged: onChanged,
      ),
    );
  }

  // 3. STUDENT LIST
  Widget _buildStudentList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredStudents.isEmpty) return const Center(child: Text("No students found."));

    return ListView.separated(
      itemCount: _filteredStudents.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (c, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        var doc = _filteredStudents[index];
        var data = doc.data() as Map<String, dynamic>;
        String docId = doc.id;
        bool isSelected = _selectedIds.contains(docId);
        
        String gender = data['gender'] ?? 'Male';
        bool isMale = gender == 'Male';
        Color teamColor = _getTeamColor(data['teamId']);

        return InkWell(
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(docId);
              });
            }
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(docId);
            }
          },
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: _isSelectionMode && isSelected ? Colors.indigo.shade50 : Colors.white, 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10), 
              side: BorderSide(color: _isSelectionMode && isSelected ? Colors.indigo : Colors.grey.shade200, width: _isSelectionMode && isSelected ? 2 : 1)
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: _isSelectionMode 
                ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.indigo : Colors.grey)
                : Container(
                    width: 50, height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: teamColor, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: teamColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  ),
              
              title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: teamColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: teamColor.withOpacity(0.3))),
                      child: Row(children: [Icon(Icons.shield, size: 10, color: teamColor), const SizedBox(width: 4), Text(data['teamId'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: teamColor))]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(data['categoryId'], style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                    if(_isMixedMode) ...[const SizedBox(width: 8), Icon(isMale ? Icons.male : Icons.female, size: 14, color: isMale ? Colors.blue : Colors.pink), const SizedBox(width: 2), Text(isMale ? "M" : "F", style: TextStyle(fontSize: 12, color: isMale ? Colors.blue : Colors.pink, fontWeight: FontWeight.bold))]
                  ],
                ),
              ),
              
              // 3-DOT MENU
              trailing: _isSelectionMode ? null : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') _openEditDialog(docId, data);
                  if (value == 'delete') _deleteStudent(docId, data['name']);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text('Edit')])),
                  const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text('Delete')])),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 4. ADD DIALOG
  void _openAddStudentDialog() {
    String? selTeam; String? selCat; String selGender = 'Male'; bool isBulk = false;
    final nameCtrl = TextEditingController(); final bulkCtrl = TextEditingController(); final chestCtrl = TextEditingController(text: "0");

    void autoUpdateChest(StateSetter setDialogState) {
      if (selTeam != null && selCat != null) {
        int next = _calculateNextChestNo(selTeam!, selCat!, selGender);
        chestCtrl.text = next.toString();
        setDialogState(() {});
      }
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text("Register", style: TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           Row(children: [
             Expanded(child: _compactDropdown(width: double.infinity, value: selTeam, label: "Select Team", items: _teams, onChanged: (v){ setDialogState(()=>selTeam=v); autoUpdateChest(setDialogState); })),
             const SizedBox(width: 8),
             Expanded(child: _compactDropdown(width: double.infinity, value: selCat, label: "Select Category", items: _categories, onChanged: (v){ setDialogState(()=>selCat=v); autoUpdateChest(setDialogState); })),
           ]),
           if(_isMixedMode) ...[const SizedBox(height: 8), Row(children: [const Text("Gender: ", style: TextStyle(fontSize: 12)), Radio(value: "Male", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); autoUpdateChest(setDialogState); }), const Text("M"), Radio(value: "Female", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); autoUpdateChest(setDialogState); }), const Text("F")])],
           const Divider(height: 16),
           
           Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Bulk Names", style: TextStyle(fontSize: 12)), Switch(value: isBulk, onChanged: (v)=>setDialogState(()=>isBulk=v))]),
           
           if(!isBulk) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name", isDense: true, border: OutlineInputBorder()))
           else TextField(controller: bulkCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Names (One per line)", isDense: true, border: OutlineInputBorder())),
           
           const SizedBox(height: 12),
           TextField(controller: chestCtrl, decoration: const InputDecoration(labelText: "Start Chest No", helperText: "Auto-suggested", border: OutlineInputBorder()), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), 
          ElevatedButton(
            onPressed: () async {
               if (selTeam == null || selCat == null) return;
               int startChest = int.tryParse(chestCtrl.text) ?? 0;
               if (startChest == 0) return;

               var batch = db.batch();
               if(isBulk) { 
                 int currentC = startChest;
                 for(var n in bulkCtrl.text.split('\n').where((s)=>s.trim().isNotEmpty)) { 
                   batch.set(db.collection('students').doc(), {'name':n.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':currentC++, 'createdAt':FieldValue.serverTimestamp()}); 
                 } 
               } else if(nameCtrl.text.isNotEmpty) { 
                 batch.set(db.collection('students').doc(), {'name':nameCtrl.text.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':startChest, 'createdAt':FieldValue.serverTimestamp()}); 
               }
               await batch.commit(); 
               if(mounted) Navigator.pop(ctx);
            }, 
            child: const Text("Register")
          )
        ]
      );
    }));
  }

  // 5. SINGLE EDIT
  void _openEditDialog(String id, Map d) {
      final nCtrl = TextEditingController(text: d['name']); 
      final cCtrl = TextEditingController(text: d['chestNo'].toString());
      String team = d['teamId']; 
      String cat = d['categoryId']; 
      String gen = d['gender'] ?? 'Male';
      
      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, setDialogState) {
          
          void updateChestIfNeeded() {
             int next = _calculateNextChestNo(team, cat, gen);
             cCtrl.text = next.toString();
          }

          return AlertDialog(
            title: const Text("Edit"), contentPadding: const EdgeInsets.all(16),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
               TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name", isDense: true, border: OutlineInputBorder())), const SizedBox(height: 8),
               Row(children: [
                 Expanded(child: _compactDropdown(width: double.infinity, value: team, label: "Select Team", items: _teams, onChanged: (v){ setDialogState(()=>team=v!); updateChestIfNeeded(); })), 
                 const SizedBox(width: 8), 
                 Expanded(child: _compactDropdown(width: double.infinity, value: cat, label: "Select Category", items: _categories, onChanged: (v){ setDialogState(()=>cat=v!); updateChestIfNeeded(); }))
               ]),
               if(_isMixedMode) Row(children: [Radio(value: "Male", groupValue: gen, onChanged: (v){ setDialogState(()=>gen=v.toString()); updateChestIfNeeded(); }), const Text("M"), Radio(value: "Female", groupValue: gen, onChanged: (v){ setDialogState(()=>gen=v.toString()); updateChestIfNeeded(); }), const Text("F")]),
               TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Chest No", isDense: true, border: OutlineInputBorder(), helperText: "Updates automatically on change"))
            ]),
            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () async { await db.collection('students').doc(id).update({'name':nCtrl.text,'teamId':team,'categoryId':cat,'chestNo':int.parse(cCtrl.text),'gender':gen}); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))]
          );
      }));
  }

  // 6. BULK EDIT (UPDATED: Auto Update Chest No)
  void _showBulkEditDialog() {
    String? selectedTeam;
    String? selectedCat;
    String? selectedGender;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text("Bulk Edit (${_selectedIds.length} items)"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select fields to update.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(value: selectedTeam, decoration: const InputDecoration(labelText: "Change Team (Optional)"), items: _teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setDialogState(() => selectedTeam = v)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: selectedCat, decoration: const InputDecoration(labelText: "Change Category (Optional)"), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDialogState(() => selectedCat = v)),
              if (_isMixedMode) ...[const SizedBox(height: 10), DropdownButtonFormField<String>(value: selectedGender, decoration: const InputDecoration(labelText: "Change Gender (Optional)"), items: const [DropdownMenuItem(value: "Male", child: Text("Male")), DropdownMenuItem(value: "Female", child: Text("Female"))], onChanged: (v) => setDialogState(() => selectedGender = v))],
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                child: const Row(children: [Icon(Icons.auto_fix_high, size: 16, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text("Chest Numbers will be automatically REASSIGNED based on the new groups.", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)))])
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                var batch = db.batch();
                
                // Helper to track incrementing chest numbers for groups during this bulk process
                Map<String, int> runningMaxChests = {};

                // Helper to get next chest (initializing from DB if needed)
                int getNextForGroup(String t, String c, String g) {
                  String key = "$t-$c-$g";
                  if (!runningMaxChests.containsKey(key)) {
                     // Calculate max from DB
                     int base = _chestConfig[key] ?? 0;
                     int max = base;
                     for (var doc in _allStudents) {
                       var d = doc.data() as Map;
                       if (d['teamId'] == t && d['categoryId'] == c && d['gender'] == g) {
                         int cNo = d['chestNo'] ?? 0;
                         if (cNo > max) max = cNo;
                       }
                     }
                     runningMaxChests[key] = max;
                  }
                  // Increment and return
                  runningMaxChests[key] = runningMaxChests[key]! + 1;
                  return runningMaxChests[key]!;
                }

                for (var id in _selectedIds) {
                  var currentDoc = _allStudents.firstWhere((d) => d.id == id);
                  var curData = currentDoc.data() as Map<String, dynamic>;

                  String t = selectedTeam ?? curData['teamId'];
                  String c = selectedCat ?? curData['categoryId'];
                  String g = selectedGender ?? curData['gender'] ?? 'Male';

                  Map<String, dynamic> updates = {};
                  if (selectedTeam != null) updates['teamId'] = t;
                  if (selectedCat != null) updates['categoryId'] = c;
                  if (selectedGender != null) updates['gender'] = g;
                  
                  // Always recalculate chest no if we are updating groups
                  // Even if only 1 field changed, the combination changed, so sequence must change.
                  if (updates.isNotEmpty) {
                    updates['chestNo'] = getNextForGroup(t, c, g);
                    batch.update(db.collection('students').doc(id), updates);
                  }
                }
                
                await batch.commit();
                _exitSelectionMode();
                if(mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk Update & Reassignment Successful")));
                }
              }, 
              child: const Text("Update All")
            )
          ],
        );
      }
    ));
  }

  // 7. BULK DELETE
  void _showBulkDeleteDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Bulk Delete", style: TextStyle(color: Colors.red)),
      content: Text("Are you sure you want to delete ${_selectedIds.length} students?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            var batch = db.batch();
            for (var id in _selectedIds) batch.delete(db.collection('students').doc(id));
            await batch.commit();
            _exitSelectionMode();
            if(mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Students Deleted")));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text("Delete All"),
        )
      ],
    ));
  }

  Future<void> _deleteStudent(String id, String n) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Student?"), content: Text("Remove '$n'?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("No")), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Yes"))])) ?? false;
    if (confirm) { await db.collection('students').doc(id).delete(); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted"))); }
  }

  Future<void> _exportToExcel() async {
    if (_filteredStudents.isEmpty) return;
    String csv = "Chest No,Name,Team,Category,Gender\n";
    for(var d in _filteredStudents) { var m = d.data() as Map; csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; }
    await ExportHelper.downloadCsv(csv, "students_list.csv");
  }
}
