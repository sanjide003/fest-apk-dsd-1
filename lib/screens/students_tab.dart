// File: lib/screens/students_tab.dart
// Version: 5.0
// Description: Restored Gender Icons, Category Icons, and robust search logic.

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
  
  // Stream & Search Control
  final List<StreamSubscription> _streams = [];
  Timer? _debounceTimer;
  String _currentSearch = "";

  // Filters
  String? _filterTeam;
  String? _filterCategory;
  String? _filterGender;
  
  // Data Caches
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
    // 1. Settings
    _streams.add(db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _chestConfig = snap.data()?['chestConfig'] ?? {};
        });
      }
    }));

    // 2. Mode
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // FILTERS
            _buildActionCard(),
            const SizedBox(height: 16),
            
            // LIST
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

  // 1. ACTION CARD
  Widget _buildActionCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10, runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 150, child: _styledDropdown(value: _filterTeam, label: "Team", items: _teams, onChanged: (v) { _filterTeam = v; _applyFilters(); })),
            SizedBox(width: 150, child: _styledDropdown(value: _filterCategory, label: "Category", items: _categories, onChanged: (v) { _filterCategory = v; _applyFilters(); })),
            if (_isMixedMode)
               SizedBox(width: 120, child: _styledDropdown(value: _filterGender, label: "Gender", items: ["Male", "Female"], onChanged: (v) { _filterGender = v; _applyFilters(); })),
            
            InkWell(
              onTap: _exportToExcel,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.table_chart, size: 18, color: Colors.green), SizedBox(width: 6), Text("Excel", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _styledDropdown({required String? value, required String label, required List<String> items, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value, isExpanded: true,
      decoration: InputDecoration(
        labelText: label, isDense: true, filled: true, fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text("All", style: TextStyle(color: Colors.grey.shade600))),
        ...items.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)))
      ],
      onChanged: onChanged,
    );
  }

  // 2. STUDENT LIST
  Widget _buildStudentList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_filteredStudents.isEmpty) return const Center(child: Text("No students found."));

    return ListView.builder(
      itemCount: _filteredStudents.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        var data = _filteredStudents[index].data() as Map<String, dynamic>;
        String docId = _filteredStudents[index].id;
        String gender = data['gender'] ?? 'Male';
        bool isMale = gender == 'Male';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Container(
              width: 50, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50, 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withOpacity(0.1))
              ),
              child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
            ),
            title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Row(
              children: [
                // Team Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(data['teamId'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                // Category
                const Icon(Icons.category, size: 12, color: Colors.grey),
                const SizedBox(width: 2),
                Text(data['categoryId'], style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                // Gender Icon
                if(_isMixedMode) ...[
                   Icon(isMale ? Icons.male : Icons.female, size: 14, color: isMale ? Colors.blue : Colors.pink),
                   const SizedBox(width: 2),
                   Text(isMale ? "M" : "F", style: TextStyle(fontSize: 12, color: isMale ? Colors.blue : Colors.pink, fontWeight: FontWeight.bold))
                ]
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _openEditDialog(docId, data)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteStudent(docId, data['name'])),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. ADD DIALOG
  void _openAddStudentDialog() {
    String? selTeam;
    String? selCat;
    String selGender = 'Male';
    bool isBulk = false;
    final nameCtrl = TextEditingController();
    final bulkCtrl = TextEditingController();
    int nextChest = 0;
    String? errorMsg;

    void calcInstantChest(StateSetter setDialogState) {
      if (selTeam == null || selCat == null) return;
      
      String key = _isMixedMode ? "$selTeam-$selCat-$selGender" : "$selTeam-$selCat-Male";
      int? startVal = _chestConfig[key];

      if (startVal == null) {
        setDialogState(() { errorMsg = "Start Chest No not set in Settings > Matrix."; nextChest = 0; });
        return;
      } else {
        setDialogState(() => errorMsg = null);
      }

      // Calc Max
      int maxVal = startVal;
      bool found = false;
      for (var doc in _allStudents) {
        var d = doc.data() as Map<String, dynamic>;
        if (d['teamId'] == selTeam && d['categoryId'] == selCat) {
          if (!_isMixedMode || d['gender'] == selGender) {
            int c = d['chestNo'] as int;
            if (c >= maxVal) { maxVal = c; found = true; }
          }
        }
      }
      setDialogState(() => nextChest = found ? maxVal + 1 : startVal);
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text("Register Student", style: TextStyle(fontWeight: FontWeight.bold)),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           Row(children: [
             Expanded(child: _styledDropdown(value: selTeam, label: "Team", items: _teams, onChanged: (v){ setDialogState(()=>selTeam=v); calcInstantChest(setDialogState); })),
             const SizedBox(width: 10),
             Expanded(child: _styledDropdown(value: selCat, label: "Category", items: _categories, onChanged: (v){ setDialogState(()=>selCat=v); calcInstantChest(setDialogState); })),
           ]),
           if(_isMixedMode) ...[
             const SizedBox(height: 10),
             Row(children: [const Text("Gender: "), Radio(value: "Male", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("Male"), Radio(value: "Female", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("Female")]),
           ],
           const Divider(height: 24),
           
           if(errorMsg != null)
             Container(padding: const EdgeInsets.all(8), color: Colors.red.shade50, child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)))
           else ...[
             Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Bulk Mode", style: TextStyle(fontWeight: FontWeight.bold)), Switch(value: isBulk, onChanged: (v)=>setDialogState(()=>isBulk=v))]),
             if(!isBulk) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Student Name", filled: true))
             else TextField(controller: bulkCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "Names (One per line)", filled: true, alignLabelWithHint: true)),
             const SizedBox(height: 16),
             Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Next Chest No: "), Text("$nextChest", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo))]))
           ]
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: (errorMsg != null || nextChest == 0) ? null : () async {
             var batch = db.batch();
             int cNo = nextChest;
             if(isBulk) {
               List names = bulkCtrl.text.split('\n').where((s)=>s.trim().isNotEmpty).toList();
               for(var n in names) { batch.set(db.collection('students').doc(), {'name':n.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':cNo++, 'createdAt':FieldValue.serverTimestamp()}); }
             } else {
               if(nameCtrl.text.isNotEmpty) batch.set(db.collection('students').doc(), {'name':nameCtrl.text.trim(), 'teamId':selTeam, 'categoryId':selCat, 'gender':selGender, 'chestNo':cNo, 'createdAt':FieldValue.serverTimestamp()});
             }
             await batch.commit(); Navigator.pop(ctx);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful!")));
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text("Register"))
        ],
      );
    }));
  }

  // 4. EDIT DIALOG
  void _openEditDialog(String id, Map d) {
    final nCtrl = TextEditingController(text: d['name']);
    final cCtrl = TextEditingController(text: d['chestNo'].toString());
    String team = d['teamId']; 
    String cat = d['categoryId']; 
    String gen = d['gender'] ?? 'Male';
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Edit Student"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
             TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name", filled: true)),
             const SizedBox(height: 10),
             Row(children: [
               Expanded(child: _styledDropdown(value: team, label: "Team", items: _teams, onChanged: (v) => setDialogState(() => team = v!))),
               const SizedBox(width: 10),
               Expanded(child: _styledDropdown(value: cat, label: "Category", items: _categories, onChanged: (v) => setDialogState(() => cat = v!))),
             ]),
             const SizedBox(height: 10),
             if(_isMixedMode) Row(children: [const Text("Gender: "), Radio(value: "Male", groupValue: gen, onChanged: (v) => setDialogState(() => gen = v.toString())), const Text("M"), Radio(value: "Female", groupValue: gen, onChanged: (v) => setDialogState(() => gen = v.toString())), const Text("F")]),
             TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Chest No (Manual)", filled: true)),
          ]), 
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(onPressed: () async {
                 await db.collection('students').doc(id).update({'name':nCtrl.text,'teamId':team,'categoryId':cat,'chestNo':int.parse(cCtrl.text),'gender':gen});
                 if(mounted) Navigator.pop(ctx);
             }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("Update"))
          ]
        );
      }
    ));
  }

  // 5. DELETE
  Future<void> _deleteStudent(String id, String n) async {
    if(await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Delete?"), content: Text("Remove '$n' permanently?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete"))])) ?? false) {
      await db.collection('students').doc(id).delete();
    }
  }

  Future<void> _exportToExcel() async {
    if (_filteredStudents.isEmpty) return;
    String csv = "Chest No,Name,Team,Category,Gender\n";
    for(var d in _filteredStudents) { 
      var m = d.data() as Map; 
      csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; 
    }
    await ExportHelper.downloadCsv(csv, "students_list.csv");
  }
}