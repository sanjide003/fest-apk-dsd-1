// File: lib/screens/students_tab.dart
// Version: 3.3
// Description: UI Improvements: Excel Icon with text, Styled Dropdowns, Gender Edit, Confirmations.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../layout/responsive_layout.dart';
import 'package:fest_manager/utils/export_helper.dart'; // Ensure this helper exists from previous steps

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final db = FirebaseFirestore.instance;
  
  // Filters
  String? _filterTeam;
  String? _filterCategory;
  String? _filterGender;
  
  // Data Caches
  List<DocumentSnapshot> _allStudents = [];
  Map<String, dynamic> _chestConfig = {};
  List<String> _teams = [];
  List<String> _categories = [];
  bool _isMixedMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDataListeners();
  }

  void _initDataListeners() {
    // 1. Settings Listener
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
          _chestConfig = snap.data()?['chestConfig'] ?? {};
        });
      }
    });

    // 2. Mode Listener
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists && mounted) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });

    // 3. Students Listener
    db.collection('students').orderBy('chestNo').snapshots().listen((snap) {
      if(mounted) {
        setState(() {
          _allStudents = snap.docs;
          _isLoading = false;
        });
      }
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
            // --- TOP ACTIONS CARD ---
            _buildActionCard(),
            const SizedBox(height: 16),
            
            // --- LIST ---
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudentDialog,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("REGISTER STUDENT", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 1. ACTION CARD (Filters & Export)
  Widget _buildActionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Team Filter
            Expanded(child: _styledDropdown(
              value: _filterTeam, 
              label: "Team", 
              items: _teams, 
              onChanged: (v) => setState(() => _filterTeam = v)
            )),
            const SizedBox(width: 10),
            
            // Category Filter
            Expanded(child: _styledDropdown(
              value: _filterCategory, 
              label: "Category", 
              items: _categories, 
              onChanged: (v) => setState(() => _filterCategory = v)
            )),
            
            // Gender Filter (If Mixed)
            if (_isMixedMode) ...[
               const SizedBox(width: 10),
               Expanded(child: _styledDropdown(
                 value: _filterGender, 
                 label: "Gender", 
                 items: ["Male", "Female"], 
                 onChanged: (v) => setState(() => _filterGender = v)
               )),
            ],
            
            const SizedBox(width: 15),
            
            // Excel Export Button
            InkWell(
              onTap: _exportToExcel,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_view, color: Colors.green, size: 24),
                    SizedBox(height: 2),
                    Text("Excel", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Dropdown Builder (Handles Overflow & Styling)
  Widget _styledDropdown({
    required String? value, 
    required String label, 
    required List<String> items, 
    required Function(String?) onChanged
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true, // Prevents overflow
      menuMaxHeight: 300, // Limits menu height
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text("All $label", style: const TextStyle(color: Colors.grey, fontSize: 13))),
        ...items.map((item) => DropdownMenuItem(
          value: item,
          child: FittedBox( // Auto-shrinks text if too long
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(item),
          ),
        ))
      ],
      onChanged: onChanged,
    );
  }

  // 2. STUDENT LIST
  Widget _buildStudentList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_allStudents.isEmpty) return const Center(child: Text("No students found."));

    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        
        final filteredDocs = _allStudents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          if (_filterTeam != null && data['teamId'] != _filterTeam) return false;
          if (_filterCategory != null && data['categoryId'] != _filterCategory) return false;
          if (_filterGender != null && data['gender'] != _filterGender) return false;
          
          if (searchQuery.isNotEmpty) {
            String name = data['name'].toString().toLowerCase();
            String chest = data['chestNo'].toString();
            if (!name.contains(searchQuery) && !chest.contains(searchQuery)) return false;
          }
          
          return true;
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("No matching records."));

        return ListView.separated(
          itemCount: filteredDocs.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            return ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo,
                child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${data['teamId']} • ${data['categoryId']} ${_isMixedMode ? '• ${data['gender']}' : ''}"),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _openEditDialog(filteredDocs[index].id, data)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteStudent(filteredDocs[index].id, data['name'])),
              ]),
            );
          },
        );
      },
    );
  }

  // 3. REGISTER DIALOG
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
        setDialogState(() {
          errorMsg = "Config missing for $key. Check Settings.";
          nextChest = 0;
        });
        return;
      } else {
        setDialogState(() => errorMsg = null);
      }

      int maxVal = startVal;
      bool found = false;

      for (var doc in _allStudents) {
        var d = doc.data() as Map<String, dynamic>;
        if (d['teamId'] == selTeam && d['categoryId'] == selCat) {
          if (!_isMixedMode || d['gender'] == selGender) {
            int c = d['chestNo'] as int;
            if (c >= maxVal) {
              maxVal = c;
              found = true;
            }
          }
        }
      }

      setDialogState(() {
        nextChest = found ? maxVal + 1 : startVal;
      });
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text("Register Student"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
               Row(children: [
                 Expanded(child: _styledDropdown(value: selTeam, label: "Team", items: _teams, onChanged: (v){ setDialogState(()=>selTeam=v); calcInstantChest(setDialogState); })),
                 const SizedBox(width: 10),
                 Expanded(child: _styledDropdown(value: selCat, label: "Category", items: _categories, onChanged: (v){ setDialogState(()=>selCat=v); calcInstantChest(setDialogState); })),
               ]),
               if(_isMixedMode) ...[
                 const SizedBox(height: 10),
                 Row(children: [const Text("Gender: "), Radio(value: "Male", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("Male"), Radio(value: "Female", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); calcInstantChest(setDialogState); }), const Text("Female")]),
               ],
               const Divider(),
               
               if(errorMsg != null)
                 Padding(padding: const EdgeInsets.all(8.0), child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
               else ...[
                 Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Bulk Import"), Switch(value: isBulk, onChanged: (v)=>setDialogState(()=>isBulk=v))]),
                 if(!isBulk) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name"))
                 else TextField(controller: bulkCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "Names (New line separated)")),
                 const SizedBox(height: 10),
                 Container(padding: const EdgeInsets.all(10), color: Colors.indigo.shade50, child: Row(children: [const Text("Next Chest No: "), Text("$nextChest", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))
               ]
            ]),
          ),
        ),
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
             await batch.commit(); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registered!")));
          }, child: const Text("Register"))
        ],
      );
    }));
  }

  // 4. EDIT DIALOG (WITH CANCEL & UPDATE)
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
             TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name")),
             const SizedBox(height: 10),
             // Team & Cat
             Row(children: [
               Expanded(child: _styledDropdown(value: team, label: "Team", items: _teams, onChanged: (v) => setDialogState(() => team = v!))),
               const SizedBox(width: 10),
               Expanded(child: _styledDropdown(value: cat, label: "Category", items: _categories, onChanged: (v) => setDialogState(() => cat = v!))),
             ]),
             const SizedBox(height: 10),
             // Gender Edit (If Mixed)
             if(_isMixedMode)
               Row(children: [
                 const Text("Gender: "),
                 Radio(value: "Male", groupValue: gen, onChanged: (v) => setDialogState(() => gen = v.toString())), const Text("M"),
                 Radio(value: "Female", groupValue: gen, onChanged: (v) => setDialogState(() => gen = v.toString())), const Text("F"),
               ]),
             const SizedBox(height: 10),
             TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Chest No (Manual)")),
          ]), 
          actions: [
             // Cancel & Update Buttons
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(
               onPressed: () async {
                 await db.collection('students').doc(id).update({'name':nCtrl.text,'teamId':team,'categoryId':cat,'chestNo':int.parse(cCtrl.text),'gender':gen});
                 if(mounted) Navigator.pop(ctx);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated Successfully")));
               }, 
               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
               child: const Text("Update")
             )
          ]
        );
      }
    ));
  }

  // 5. DELETE DIALOG
  Future<void> _deleteStudent(String id, String n) async {
    if(await showDialog(context: context, builder: (c)=>AlertDialog(
      title: const Text("Delete Student?"), 
      content: Text("Are you sure you want to delete '$n'?"), 
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")),
        ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete"))
      ]
    )) ?? false) {
      await db.collection('students').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
    }
  }

  // 6. EXPORT (Specific Order)
  Future<void> _exportToExcel() async {
    if (_allStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export")));
      return;
    }
    // ORDER: Chest No, Name, Team, Category, Gender
    String csv = "Chest No,Name,Team,Category,Gender\n";
    for(var d in _allStudents) { 
      var m = d.data() as Map; 
      csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; 
    }
    
    // Cross-platform helper
    await ExportHelper.downloadCsv(csv, "students_list.csv");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Export downloaded!")));
  }
}