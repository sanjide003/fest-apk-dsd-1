import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;

  // Controllers
  final _teamNameCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();
  
  // Website Config Controllers
  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _socialIgCtrl = TextEditingController();
  final _socialYtCtrl = TextEditingController();

  // State Variables
  String _tempMode = 'mixed';
  bool _chestMatrixLocked = true; // ചെസ്റ്റ് നമ്പർ ലോക്കിംഗ്

  @override
  void initState() {
    super.initState();
    _loadWebConfig();
  }

  void _loadWebConfig() {
    db.collection('settings').doc('home_config').get().then((doc) {
      if(doc.exists) {
        var d = doc.data()!;
        setState(() {
          _festNameCtrl.text = d['festName1'] ?? '';
          _taglineCtrl.text = d['tagline'] ?? '';
          _logoUrlCtrl.text = d['logoUrl'] ?? '';
          if(d['social'] != null) {
            _socialIgCtrl.text = d['social']['ig'] ?? '';
            _socialYtCtrl.text = d['social']['yt'] ?? '';
          }
        });
      }
    });
  }

  // --- CONFIRMATION DIALOG HELPER ---
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
            // 1. FEST MODE SETUP
            _buildModeSection(),
            const SizedBox(height: 24),

            // 2. MASTER DATA (Teams & Categories)
            _buildMasterDataSection(),
            const SizedBox(height: 24),

            // 3. CHEST NUMBER MATRIX
            _buildChestMatrix(),
            const SizedBox(height: 24),

            // 4. WEBSITE CONFIGURATION
            _buildWebConfigSection(),
            const SizedBox(height: 40),

            // 5. FACTORY RESET
             Center(
              child: TextButton.icon(
                onPressed: _factoryReset,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("FACTORY RESET (Clear All Data)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // 1. MODE CONFIGURATION
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
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _lockMode() async {
    if(await _confirmAction("Lock Mode?", "Once locked, you can only change this by resetting all data.")) {
      await db.collection('config').doc('main').set({'mode': _tempMode, 'locked': true, 'setupDone': true}, SetOptions(merge: true));
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
        
        // Detailed Team Info (Color, Leaders, Passcode)
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
                    // Simple Add
                    Row(children: [
                      Expanded(child: TextField(controller: _teamNameCtrl, decoration: const InputDecoration(hintText: "Team Name", isDense: true))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () => _addTeam(teams), child: const Text("Add"))
                    ]),
                    const SizedBox(height: 15),
                    // List with Edit Option
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
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openTeamEditor(tName, tData, teams, teamDetails),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTeam(tName, teams, teamDetails),
                              ),
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
                    Row(children: [
                      Expanded(child: TextField(controller: _catNameCtrl, decoration: const InputDecoration(hintText: "Category Name", isDense: true))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () => _addCat(cats), child: const Text("Add"))
                    ]),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      children: cats.map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => _deleteCat(c, cats),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      )).toList(),
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

  // --- TEAM FUNCTIONS ---
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

  // --- TEAM FULL EDITOR (Dialog) ---
  void _openTeamEditor(String name, Map currentData, List allTeams, Map allDetails) {
    // Controllers for Dialog
    TextEditingController editNameCtrl = TextEditingController(text: name);
    TextEditingController editPassCtrl = TextEditingController(text: currentData['passcode'] ?? '');
    TextEditingController roleCtrl = TextEditingController();
    TextEditingController personNameCtrl = TextEditingController();
    
    Color selectedColor = Color(currentData['color'] ?? 0xFF2196F3);
    List<dynamic> leaders = List.from(currentData['leaders'] ?? []); // Clone list
    
    // Colors List
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
                    // 1. Basic Info
                    TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: "Team Name")),
                    const SizedBox(height: 10),
                    TextField(controller: editPassCtrl, decoration: const InputDecoration(labelText: "Passcode")),
                    const SizedBox(height: 10),
                    const Text("Team Color:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      children: colors.map((c) => InkWell(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: CircleAvatar(backgroundColor: c, radius: 12, child: selectedColor.value == c.value ? const Icon(Icons.check, size: 12, color: Colors.white) : null),
                      )).toList(),
                    ),
                    const Divider(height: 30),
                    
                    // 2. Leaders & Positions (Drag & Drop)
                    const Text("Positions / Leaders (Order Matters)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 5),
                    const Text("Drag to reorder positions for website display.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    Container(
                      height: 150, // Limited height for list
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ReorderableListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (int i = 0; i < leaders.length; i++)
                            ListTile(
                              key: ValueKey(leaders[i]), // Unique key needed
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
                        Expanded(child: TextField(controller: personNameCtrl, decoration: const InputDecoration(labelText: "Student Name", isDense: true))),
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
                    
                    // Update Lists
                    if(newName != name) {
                      int idx = allTeams.indexOf(name);
                      if(idx != -1) allTeams[idx] = newName;
                      allDetails.remove(name); // Remove old key
                    }
                    
                    // Save new data
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

  // --- CAT FUNCTIONS ---
  Future<void> _addCat(List cats) async {
    if (_catNameCtrl.text.isEmpty) return;
    String name = _catNameCtrl.text.trim();
    if(!cats.contains(name)) {
      cats.add(name);
      await db.collection('settings').doc('general').set({'categories': cats}, SetOptions(merge: true));
      _catNameCtrl.clear();
    }
  }

  Future<void> _deleteCat(String name, List cats) async {
    if(await _confirmAction("Delete Category?", "Deleting '$name' is permanent.", isDelete: true)) {
      cats.remove(name);
      await db.collection('settings').doc('general').update({'categories': cats});
    }
  }


  // ==============================================================================
  // 3. CHEST MATRIX (LOCK & EDIT)
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
                    // TOGGLE BUTTON
                    ElevatedButton.icon(
                      onPressed: () {
                         if(!_chestMatrixLocked) {
                           // Saving logic if needed
                         }
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
                                enabled: !_chestMatrixLocked, // Locked Check
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
  // 4. WEB CONFIG
  // ==============================================================================
  Widget _buildWebConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Website Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name")),
            const SizedBox(height: 10),
            TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
            const SizedBox(height: 10),
            TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL")),
            const SizedBox(height: 10),
            TextField(controller: _socialIgCtrl, decoration: const InputDecoration(labelText: "Instagram Link")),
            const SizedBox(height: 10),
            TextField(controller: _socialYtCtrl, decoration: const InputDecoration(labelText: "YouTube Link")),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if(await _confirmAction("Update Website?", "This will update the public home page.")) {
                    await db.collection('settings').doc('home_config').set({
                      'festName1': _festNameCtrl.text,
                      'tagline': _taglineCtrl.text,
                      'logoUrl': _logoUrlCtrl.text,
                      'social': { 'ig': _socialIgCtrl.text, 'yt': _socialYtCtrl.text },
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Website Updated!")));
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text("UPDATE WEBSITE SETTINGS"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // 5. FACTORY RESET
  // ==============================================================================
  Future<void> _factoryReset() async {
    if (await _confirmAction("FACTORY RESET?", "WARNING: This will delete ALL Data (Students, Events, Results). Cannot be undone.", isDelete: true)) {
      var batch = db.batch();
      batch.delete(db.collection('config').doc('main'));
      batch.delete(db.collection('settings').doc('general'));
      // Delete collections manually in real logic, here simplified
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
