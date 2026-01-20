// File: lib/screens/students_tab.dart
// Version: 3.0
// Description: Strict Add Logic (Checks Settings), Header Search Integration, Excel Export Only.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html; // For Web Export
import 'dart:convert';
import '../layout/responsive_layout.dart'; // To access globalSearchQuery

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
  String? _filterGender; // For Mixed Mode
  
  // Data
  List<String> _teams = [];
  List<String> _categories = [];
  bool _isMixedMode = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  void _fetchSettings() {
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
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
            // --- FILTERS & EXPORT ---
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

  Widget _buildActionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: DropdownButtonFormField<String>(value: _filterTeam, decoration: const InputDecoration(labelText: "Team", isDense: true, contentPadding: EdgeInsets.all(10)), items: [const DropdownMenuItem(value: null, child: Text("All Teams")), ..._teams.map((t) => DropdownMenuItem(value: t, child: Text(t)))], onChanged: (v) => setState(() => _filterTeam = v))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(value: _filterCategory, decoration: const InputDecoration(labelText: "Category", isDense: true, contentPadding: EdgeInsets.all(10)), items: [const DropdownMenuItem(value: null, child: Text("All Categories")), ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))], onChanged: (v) => setState(() => _filterCategory = v))),
            const SizedBox(width: 10),
            if (_isMixedMode) ...[
               Expanded(child: DropdownButtonFormField<String>(value: _filterGender, decoration: const InputDecoration(labelText: "Gender", isDense: true, contentPadding: EdgeInsets.all(10)), items: const [DropdownMenuItem(value: null, child: Text("All")), DropdownMenuItem(value: "Male", child: Text("Male")), DropdownMenuItem(value: "Female", child: Text("Female"))], onChanged: (v) => setState(() => _filterGender = v))),
               const SizedBox(width: 10),
            ],
            IconButton(onPressed: _exportToExcel, icon: const Icon(Icons.download, color: Colors.green), tooltip: "Export Excel"),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    // Listen to Global Search
    return ValueListenableBuilder<String>(
      valueListenable: globalSearchQuery,
      builder: (context, searchQuery, _) {
        
        Query query = db.collection('students').orderBy('chestNo');
        if (_filterTeam != null) query = query.where('teamId', isEqualTo: _filterTeam);
        if (_filterCategory != null) query = query.where('categoryId', isEqualTo: _filterCategory);
        if (_filterGender != null) query = query.where('gender', isEqualTo: _filterGender);

        return StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Center(child: Text("No students found."));

            // Client side filter for Search
            var docs = snap.data!.docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              String name = data['name'].toString().toLowerCase();
              String chest = data['chestNo'].toString();
              return searchQuery.isEmpty || name.contains(searchQuery) || chest.contains(searchQuery);
            }).toList();

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                return ListTile(
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo,
                    child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['teamId']} • ${data['categoryId']} ${_isMixedMode ? '• ${data['gender']}' : ''}"),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _openEditDialog(docs[index].id, data)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteStudent(docs[index].id, data['name'])),
                  ]),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- ADD STUDENT (STRICT LOGIC) ---
  void _openAddStudentDialog() {
    String? selTeam;
    String? selCat;
    String selGender = 'Male';
    bool isBulk = false;
    final nameCtrl = TextEditingController();
    final bulkCtrl = TextEditingController();
    int nextChest = 0;
    bool loadingChest = false;
    String? errorMsg;

    Future<void> checkConfigAndCalc(StateSetter setState) async {
      if (selTeam == null || selCat == null) return;
      setState(() { loadingChest = true; errorMsg = null; });

      // 1. Check Settings
      var settingsSnap = await db.collection('settings').doc('general').get();
      Map chestConfig = settingsSnap.data()?['chestConfig'] ?? {};
      String key = _isMixedMode ? "$selTeam-$selCat-$selGender" : "$selTeam-$selCat-Male"; // Key Format must match Settings
      
      int? startVal = chestConfig[key];

      if (startVal == null) {
        setState(() { 
          loadingChest = false; 
          errorMsg = "Chest Number not configured for $selTeam - $selCat ($selGender). Go to Settings."; 
          nextChest = 0;
        });
        return;
      }

      // 2. Calc Next Number
      var q = db.collection('students').where('teamId', isEqualTo: selTeam).where('categoryId', isEqualTo: selCat);
      if(_isMixedMode) q = q.where('gender', isEqualTo: selGender);
      
      var sSnap = await q.orderBy('chestNo', descending: true).limit(1).get();
      if (sSnap.docs.isNotEmpty) {
        nextChest = (sSnap.docs.first['chestNo'] as int) + 1;
      } else {
        nextChest = startVal;
      }
      setState(() => loadingChest = false);
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        title: const Text("Register Student"),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
               Row(children: [
                 Expanded(child: DropdownButtonFormField(value: selTeam, hint: const Text("Team"), items: _teams.map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v){ setDialogState(()=>selTeam=v.toString()); checkConfigAndCalc(setDialogState); })),
                 const SizedBox(width: 10),
                 Expanded(child: DropdownButtonFormField(value: selCat, hint: const Text("Category"), items: _categories.map((e)=>DropdownMenuItem(value:e, child:Text(e))).toList(), onChanged: (v){ setDialogState(()=>selCat=v.toString()); checkConfigAndCalc(setDialogState); })),
               ]),
               if(_isMixedMode) ...[
                 const SizedBox(height: 10),
                 Row(children: [const Text("Gender: "), Radio(value: "Male", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); checkConfigAndCalc(setDialogState); }), const Text("Male"), Radio(value: "Female", groupValue: selGender, onChanged: (v){ setDialogState(()=>selGender=v.toString()); checkConfigAndCalc(setDialogState); }), const Text("Female")]),
               ],
               const Divider(),
               
               // Error or Success
               if(errorMsg != null)
                 Padding(padding: const EdgeInsets.all(8.0), child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
               else ...[
                 Row(mainAxisAlignment: MainAxisAlignment.end, children: [const Text("Bulk Import"), Switch(value: isBulk, onChanged: (v)=>setDialogState(()=>isBulk=v))]),
                 if(!isBulk) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name"))
                 else TextField(controller: bulkCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "Names (New line separated)")),
                 const SizedBox(height: 10),
                 Container(padding: const EdgeInsets.all(10), color: Colors.indigo.shade50, child: Row(children: [const Text("Next Chest No: "), loadingChest ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)) : Text("$nextChest", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))
               ]
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: (errorMsg != null || nextChest == 0) ? null : () async {
             // Save Logic
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

  // --- EDIT & DELETE (Manual Chest No Allowed) ---
  void _openEditDialog(String id, Map d) {
    final nCtrl = TextEditingController(text: d['name']);
    final cCtrl = TextEditingController(text: d['chestNo'].toString());
    String team = d['teamId']; String cat = d['categoryId']; String gen = d['gender']??'Male';
    
    showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text("Edit"), content: Column(mainAxisSize: MainAxisSize.min, children: [
       TextField(controller: nCtrl, decoration: const InputDecoration(labelText: "Name")),
       DropdownButtonFormField(value: team, items: _teams.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>team=v.toString()),
       DropdownButtonFormField(value: cat, items: _categories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged: (v)=>cat=v.toString()),
       TextField(controller: cCtrl, decoration: const InputDecoration(labelText: "Chest No (Manual)")),
    ]), actions: [
       ElevatedButton(onPressed: () async {
         await db.collection('students').doc(id).update({'name':nCtrl.text,'teamId':team,'categoryId':cat,'chestNo':int.parse(cCtrl.text),'gender':gen});
         if(mounted) Navigator.pop(ctx);
       }, child: const Text("Update"))
    ]));
  }

  Future<void> _deleteStudent(String id, String n) async {
    if(await showDialog(context: context, builder: (c)=>AlertDialog(title: const Text("Delete?"), content: Text(n), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(c,true), child: const Text("Yes"))])) ?? false) {
      await db.collection('students').doc(id).delete();
    }
  }

  Future<void> _exportToExcel() async {
    var s = await db.collection('students').orderBy('chestNo').get();
    String csv = "ChestNo,Name,Team,Category,Gender\n";
    for(var d in s.docs) { var m=d.data(); csv+="${m['chestNo']},${m['name']},${m['teamId']},${m['categoryId']},${m['gender']}\n"; }
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..setAttribute("download", "students.csv")..click();
    html.Url.revokeObjectUrl(url);
  }
}