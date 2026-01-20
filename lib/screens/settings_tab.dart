// File: lib/screens/settings_tab.dart
// Version: 3.0
// Description: Chest Number Matrix handles Mixed Mode (Male/Female rows).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;
  final _teamNameCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();
  
  String _tempMode = 'mixed';
  bool _chestMatrixLocked = true;

  // Confirmation Helper
  Future<bool> _confirmAction(String title, String content, {bool isDelete = false}) async {
    return await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(title, style: TextStyle(color: isDelete ? Colors.red : Colors.black87)), content: Text(content),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")), ElevatedButton(onPressed: ()=>Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: isDelete?Colors.red:Colors.indigo, foregroundColor: Colors.white), child: Text(isDelete?"Delete":"Confirm"))],
    )) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSection(),
            const SizedBox(height: 24),
            _buildMasterDataSection(),
            const SizedBox(height: 24),
            _buildChestMatrix(),
            const SizedBox(height: 40),
             Center(child: TextButton.icon(onPressed: _factoryReset, icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text("FACTORY RESET", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 1. MODE SECTION
  Widget _buildModeSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        bool isLocked = data['locked'] == true;
        String currentMode = data['mode'] ?? 'mixed';

        return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Row(children: [Icon(isLocked?Icons.lock:Icons.lock_open_rounded, color: isLocked?Colors.green:Colors.indigo), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isLocked?"MODE LOCKED: ${currentMode.toUpperCase()}":"SETUP MODE", style: const TextStyle(fontWeight: FontWeight.bold)), if(!isLocked) const Text("Cannot change later.", style: TextStyle(fontSize: 10, color: Colors.grey))])]),
          if (!isLocked) ...[const Divider(), Row(children: [Radio(value: 'mixed', groupValue: _tempMode, onChanged: (v)=>setState(()=>_tempMode=v.toString())), const Text("Mixed"), const SizedBox(width: 20), Radio(value: 'boys', groupValue: _tempMode, onChanged: (v)=>setState(()=>_tempMode=v.toString())), const Text("Boys Only")]), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _lockMode, child: const Text("SAVE & LOCK")))]
          else ...[const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _factoryReset, child: const Text("Unlock (Requires Reset)", style: TextStyle(color: Colors.red, fontSize: 11))))]
        ])));
      },
    );
  }

  Future<void> _lockMode() async {
    if(await _confirmAction("Lock Mode?", "This cannot be undone.")) {
      await db.collection('config').doc('main').set({'mode': _tempMode, 'locked': true, 'setupDone': true}, SetOptions(merge: true));
      await db.collection('settings').doc('general').set({'updated': true}, SetOptions(merge: true));
    }
  }

  // 2. MASTER DATA (Simple Add, Advanced Edit)
  Widget _buildMasterDataSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = data['teams'] ?? [];
        List cats = data['categories'] ?? [];
        Map teamDetails = data['teamDetails'] ?? {}; 

        return Column(children: [
          _buildManagerCard("Teams", _teamNameCtrl, teams, (l) => _addTeam(l), (item) => _openTeamEditor(item, teamDetails[item]??{}, teams, teamDetails), (item)=>_deleteTeam(item, teams, teamDetails), isTeam: true),
          const SizedBox(height: 20),
          _buildManagerCard("Categories", _catNameCtrl, cats, (l) => _addCat(l), (item) => _editCat(item, cats), (item)=>_deleteCat(item, cats), isTeam: false),
        ]);
      },
    );
  }

  Widget _buildManagerCard(String title, TextEditingController ctrl, List list, Function(List) onAdd, Function(String) onEdit, Function(String) onDel, {required bool isTeam}) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Manage $title", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      Row(children: [Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: "New $title", isDense: true))), const SizedBox(width: 10), ElevatedButton(onPressed: () => onAdd(list), child: const Text("Add"))]),
      const SizedBox(height: 15),
      ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length, separatorBuilder: (c,i)=>const Divider(height:1), itemBuilder: (c,i) {
        return ListTile(contentPadding: EdgeInsets.zero, title: Text(list[i], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: ()=>onEdit(list[i])), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>onDel(list[i]))]));
      })
    ])));
  }

  // ... (Team Add/Edit/Delete Logic - Same as before, compacted for brevity) ...
  Future<void> _addTeam(List teams) async { if(_teamNameCtrl.text.isNotEmpty && !teams.contains(_teamNameCtrl.text.trim())) { teams.add(_teamNameCtrl.text.trim()); await db.collection('settings').doc('general').update({'teams': teams}); _teamNameCtrl.clear(); } }
  Future<void> _deleteTeam(String n, List t, Map d) async { if(await _confirmAction("Delete?", "Sure?", isDelete:true)) { t.remove(n); d.remove(n); await db.collection('settings').doc('general').update({'teams': t, 'teamDetails': d}); } }
  
  void _openTeamEditor(String name, Map currentData, List allTeams, Map allDetails) {
    // ... (Use same popup logic as previous version for Team Edit & Drag/Drop) ...
    // For brevity, assuming previous _openTeamEditor is retained or copied here.
    // Ensure you copy the _openTeamEditor function from the previous response V 1.0 code.
    // If you need it re-generated fully, let me know. I will include a placeholder here.
    _showTeamEditDialog(name, currentData, allTeams, allDetails);
  }

  Future<void> _addCat(List cats) async { if(_catNameCtrl.text.isNotEmpty && !cats.contains(_catNameCtrl.text.trim())) { cats.add(_catNameCtrl.text.trim()); await db.collection('settings').doc('general').update({'categories': cats}); _catNameCtrl.clear(); } }
  Future<void> _editCat(String old, List cats) async {
    TextEditingController c = TextEditingController(text: old);
    if(await showDialog(context: context, builder: (ctx)=>AlertDialog(title: const Text("Edit"), content: TextField(controller: c), actions: [ElevatedButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text("Save"))])) == true) {
      if(c.text.isNotEmpty) { int i = cats.indexOf(old); if(i!=-1) { cats[i]=c.text.trim(); await db.collection('settings').doc('general').update({'categories': cats}); } }
    }
  }
  Future<void> _deleteCat(String n, List c) async { if(await _confirmAction("Delete?", "Sure?", isDelete:true)) { c.remove(n); await db.collection('settings').doc('general').update({'categories': c}); } }

  // 3. CHEST NUMBER MATRIX (UPDATED FOR MIXED MODE)
  Widget _buildChestMatrix() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, configSnap) {
        bool isMixed = (configSnap.data?.exists ?? false) ? (configSnap.data!.get('mode') == 'mixed') : true;
        
        return StreamBuilder<DocumentSnapshot>(
          stream: db.collection('settings').doc('general').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
            List teams = data['teams'] ?? [];
            List cats = data['categories'] ?? [];
            Map chestConfig = data['chestConfig'] ?? {};

            if (teams.isEmpty || cats.isEmpty) return const SizedBox();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Chest Number Matrix", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(onPressed: () => setState(() => _chestMatrixLocked = !_chestMatrixLocked), icon: Icon(_chestMatrixLocked ? Icons.edit : Icons.save), label: Text(_chestMatrixLocked ? "EDIT" : "SAVE & LOCK"), style: ElevatedButton.styleFrom(backgroundColor: _chestMatrixLocked ? Colors.orange : Colors.green, foregroundColor: Colors.white))
                    ]),
                    const SizedBox(height: 5),
                    const Text("Set starting numbers. If Mixed, set for Male & Female separately.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                        columns: [
                          const DataColumn(label: Text("Category")),
                          ...teams.map((t) => DataColumn(label: Text(t.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)))),
                        ],
                        rows: _buildMatrixRows(cats, teams, chestConfig, isMixed),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  List<DataRow> _buildMatrixRows(List cats, List teams, Map config, bool isMixed) {
    List<DataRow> rows = [];
    for (var c in cats) {
      if (isMixed) {
        // Male Row
        rows.add(_buildSingleRow("$c (Male)", c, "Male", teams, config));
        // Female Row
        rows.add(_buildSingleRow("$c (Female)", c, "Female", teams, config));
      } else {
        // Single Row (Boys Only)
        rows.add(_buildSingleRow(c, c, "Male", teams, config)); // Defaulting key to Male for logic consistency
      }
    }
    return rows;
  }

  DataRow _buildSingleRow(String label, String realCat, String gender, List teams, Map config) {
    return DataRow(cells: [
      DataCell(Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      ...teams.map((t) {
        // KEY FORMAT: Team-Category-Gender
        String key = "$t-$realCat-$gender"; 
        return DataCell(
          Container(
            width: 70, padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextFormField(
              initialValue: (config[key] ?? "").toString(),
              enabled: !_chestMatrixLocked,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: "000", filled: true, fillColor: _chestMatrixLocked ? Colors.grey.shade100 : Colors.white, contentPadding: const EdgeInsets.all(8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300))),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  config[key] = int.parse(val);
                  db.collection('settings').doc('general').update({'chestConfig': config});
                }
              },
            ),
          ),
        );
      })
    ]);
  }

  // 4. FACTORY RESET
  Future<void> _factoryReset() async {
    if (await _confirmAction("FACTORY RESET?", "WARNING: Deletes ALL DATA.", isDelete: true)) {
      var batch = db.batch();
      batch.delete(db.collection('config').doc('main'));
      batch.delete(db.collection('settings').doc('general'));
      // Delete collections manually
      var sSnap = await db.collection('students').get(); for (var d in sSnap.docs) batch.delete(d.reference);
      var eSnap = await db.collection('events').get(); for (var d in eSnap.docs) batch.delete(d.reference);
      var rSnap = await db.collection('results').get(); for (var d in rSnap.docs) batch.delete(d.reference);
      var regSnap = await db.collection('registrations').get(); for (var d in regSnap.docs) batch.delete(d.reference);
      await batch.commit();
      setState(() => _tempMode = 'mixed');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset Complete.")));
    }
  }

  // Copy of previous dialog for Team Edit
  void _showTeamEditDialog(String name, Map currentData, List allTeams, Map allDetails) {
     TextEditingController editNameCtrl = TextEditingController(text: name);
     TextEditingController editPassCtrl = TextEditingController(text: currentData['passcode'] ?? '');
     TextEditingController roleCtrl = TextEditingController();
     TextEditingController personNameCtrl = TextEditingController();
     Color selectedColor = Color(currentData['color'] ?? 0xFF2196F3);
     List<dynamic> leaders = List.from(currentData['leaders'] ?? []);
     final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.brown, Colors.black];

     showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(title: Text("Edit Team: $name"), content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
             TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: "Team Name")), const SizedBox(height: 10),
             TextField(controller: editPassCtrl, decoration: const InputDecoration(labelText: "Passcode")), const SizedBox(height: 10),
             Wrap(spacing: 5, children: colors.map((c) => InkWell(onTap: () => setDialogState(() => selectedColor = c), child: CircleAvatar(backgroundColor: c, radius: 12, child: selectedColor.value == c.value ? const Icon(Icons.check, size: 12, color: Colors.white) : null))).toList()),
             const Divider(), const Text("Leaders", style: TextStyle(fontWeight: FontWeight.bold)),
             Container(height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)), child: ReorderableListView(padding: const EdgeInsets.all(8), children: [for(int i=0;i<leaders.length;i++) ListTile(key: ValueKey(leaders[i]), dense: true, title: Text(leaders[i]['role']), subtitle: Text(leaders[i]['name']), trailing: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: ()=>setDialogState(()=>leaders.removeAt(i))))], onReorder: (o,n){ setDialogState((){ if(n>o)n-=1; final i=leaders.removeAt(o); leaders.insert(n,i); }); })),
             Row(children: [Expanded(child: TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Pos"))), const SizedBox(width: 5), Expanded(child: TextField(controller: personNameCtrl, decoration: const InputDecoration(labelText: "Name"))), IconButton(icon: const Icon(Icons.add), onPressed: (){ if(roleCtrl.text.isNotEmpty){ setDialogState(()=>leaders.add({'role': roleCtrl.text, 'name': personNameCtrl.text})); roleCtrl.clear(); personNameCtrl.clear(); } })])
          ]))), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () async {
             String newName = editNameCtrl.text.trim();
             if(newName!=name) { int idx=allTeams.indexOf(name); if(idx!=-1) allTeams[idx]=newName; allDetails.remove(name); }
             allDetails[newName] = {'color': selectedColor.value, 'passcode': editPassCtrl.text, 'leaders': leaders};
             await db.collection('settings').doc('general').update({'teams': allTeams, 'teamDetails': allDetails});
             if(mounted) Navigator.pop(ctx);
          }, child: const Text("Save"))]);
     }));
  }
}