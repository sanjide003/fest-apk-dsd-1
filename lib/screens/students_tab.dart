// File: lib/screens/students_tab.dart
// Version: 8.0
// Description: Restored Rich UI, 3-Dot Menu, Delete Confirmation (Yes/No).

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

  // Filters
  String? _filterTeam;
  String? _filterCategory;
  String? _filterGender;
  
  // Data
  List<DocumentSnapshot> _allStudents = [];
  List<DocumentSnapshot> _filteredStudents = [];
  Map<String, dynamic> _chestConfig = {};
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
      setState(() {
        _currentSearch = globalSearchQuery.value.toLowerCase();
        _applyFilters();
      });
    });
  }

  void _initDataListeners() {
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _chestConfig = snap.data()?['chestConfig'] ?? {};
        });
      }
    }));

    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildCompactActionCard(),
            const SizedBox(height: 10),
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudentDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 1. COMPACT ACTION CARD
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
                    _compactDropdown(width: 140, value: _filterTeam, label: "Team", items: _teams, onChanged: (v) { _filterTeam = v; _applyFilters(); }),
                    const SizedBox(width: 8),
                    _compactDropdown(width: 140, value: _filterCategory, label: "Category", items: _categories, onChanged: (v) { _filterCategory = v; _applyFilters(); }),
                    if (_isMixedMode) ...[
                      const SizedBox(width: 8),
                      _compactDropdown(width: 100, value: _filterGender, label: "Gender", items: ["Male", "Female"], onChanged: (v) { _filterGender = v; _applyFilters(); }),
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
      height: 36,
      child: DropdownButtonFormField<String>(
        value: value, isExpanded: true,
        decoration: InputDecoration(
          labelText: label, isDense: true, filled: true, fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  // 2. STUDENT LIST (RESTORED VISUALS + 3 DOT MENU)
  Widget _buildStudentList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredStudents.isEmpty) return const Center(child: Text("No students found."));

    return ListView.separated(
      itemCount: _filteredStudents.length,
      padding: const EdgeInsets.only(bottom: 80),
      separatorBuilder: (c, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        var data = _filteredStudents[index].data() as Map<String, dynamic>;
        String docId = _filteredStudents[index].id;
        String gender = data['gender'] ?? 'Male';
        bool isMale = gender == 'Male';
        
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            // Chest Number Box
            leading: Container(
              width: 50, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.indigo, // Solid color for better visibility
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
              ),
              child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ),
            
            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            
            // Subtitle with Badges
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  // Team Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
                    child: Row(children: [
                       const Icon(Icons.shield, size: 10, color: Colors.blue),
                       const SizedBox(width: 4),
                       Text(data['teamId'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  
                  // Category Icon
                  Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 2),
                  Text(data['categoryId'], style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                  
                  const SizedBox(width: 8),
                  
                  // Gender Icon
                  if(_isMixedMode) ...[
                     Icon(isMale ? Icons.male : Icons.female, size: 14, color: isMale ? Colors.blue : Colors.pink),
                     const SizedBox(width: 2),
                     Text(isMale ? "M" : "F", style: TextStyle(fontSize: 12, color: isMale ? Colors.blue : Colors.pink, fontWeight: FontWeight.bold))
                  ]
                ],
              ),
            ),
            
            // 3-DOT MENU
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'edit') _openEditDialog(docId, data);
                if (value == 'delete') _deleteStudent(docId, data['name']);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text('Edit')]),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text('Delete')]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. ADD DIALOG
  void _openAddStudentDialog() {
    String? selTeam; String? selCat; String selGender = 'Male'; bool isBulk = false;
    final nameCtrl = TextEditingController(); final bulkCtrl = TextEditingController(); int nextChest = 0; String? errorMsg;

    void calcInstantChest(StateSetter setDialogState) {
        if (selTeam == null || selCat == null) return;
        String key = _isMixedMode ? "$selTeam-$selCat-$selGender" : "$selTeam-$selCat-Male";
        int? startVal = _chestConfig[key];
        if (startVal == null) { setDialogState(() { errorMsg = "Start Chest No not set."; nextChest = 0; }); return; } 
        else { setDialogState(() => errorMsg = null); }
        int maxVal = startVal; bool found = false;
        for (var doc in _allStudents) {
            var d = doc.data() as Map<String, dynamic>;
            if (d['teamId'] == selTeam && d['categoryId'] == selCat) {
                if (!_isMixedMode || d['gender'] == selGender) {
                    int c = d['chestNo'] as int; if (c >= maxVal) { maxVal = c; found = true; }
                }
            }
        }
        setDialogState(() => nextChest = found ? maxVal + 1 : startVal);
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text("Register", style: TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.all(16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           Row(children: [
             Expanded(child: _compactDropdown(width: double.infinity, value: selTeam, label: "Team", items: _teams, onChanged: (v){ setDialogState(()=>selTeam=v); calcInstantChest(setDialogState); })),
             const SizedBox(width: 8),
             Expanded(child: _compactDropdown(width: double.infinity, value: selCat, label: "Category", items: _categories, onChanged: (v){ setDialogState(()=>selCat=v); calcInstantChest(setDialogState); })),
           ]),
           if(_isMixedMode) ...[const SizedBox(height: 8), Row(children: [const Text("Gender: ", style: TextStyle(fontSize: 12)), Radio(value: "Male", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("M"), Radio(value: "Female", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("F")])],
           const Divider(height: 16),
           if(errorMsg != null) Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 11))
           else ...[
             Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Bulk", style: TextStyle(fontSize: 12)), Switch(value: isBulk, onChanged: (v)=>setDialogState(()=>isBulk=v))]),
             if(!isBulk) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name", isDense: true, border: OutlineInputBorder()))
             else TextField(controller: bulkCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Names (Lines)", isDense: true, border: OutlineInputBorder())),
             const SizedBox(height: 10),
             Text("Next: $nextChest", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))
           ]
        ]),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: (errorMsg!=null||nextChest==0)?null:() async {
             var batch = db.batch(); int cNo = nextChest;
             if(isBulk) { for(var n in bulkCtrl.text.split('\n').where((s)=>s.trim().isNotEmpty)) { batch.set(db.collection('students').doc(), {'name':n.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':cNo++, 'createdAt':FieldValue.serverTimestamp()}); } } 
             else if(nameCtrl.text.isNotEmpty) { batch.set(db.collection('students').doc(), {'name':nameCtrl.text.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':cNo, 'createdAt':FieldValue.serverTimestamp()}); }
             await batch.commit(); Navigator.pop(ctx);
        }, child: const Text("Register"))]
      );
    }));
  }

  void _openEditDialog(String id, Map d) {
      final nCtrl = TextEditingController(text: d['name']); final cCtrl = TextEditingController(text: d['chestNo'].toString());
      String team = d['teamId']; String cat = d['categoryId']; String gen = d['gender'] ?? 'Male';
      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, setDialogState) => AlertDialog(
          title: const Text("Edit"), contentPadding: const EdgeInsets.all(16),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
             TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name", isDense: true, border: OutlineInputBorder())), const SizedBox(height: 8),
             Row(children: [Expanded(child: _compactDropdown(width: double.infinity, value: team, label: "Team", items: _teams, onChanged: (v)=>setDialogState(()=>team=v!))), const SizedBox(width: 8), Expanded(child: _compactDropdown(width: double.infinity, value: cat, label: "Category", items: _categories, onChanged: (v)=>setDialogState(()=>cat=v!)))]),
             if(_isMixedMode) Row(children: [Radio(value: "Male", groupValue: gen, onChanged: (v)=>setDialogState(()=>gen=v.toString())), const Text("M"), Radio(value: "Female", groupValue: gen, onChanged: (v)=>setDialogState(()=>gen=v.toString())), const Text("F")]),
             TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Chest No", isDense: true, border: OutlineInputBorder()))
          ]),
          actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () async { await db.collection('students').doc(id).update({'name':nCtrl.text,'teamId':team,'categoryId':cat,'chestNo':int.parse(cCtrl.text),'gender':gen}); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))]
      )));
  }

  // 4. CONFIRM DELETE DIALOG (YES/NO)
  Future<void> _deleteStudent(String id, String n) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Student?", style: TextStyle(fontWeight: FontWeight.bold)), 
        content: Text("Are you sure you want to permanently remove '$n'?"), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false), 
            child: const Text("No", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
            child: const Text("Yes, Delete")
          )
        ]
      )
    ) ?? false;

    if (confirm) {
      await db.collection('students').doc(id).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student deleted successfully")));
    }
  }

  Future<void> _exportToExcel() async {
    if (_filteredStudents.isEmpty) return;
    String csv = "Chest No,Name,Team,Category,Gender\n";
    for(var d in _filteredStudents) { var m = d.data() as Map; csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; }
    await ExportHelper.downloadCsv(csv, "students_list.csv");
  }
}