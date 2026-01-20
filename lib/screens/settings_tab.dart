// File: lib/screens/settings_tab.dart
// Version: 1.0
// Description: ടീം മാനേജ്‌മെന്റ്, കാറ്റഗറി, ചെസ്റ്റ് നമ്പർ മാട്രിക്സ്, ഫാക്ടറി റീസെറ്റ് എന്നിവ നിയന്ത്രിക്കുന്ന പേജ്.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;

  // കൺട്രോളറുകൾ
  final _teamNameCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();

  // സ്റ്റേറ്റ് വേരിയബിളുകൾ
  String _tempMode = 'mixed';
  bool _chestMatrixLocked = true; // ചെസ്റ്റ് നമ്പർ എഡിറ്റിംഗ് ലോക്ക് ചെയ്യാൻ

  // --- സഹായ ഫംഗ്ഷൻ: കൺഫർമേഷൻ ഡയലോഗ് ---
  // എഡിറ്റ്/ഡിലീറ്റ് ചെയ്യുന്നതിന് മുൻപ് ഉറപ്പാക്കാൻ ചോദിക്കുന്നു
  Future<bool> _confirmAction(String title, String content, {bool isDelete = false}) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDelete ? Colors.red : Colors.black87)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDelete ? Colors.red : Colors.indigo, foregroundColor: Colors.white),
            child: Text(isDelete ? "Delete" : "Confirm"),
          )
        ],
      )
    ) ?? false;
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
            // 1. FEST MODE SETUP (LOCKING SYSTEM)
            _buildModeSection(),
            const SizedBox(height: 24),

            // 2. MASTER DATA (Teams & Categories)
            _buildMasterDataSection(),
            const SizedBox(height: 24),

            // 3. CHEST NUMBER MATRIX
            _buildChestMatrix(),
            const SizedBox(height: 40),

            // 4. FACTORY RESET (DANGER ZONE)
             Center(
              child: TextButton.icon(
                onPressed: _factoryReset,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("FACTORY RESET (Clear All Data)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), backgroundColor: Colors.red.shade50),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // 1. MODE CONFIGURATION (LOCKING SYSTEM)
  // ==============================================================================
  Widget _buildModeSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        bool isLocked = data['locked'] == true;
        String currentMode = data['mode'] ?? 'mixed';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(isLocked ? Icons.lock : Icons.lock_open_rounded, color: isLocked ? Colors.green : Colors.indigo),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isLocked ? "MODE LOCKED: ${currentMode.toUpperCase()}" : "SETUP MODE", style: const TextStyle(fontWeight: FontWeight.bold)),
                        if(!isLocked) const Text("Select carefully. Cannot change later.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                if (!isLocked) ...[
                  const Divider(),
                  Row(children: [
                    Radio(value: 'mixed', groupValue: _tempMode, onChanged: (v)=>setState(()=>_tempMode=v.toString())), const Text("Mixed"),
                    const SizedBox(width: 20),
                    Radio(value: 'boys', groupValue: _tempMode, onChanged: (v)=>setState(()=>_tempMode=v.toString())), const Text("Boys Only"),
                  ]),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _lockMode, child: const Text("SAVE & LOCK")))
                ] else ...[
                   // ലോക്ക് ആയതിന് ശേഷം കാണിക്കുന്ന അൺലോക്ക് ബട്ടൺ
                   const SizedBox(height: 10),
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(
                       onPressed: _factoryReset, // അൺലോക്ക് ചെയ്യാൻ റീസെറ്റ് ചെയ്യണം
                       child: const Text("Unlock (Requires Reset)", style: TextStyle(color: Colors.red, fontSize: 11)),
                     ),
                   )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  // മോഡ് ലോക്ക് ചെയ്യുന്ന ഫംഗ്ഷൻ
  Future<void> _lockMode() async {
    if(await _confirmAction("Lock Mode?", "Once locked, you can only change this by resetting all data.")) {
      await db.collection('config').doc('main').set({'mode': _tempMode, 'locked': true, 'setupDone': true}, SetOptions(merge: true));
      // സെറ്റിംഗ്സ് ഡോക്യുമെന്റ് ഇല്ലെങ്കിൽ ഉണ്ടാക്കുന്നു
      await db.collection('settings').doc('general').set({'updated': true}, SetOptions(merge: true));
    }
  }

  // ==============================================================================
  // 2. TEAMS & CATEGORIES MANAGEMENT
  // ==============================================================================
  Widget _buildMasterDataSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        
        List teams = data['teams'] ?? [];
        List cats = data['categories'] ?? [];
        Map teamDetails = data['teamDetails'] ?? {}; 

        return Column(
          children: [
            // --- TEAMS MANAGER ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Manage Teams", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    // Add Team (Simple Name Only)
                    Row(children: [
                      Expanded(child: TextField(controller: _teamNameCtrl, decoration: const InputDecoration(hintText: "Team Name", isDense: true))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () => _addTeam(teams), child: const Text("Add"))
                    ]),
                    const SizedBox(height: 15),
                    // Team List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teams.length,
                      separatorBuilder: (c,i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        String tName = teams[i];
                        Map tData = teamDetails[tName] ?? {};
                        int colorVal = tData['color'] ?? 0xFF2196F3;
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundColor: Color(colorVal), radius: 10),
                          title: Text(tName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(tData['passcode'] != null ? "Pass: ${tData['passcode']}" : "No Passcode"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openTeamEditor(tName, tData, teams, teamDetails)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTeam(tName, teams, teamDetails)),
                            ],
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- CATEGORIES MANAGER ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Manage Categories", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    // Add Category
                    Row(children: [
                      Expanded(child: TextField(controller: _catNameCtrl, decoration: const InputDecoration(hintText: "Category Name", isDense: true))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () => _addCat(cats), child: const Text("Add"))
                    ]),
                    const SizedBox(height: 15),
                    // Category List with Edit/Delete
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cats.length,
                      separatorBuilder: (c,i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        return Container(
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            dense: true,
                            title: Text(cats[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _editCat(cats[i], cats)),
                                IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deleteCat(cats[i], cats)),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- ടീം ഫംഗ്ഷനുകൾ ---
  Future<void> _addTeam(List teams) async {
    if (_teamNameCtrl.text.isEmpty) return;
    String name = _teamNameCtrl.text.trim();
    if(!teams.contains(name)) {
      teams.add(name);
      await db.collection('settings').doc('general').set({'teams': teams}, SetOptions(merge: true));
      _teamNameCtrl.clear();
    }
  }

  Future<void> _deleteTeam(String name, List teams, Map details) async {
    if(await _confirmAction("Delete Team?", "Deleting '$name' might affect students registered under this team.", isDelete: true)) {
      teams.remove(name);
      details.remove(name);
      await db.collection('settings').doc('general').update({'teams': teams, 'teamDetails': details});
    }
  }

  // --- ടീം എഡിറ്റർ (POP-UP DIALOG) ---
  void _openTeamEditor(String name, Map currentData, List allTeams, Map allDetails) {
    TextEditingController editNameCtrl = TextEditingController(text: name);
    TextEditingController editPassCtrl = TextEditingController(text: currentData['passcode'] ?? '');
    
    // ലീഡേഴ്സിനെ ചേർക്കാനുള്ള കൺട്രോളറുകൾ
    TextEditingController roleCtrl = TextEditingController();
    TextEditingController personNameCtrl = TextEditingController();
    
    Color selectedColor = Color(currentData['color'] ?? 0xFF2196F3);
    List<dynamic> leaders = List.from(currentData['leaders'] ?? []);
    
    final List<Color> colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.brown, Colors.black];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Edit Team: $name"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. അടിസ്ഥാന വിവരങ്ങൾ
                    TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: "Team Name")),
                    const SizedBox(height: 10),
                    TextField(controller: editPassCtrl, decoration: const InputDecoration(labelText: "Passcode")),
                    const SizedBox(height: 10),
                    const Text("Team Color:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 5,
                      children: colors.map((c) => InkWell(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: CircleAvatar(backgroundColor: c, radius: 12, child: selectedColor.value == c.value ? const Icon(Icons.check, size: 12, color: Colors.white) : null),
                      )).toList(),
                    ),
                    const Divider(height: 30),
                    
                    // 2. ലീഡേഴ്സ് (Drag & Drop)
                    const Text("Leaders & Positions (Drag to Reorder)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 10),
                    
                    Container(
                      height: 200, 
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ReorderableListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (int i = 0; i < leaders.length; i++)
                            ListTile(
                              key: ValueKey(leaders[i]), // യുണീക് കീ നിർബന്ധമാണ്
                              tileColor: Colors.grey.shade50,
                              dense: true,
                              leading: const Icon(Icons.drag_handle, color: Colors.grey),
                              title: Text(leaders[i]['role'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(leaders[i]['name']),
                              trailing: IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: (){
                                setDialogState(() => leaders.removeAt(i));
                              }),
                            )
                        ],
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = leaders.removeAt(oldIndex);
                            leaders.insert(newIndex, item);
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Position (e.g. Captain)", isDense: true))),
                        const SizedBox(width: 5),
                        Expanded(child: TextField(controller: personNameCtrl, decoration: const InputDecoration(labelText: "Name", isDense: true))),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () {
                            if(roleCtrl.text.isNotEmpty && personNameCtrl.text.isNotEmpty) {
                              setDialogState(() {
                                leaders.add({'role': roleCtrl.text, 'name': personNameCtrl.text});
                              });
                              roleCtrl.clear();
                              personNameCtrl.clear();
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if(await _confirmAction("Update Team?", "Save all changes?")) {
                    String newName = editNameCtrl.text.trim();
                    
                    if(newName != name) {
                      int idx = allTeams.indexOf(name);
                      if(idx != -1) allTeams[idx] = newName;
                      allDetails.remove(name);
                    }
                    
                    allDetails[newName] = {
                      'color': selectedColor.value,
                      'passcode': editPassCtrl.text,
                      'leaders': leaders
                    };

                    await db.collection('settings').doc('general').update({
                      'teams': allTeams,
                      'teamDetails': allDetails
                    });
                    
                    if(mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("Save Changes"),
              )
            ],
          );
        },
      ),
    );
  }

  // --- കാറ്റഗറി ഫംഗ്ഷനുകൾ ---
  Future<void> _addCat(List cats) async {
    if (_catNameCtrl.text.isEmpty) return;
    String name = _catNameCtrl.text.trim();
    if(!cats.contains(name)) {
      cats.add(name);
      await db.collection('settings').doc('general').update({'categories': cats});
      _catNameCtrl.clear();
    }
  }

  Future<void> _editCat(String oldName, List cats) async {
    TextEditingController editCtrl = TextEditingController(text: oldName);
    bool? save = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Edit Category"),
      content: TextField(controller: editCtrl),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c, false), child: const Text("Cancel")),
        ElevatedButton(onPressed: ()=>Navigator.pop(c, true), child: const Text("Save"))
      ],
    ));

    if(save == true && editCtrl.text.isNotEmpty) {
      int idx = cats.indexOf(oldName);
      if(idx != -1) {
        cats[idx] = editCtrl.text.trim();
        await db.collection('settings').doc('general').update({'categories': cats});
      }
    }
  }

  Future<void> _deleteCat(String name, List cats) async {
    if(await _confirmAction("Delete Category?", "Deleting '$name' is permanent.", isDelete: true)) {
      cats.remove(name);
      await db.collection('settings').doc('general').update({'categories': cats});
    }
  }


  // ==============================================================================
  // 3. CHEST NUMBER MATRIX (LOCK & EDIT)
  // ==============================================================================
  Widget _buildChestMatrix() {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Chest Number Matrix", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    // ലോക്ക്/എഡിറ്റ് ബട്ടൺ
                    ElevatedButton.icon(
                      onPressed: () {
                         setState(() => _chestMatrixLocked = !_chestMatrixLocked);
                      },
                      icon: Icon(_chestMatrixLocked ? Icons.edit : Icons.save),
                      label: Text(_chestMatrixLocked ? "EDIT" : "SAVE & LOCK"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _chestMatrixLocked ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                    columns: [
                      const DataColumn(label: Text("Category")),
                      ...teams.map((t) => DataColumn(label: Text(t.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)))),
                    ],
                    rows: cats.map((c) {
                      return DataRow(cells: [
                        DataCell(Text(c.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ...teams.map((t) {
                          String key = "$t-$c";
                          return DataCell(
                            Container(
                              width: 70,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TextFormField(
                                initialValue: (chestConfig[key] ?? "").toString(),
                                enabled: !_chestMatrixLocked, // ലോക്ക് ചെയ്തിട്ടുണ്ടെങ്കിൽ ടൈപ്പ് ചെയ്യാൻ പറ്റില്ല
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: "000",
                                  filled: true,
                                  fillColor: _chestMatrixLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.all(8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                ),
                                onChanged: (val) {
                                  if (val.isNotEmpty) {
                                    chestConfig[key] = int.parse(val);
                                    db.collection('settings').doc('general').update({'chestConfig': chestConfig});
                                  }
                                },
                              ),
                            ),
                          );
                        })
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================================================================
  // 4. FACTORY RESET
  // ==============================================================================
  Future<void> _factoryReset() async {
    if (await _confirmAction("FACTORY RESET?", "WARNING: This will delete ALL Data (Students, Events, Results). Cannot be undone.", isDelete: true)) {
      var batch = db.batch();
      // കോൺഫിഗറേഷനുകൾ ഡിലീറ്റ് ചെയ്യുന്നു
      batch.delete(db.collection('config').doc('main'));
      batch.delete(db.collection('settings').doc('general'));
      batch.delete(db.collection('settings').doc('home_config'));
      
      // കളക്ഷനുകൾ ഡിലീറ്റ് ചെയ്യുന്നു (ലളിതമായ രീതി)
      var sSnap = await db.collection('students').get();
      for (var d in sSnap.docs) batch.delete(d.reference);
      var eSnap = await db.collection('events').get();
      for (var d in eSnap.docs) batch.delete(d.reference);
      var rSnap = await db.collection('results').get();
      for (var d in rSnap.docs) batch.delete(d.reference);
      var regSnap = await db.collection('registrations').get();
      for (var d in regSnap.docs) batch.delete(d.reference);

      await batch.commit();
      setState(() => _tempMode = 'mixed');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Reset Complete.")));
    }
  }
}
