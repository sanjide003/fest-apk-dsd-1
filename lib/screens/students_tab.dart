// File: lib/screens/students_tab.dart
// Version: 10.0
// Description: Bulk Selection (Long Press), Select All, Bulk Edit/Delete, and Smart Chest No Auto-Generation.

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
  Map<String, dynamic> _chestConfig = {}; // Matrix from Settings
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
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentSearch = globalSearchQuery.value.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  void _initDataListeners() {
    // 1. Listen to Config (Mixed Mode)
    _streams.add(db.collection('config').doc('main').snapshots().listen((snap) {
      if (mounted) setState(() => _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed');
    }));

    // 2. Listen to Settings (Teams, Cats, Chest Matrix)
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        var d = snap.data()!;
        setState(() {
          _teams = List<String>.from(d['teams'] ?? []);
          _categories = List<String>.from(d['categories'] ?? []);
          _chestConfig = d['chestConfig'] ?? {};
        });
      }
    }));

    // 3. Listen to Students
    _streams.add(db.collection('students').snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _allStudents = snap.docs;
          _isLoading = false;
          _applyFilters();
        });
      }
    }));
  }

  void _applyFilters() {
    _filteredStudents = _allStudents.where((doc) {
      var d = doc.data() as Map<String, dynamic>;
      bool matchSearch = _currentSearch.isEmpty || 
          d['name'].toString().toLowerCase().contains(_currentSearch) ||
          d['chestNo'].toString().contains(_currentSearch);
      
      bool matchTeam = _filterTeam == null || d['teamId'] == _filterTeam;
      bool matchCat = _filterCategory == null || d['categoryId'] == _filterCategory;
      bool matchGender = _filterGender == null || d['gender'] == _filterGender;

      return matchSearch && matchTeam && matchCat && matchGender;
    }).toList();
    
    // Sort by Chest No
    _filteredStudents.sort((a, b) => (a['chestNo'] as int).compareTo(b['chestNo'] as int));
  }

  // --- AUTO CHEST NUMBER LOGIC ---
  int _calculateNextChestNo(String team, String category, String gender) {
    // 1. Get Base Number from Matrix
    String key = "$team-$category-$gender";
    int base = _chestConfig[key] ?? 0;
    
    if (base == 0) return 0; // Not configured in settings

    // 2. Find max current chest no in this group
    int maxCurrent = base;
    
    // Efficiently check existing students in memory
    for (var doc in _allStudents) {
      var d = doc.data() as Map;
      if (d['teamId'] == team && d['categoryId'] == category && d['gender'] == gender) {
        int cNo = d['chestNo'] ?? 0;
        if (cNo > maxCurrent) maxCurrent = cNo;
      }
    }

    // 3. Return Next Number
    // If no students yet, return Base. If students exist, return Max + 1.
    // Wait, if base is 100, and no students, first should be 101 or 100? Usually 101.
    // Let's assume user inputs 'Starting Series' like 100. So first student is 101.
    return maxCurrent == base ? base + 1 : maxCurrent + 1;
  }

  // --- SELECTION LOGIC ---
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
        _selectedIds.clear(); // Deselect All
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
      body: Column(
        children: [
          // 1. TOP BAR (Search OR Selection Actions)
          _isSelectionMode ? _buildSelectionBar() : _buildFilterBar(),
          
          // 2. STUDENT LIST
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _filteredStudents.isEmpty 
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // Mobile 2 Columns
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85, // Taller cards
                      ),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        return _buildStudentCard(_filteredStudents[index]);
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: () => _showAddEditStudentDialog(null),
        label: const Text("Add Student"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSelectionBar() {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close), 
            onPressed: _exitSelectionMode,
            tooltip: "Close Selection",
          ),
          const SizedBox(width: 8),
          Text(
            "${_selectedIds.length} Selected", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)
          ),
          const Spacer(),
          // Select All
          TextButton.icon(
            onPressed: _selectAll,
            icon: Icon(_selectedIds.length == _filteredStudents.length ? Icons.check_box : Icons.check_box_outline_blank),
            label: const Text("All"),
          ),
          // Bulk Edit
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: _selectedIds.isEmpty ? null : () => _showBulkEditDialog(),
            tooltip: "Bulk Edit",
          ),
          // Bulk Delete
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _selectedIds.isEmpty ? null : () => _showBulkDeleteDialog(),
            tooltip: "Bulk Delete",
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_isMixedMode) ...[
                  _buildFilterChip("Boys", _filterGender == "Male", () => setState(() => _filterGender = _filterGender == "Male" ? null : "Male")),
                  const SizedBox(width: 8),
                  _buildFilterChip("Girls", _filterGender == "Female", () => setState(() => _filterGender = _filterGender == "Female" ? null : "Female")),
                  const SizedBox(width: 8),
                ],
                // Team Filters
                DropdownButton<String>(
                  value: _filterTeam,
                  hint: const Text("All Teams", style: TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  onChanged: (v) => setState(() => _filterTeam = v),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Teams")),
                    ..._teams.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  ],
                ),
                const SizedBox(width: 10),
                // Category Filters
                DropdownButton<String>(
                  value: _filterCategory,
                  hint: const Text("All Cats", style: TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  onChanged: (v) => setState(() => _filterCategory = v),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Cats")),
                    ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  ],
                ),
                const SizedBox(width: 10),
                // Export Button
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.green),
                  onPressed: _exportToExcel,
                  tooltip: "Export List",
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo,
      labelStyle: TextStyle(color: isSelected ? Colors.indigo : Colors.black87, fontSize: 12),
    );
  }

  Widget _buildStudentCard(DocumentSnapshot doc) {
    Map d = doc.data() as Map;
    bool isSelected = _selectedIds.contains(doc.id);
    
    // Team Color
    Color teamColor = Colors.grey; // Default
    // Assuming team details are needed, but for now using generic colors or passed from logic
    
    return InkWell(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedIds.add(doc.id);
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(doc.id);
        } else {
          _showAddEditStudentDialog(doc);
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: _isSelectionMode && isSelected 
                  ? Border.all(color: Colors.indigo, width: 3) 
                  : Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Chest No)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15))
                  ),
                  child: Center(
                    child: Text(
                      "${d['chestNo']}", 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)
                    ),
                  ),
                ),
                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(d['name'], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(d['teamId'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text("${d['categoryId']} • ${d['gender']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Checkbox Overlay
          if (_isSelectionMode)
            Positioned(
              top: 8, right: 8,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.indigo : Colors.grey,
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("No students found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- DIALOGS ---

  // 1. ADD / EDIT STUDENT
  void _showAddEditStudentDialog(DocumentSnapshot? doc) {
    bool isEdit = doc != null;
    Map d = isEdit ? doc.data() as Map : {};
    
    final nCtrl = TextEditingController(text: d['name'] ?? '');
    final cCtrl = TextEditingController(text: (d['chestNo'] ?? 0).toString());
    
    String? team = d['teamId'] ?? (_teams.isNotEmpty ? _teams.first : null);
    String? cat = d['categoryId'] ?? (_categories.isNotEmpty ? _categories.first : null);
    String gen = d['gender'] ?? 'Male';

    // Helper to update chest no automatically
    void autoUpdateChestNo(StateSetter setDialogState) {
      if (!isEdit && team != null && cat != null) {
        int next = _calculateNextChestNo(team!, cat!, gen);
        cCtrl.text = next.toString();
      }
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        
        // Auto-fill chest no on first load of Add Dialog
        if (!isEdit && cCtrl.text == "0") {
           autoUpdateChestNo(setDialogState);
        }

        return AlertDialog(
          title: Text(isEdit ? "Edit Student" : "New Student"),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name", filled: true)),
              const SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: team,
                decoration: const InputDecoration(labelText: "Team"),
                items: _teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) { 
                  setDialogState(() => team = v); 
                  autoUpdateChestNo(setDialogState);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(labelText: "Category"),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  setDialogState(() => cat = v);
                  autoUpdateChestNo(setDialogState);
                },
              ),
              const SizedBox(height: 12),
              if (_isMixedMode)
                Row(
                  children: [
                    Expanded(child: RadioListTile(title: const Text("Male"), value: "Male", groupValue: gen, onChanged: (v) { setDialogState(() => gen = v.toString()); autoUpdateChestNo(setDialogState); })),
                    Expanded(child: RadioListTile(title: const Text("Female"), value: "Female", groupValue: gen, onChanged: (v) { setDialogState(() => gen = v.toString()); autoUpdateChestNo(setDialogState); })),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: cCtrl, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: "Chest No", helperText: "Auto-generated based on settings", filled: true)
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
            // DELETE BUTTON (Only in Single Edit)
            if (isEdit) 
              TextButton(
                onPressed: () { Navigator.pop(ctx); _deleteStudent(doc.id, d['name']); },
                child: const Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                if(nCtrl.text.isNotEmpty && team != null && cat != null) {
                  Map<String, dynamic> data = {
                    'name': nCtrl.text.trim(),
                    'teamId': team,
                    'categoryId': cat,
                    'chestNo': int.parse(cCtrl.text),
                    'gender': gen
                  };

                  if(isEdit) {
                    await db.collection('students').doc(doc.id).update(data);
                  } else {
                    await db.collection('students').add(data);
                  }
                  if(mounted) Navigator.pop(ctx);
                }
              }, 
              child: const Text("Save")
            )
          ]
        );
      }
    ));
  }

  // 2. BULK EDIT DIALOG
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
              const Text("Select fields to update. Leave empty to keep original values.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedTeam,
                decoration: const InputDecoration(labelText: "Change Team (Optional)"),
                items: _teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setDialogState(() => selectedTeam = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: const InputDecoration(labelText: "Change Category (Optional)"),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => selectedCat = v),
              ),
              if (_isMixedMode) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(labelText: "Change Gender (Optional)"),
                  items: const [DropdownMenuItem(value: "Male", child: Text("Male")), DropdownMenuItem(value: "Female", child: Text("Female"))],
                  onChanged: (v) => setDialogState(() => selectedGender = v),
                ),
              ],
              const SizedBox(height: 15),
              const Text("Note: Chest Numbers will be cleared to '0' on update.", style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                var batch = db.batch();
                for (var id in _selectedIds) {
                  Map<String, dynamic> updates = {};
                  if (selectedTeam != null) updates['teamId'] = selectedTeam;
                  if (selectedCat != null) updates['categoryId'] = selectedCat;
                  if (selectedGender != null) updates['gender'] = selectedGender;
                  
                  // If any change, clear Chest No
                  if (updates.isNotEmpty) {
                    updates['chestNo'] = 0; // Cleared as per requirement
                    batch.update(db.collection('students').doc(id), updates);
                  }
                }
                await batch.commit();
                _exitSelectionMode();
                if(mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk Update Successful")));
                }
              }, 
              child: const Text("Update All")
            )
          ],
        );
      }
    ));
  }

  // 3. BULK DELETE DIALOG
  void _showBulkDeleteDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Bulk Delete"),
      content: Text("Are you sure you want to delete ${_selectedIds.length} students?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            var batch = db.batch();
            for (var id in _selectedIds) {
              batch.delete(db.collection('students').doc(id));
            }
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

  // Single Delete (Called from Edit Dialog)
  Future<void> _deleteStudent(String id, String n) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Student?"), 
        content: Text("Remove '$n'?"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Yes"))
        ]
      )
    ) ?? false;

    if (confirm) {
      await db.collection('students').doc(id).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
    }
  }

  Future<void> _exportToExcel() async {
    if (_filteredStudents.isEmpty) return;
    String csv = "Chest No,Name,Team,Category,Gender\n";
    for(var d in _filteredStudents) { var m = d.data() as Map; csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; }
    await ExportHelper.downloadCsv(csv, "students_list.csv");
  }
}
