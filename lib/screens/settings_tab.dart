// File: lib/screens/settings_tab.dart
// Version: 7.0
// Description: Added 3-Dot Menus for all items, Detailed Unlock Warning, and Confirmations.

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
  final _catNameCtrl = TextEditingController();

  // State
  String _selectedMode = 'mixed';
  bool _isLoading = false;
  bool _isMatrixEditing = false; 

  // Colors Palette
  final List<Color> _colors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.brown, 
    Colors.indigo, Colors.cyan, Colors.lime, Colors.amber
  ];

  // Helper: Simple Confirmation
  Future<bool> _confirm(String title, String msg, {bool isDestructive = false}) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? Colors.red : Colors.indigo, foregroundColor: Colors.white),
            child: Text(isDestructive ? "Confirm Delete" : "Yes, Proceed")
          )
        ],
      )
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModeConfigSection(),
                const SizedBox(height: 24),
                _buildTeamsSection(),
                const SizedBox(height: 24),
                _buildCategoriesSection(),
                const SizedBox(height: 24),
                _buildChestMatrixSection(),
                const SizedBox(height: 24),
                _buildTeamLeadersSection(),
                const SizedBox(height: 40),
                _buildDangerZone(),
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  // ================= 1. MODE CONFIGURATION (DETAILED WARNING) =================
  Widget _buildModeConfigSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        bool isLocked = data['locked'] == true;
        String mode = data['mode'] ?? 'mixed';
        
        if (isLocked && _selectedMode != mode) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if(mounted) setState(() => _selectedMode = mode);
           });
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                    child: Row(children: [
                      const Icon(Icons.lock, color: Colors.green), 
                      const SizedBox(width: 10), 
                      Expanded(child: Text("Mode Locked: ${mode.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))), 
                      OutlinedButton(onPressed: _unlockWithDetailedWarning, child: const Text("Unlock"))
                    ]),
                  )
                else
                  Column(
                    children: [
                      const Text("Select Competition Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _modeOption('mixed', "Mixed (Boys & Girls)", Icons.wc)),
                          const SizedBox(width: 10),
                          Expanded(child: _modeOption('boys', "Single Gender", Icons.male)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(onPressed: _lockConfig, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)), child: const Text("SAVE & LOCK MODE"))
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modeOption(String val, String label, IconData icon) {
    bool isSel = _selectedMode == val;
    return InkWell(
      onTap: () => setState(() => _selectedMode = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSel ? Colors.indigo.shade50 : Colors.white, border: Border.all(color: isSel ? Colors.indigo : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [Icon(icon, color: isSel ? Colors.indigo : Colors.grey), const SizedBox(height: 5), Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? Colors.indigo : Colors.black87))]),
      ),
    );
  }

  Future<void> _lockConfig() async {
    if (await _confirm("Lock Configuration?", "This will define the structure of your fest. You can unlock it later, but it will require a reset.")) {
      await db.collection('config').doc('main').set({'mode': _selectedMode, 'locked': true});
    }
  }

  // DETAILED WARNING DIALOG
  Future<void> _unlockWithDetailedWarning() async {
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Unlock & Reset?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Unlocking will perform a FACTORY RESET to prevent data corruption. The following data will be PERMANENTLY DELETED:", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("• All Registered Students", style: TextStyle(color: Colors.red)),
            Text("• All Events & Points", style: TextStyle(color: Colors.red)),
            Text("• All Registrations", style: TextStyle(color: Colors.red)),
            Text("• All Published Results", style: TextStyle(color: Colors.red)),
            SizedBox(height: 10),
            Text("Are you absolutely sure?", style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Yes, Reset Everything"))
        ],
      )
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      var batch = db.batch();
      
      var sSnap = await db.collection('students').get(); for (var d in sSnap.docs) batch.delete(d.reference);
      var eSnap = await db.collection('events').get(); for (var d in eSnap.docs) batch.delete(d.reference);
      var rSnap = await db.collection('registrations').get(); for (var d in rSnap.docs) batch.delete(d.reference);
      var resSnap = await db.collection('results').get(); for (var d in resSnap.docs) batch.delete(d.reference);
      
      batch.set(db.collection('config').doc('main'), {'locked': false, 'mode': 'mixed'});
      await batch.commit();
      setState(() { _isLoading = false; _selectedMode = 'mixed'; });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Reset Successfully")));
    }
  }

  // ================= 2. TEAMS MANAGEMENT (3-DOT MENU) =================
  Widget _buildTeamsSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = List.from(data['teams'] ?? []);
        Map details = data['teamDetails'] ?? {};

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Row(children: [Icon(Icons.shield, color: Colors.blue), SizedBox(width: 8), Text("Teams", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                  IconButton.filled(onPressed: () => _showAddTeamDialog(teams, details), icon: const Icon(Icons.add), tooltip: "Add Team")
                ]),
                const SizedBox(height: 10),
                if(teams.isEmpty) const Text("No teams added.", style: TextStyle(color: Colors.grey)),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: teams.map((tName) {
                    Map d = details[tName] ?? {};
                    return Chip(
                      avatar: CircleAvatar(backgroundColor: Color(d['color'] ?? 0xFF000000), radius: 8),
                      label: Text(tName),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      deleteIcon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                      onDeleted: () => _showTeamOptions(tName, teams, details), // Using deleteIcon slot for menu trigger
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTeamOptions(String name, List teams, Map details) {
    showModalBottomSheet(context: context, builder: (c) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Options for $name", style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Edit Team"), onTap: (){ Navigator.pop(c); _showEditTeamDialog(name, teams, details); }),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Team"), onTap: (){ Navigator.pop(c); _deleteTeam(name, teams, details); }),
      ])
    ));
  }

  void _showAddTeamDialog(List teams, Map details) {
    TextEditingController nameCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("New Team"),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Team Name", filled: true)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          String name = nameCtrl.text.trim();
          if(name.isNotEmpty && !teams.contains(name)) {
            teams.add(name);
            details[name] = {'color': Colors.blue.value, 'passcode': '1234'};
            await db.collection('settings').doc('general').update({'teams': teams, 'teamDetails': details});
            Navigator.pop(ctx);
          }
        }, child: const Text("Create"))
      ],
    ));
  }

  void _showEditTeamDialog(String name, List allTeams, Map allDetails) {
    Map d = allDetails[name] ?? {};
    TextEditingController editNameCtrl = TextEditingController(text: name);
    TextEditingController editPassCtrl = TextEditingController(text: d['passcode'] ?? '');
    Color selectedColor = Color(d['color'] ?? 0xFF2196F3);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Edit Team"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: editNameCtrl, decoration: const InputDecoration(labelText: "Team Name")),
            const SizedBox(height: 10),
            TextField(controller: editPassCtrl, decoration: const InputDecoration(labelText: "Login Passcode")),
            const SizedBox(height: 15),
            const Text("Team Color"),
            const SizedBox(height: 8),
            Wrap(spacing: 5, children: _colors.map((c) => InkWell(
              onTap: () => setDialogState(() => selectedColor = c),
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: selectedColor == c ? Border.all(width: 3, color: Colors.black) : null)),
            )).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(onPressed: () async {
              String newName = editNameCtrl.text.trim();
              if(newName.isNotEmpty) {
                if (newName != name) {
                  int idx = allTeams.indexOf(name);
                  if(idx != -1) allTeams[idx] = newName;
                  allDetails.remove(name);
                }
                allDetails[newName] = {'color': selectedColor.value, 'passcode': editPassCtrl.text, 'leaders': d['leaders'] ?? []};
                await db.collection('settings').doc('general').update({'teams': allTeams, 'teamDetails': allDetails});
                Navigator.pop(ctx);
              }
            }, child: const Text("Update"))
          ],
        );
      }
    ));
  }

  Future<void> _deleteTeam(String name, List teams, Map details) async {
    if(await _confirm("Delete Team?", "Deleting '$name' might cause issues with existing data.")) {
      teams.remove(name); details.remove(name);
      await db.collection('settings').doc('general').update({'teams': teams, 'teamDetails': details});
    }
  }

  // ================= 3. CATEGORIES MANAGEMENT (3-DOT MENU) =================
  Widget _buildCategoriesSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        var data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : {};
        List cats = List.from(data['categories'] ?? []);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.category, color: Colors.purple), SizedBox(width: 8), Text("Categories", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 10),
                
                Row(children: [
                  Expanded(child: TextField(controller: _catNameCtrl, decoration: const InputDecoration(labelText: "New Category", isDense: true, border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  IconButton.filled(onPressed: () async {
                    String c = _catNameCtrl.text.trim();
                    if(c.isNotEmpty && !cats.contains(c)) {
                      cats.add(c);
                      await db.collection('settings').doc('general').update({'categories': cats});
                      _catNameCtrl.clear();
                    }
                  }, icon: const Icon(Icons.add))
                ]),
                const SizedBox(height: 16),
                
                Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) => Chip(
                  label: Text(c),
                  deleteIcon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onDeleted: () => _showCategoryOptions(c, cats),
                )).toList())
              ],
            ),
          ),
        );
      }
    );
  }

  void _showCategoryOptions(String cat, List allCats) {
    showModalBottomSheet(context: context, builder: (c) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Options for $cat", style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text("Edit Category"), onTap: (){ Navigator.pop(c); _editCategory(cat, allCats); }),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text("Delete Category"), onTap: (){ Navigator.pop(c); _deleteCategory(cat, allCats); }),
      ])
    ));
  }

  void _editCategory(String cat, List allCats) {
    TextEditingController editCtrl = TextEditingController(text: cat);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit Category"),
      content: TextField(controller: editCtrl),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          int idx = allCats.indexOf(cat);
          if(idx != -1 && editCtrl.text.isNotEmpty) { 
            allCats[idx] = editCtrl.text.trim(); 
            await db.collection('settings').doc('general').update({'categories': allCats}); 
          }
          Navigator.pop(ctx);
        }, child: const Text("Update"))
      ],
    ));
  }

  Future<void> _deleteCategory(String cat, List allCats) async {
    if(await _confirm("Delete Category?", "Remove '$cat'? This may affect events.")) {
      allCats.remove(cat);
      await db.collection('settings').doc('general').update({'categories': allCats});
    }
  }

  // ================= 4. CHEST MATRIX =================
  Widget _buildChestMatrixSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = data['teams'] ?? [];
        List cats = data['categories'] ?? [];
        Map chestConfig = data['chestConfig'] ?? {};

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Row(children: [Icon(Icons.confirmation_number, color: Colors.orange), SizedBox(width: 8), Text("Chest Number Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_isMatrixEditing) db.collection('settings').doc('general').update({'chestConfig': chestConfig});
                        setState(() => _isMatrixEditing = !_isMatrixEditing);
                      },
                      icon: Icon(_isMatrixEditing ? Icons.save : Icons.edit),
                      label: Text(_isMatrixEditing ? "Save" : "Edit"),
                      style: ElevatedButton.styleFrom(backgroundColor: _isMatrixEditing ? Colors.green : Colors.blue, foregroundColor: Colors.white),
                    )
                ]),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                    border: TableBorder.all(color: Colors.grey.shade200),
                    columns: [const DataColumn(label: Text("Category")), ...teams.map((t) => DataColumn(label: Text(t)))],
                    rows: cats.map((c) => DataRow(cells: [
                      DataCell(Text(c, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ...teams.map((t) {
                        String key = "$t-$c-Male"; 
                        return DataCell(_isMatrixEditing 
                          ? TextFormField(initialValue: (chestConfig[key]??"").toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (v){ if(v.isNotEmpty) chestConfig[key]=int.parse(v); })
                          : Center(child: Text((chestConfig[key]??"-").toString())));
                      })
                    ])).toList(),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  // ================= 5. TEAM LEADERS (3-DOT & DRAG) =================
  Widget _buildTeamLeadersSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = List.from(data['teams'] ?? []);
        Map allDetails = Map<String, dynamic>.from(data['teamDetails'] ?? {});

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.groups, color: Colors.teal), SizedBox(width: 8), Text("Team Leaders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const Text("Add leaders. Drag to reorder. Changes reflect on public page.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                
                ...teams.map((tName) {
                  Map tData = allDetails[tName] ?? {};
                  List leaders = List.from(tData['leaders'] ?? []);
                  
                  return ExpansionTile(
                    title: Text(tName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: CircleAvatar(backgroundColor: Color(tData['color'] ?? 0xFF000000), radius: 10),
                    children: [
                      _buildLeadersList(tName, leaders, allTeams: teams, allDetails: allDetails)
                    ],
                  );
                }).toList()
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeadersList(String name, List leaders, {required List allTeams, required Map allDetails}) {
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (int i = 0; i < leaders.length; i++)
              ListTile(
                key: ValueKey(leaders[i]), 
                dense: true,
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(leaders[i]['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: Text(leaders[i]['name']),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editLeader(name, i, leaders, allDetails);
                    if (v == 'delete') _deleteLeader(name, i, leaders, allDetails);
                  },
                  itemBuilder: (c) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Edit")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Delete")])),
                  ],
                ),
              )
          ],
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = leaders.removeAt(oldIndex);
            leaders.insert(newIndex, item);
            allDetails[name]['leaders'] = leaders;
            await db.collection('settings').doc('general').update({'teamDetails': allDetails});
          },
        ),
        TextButton.icon(onPressed: () => _addLeader(name, leaders, allDetails), icon: const Icon(Icons.add, size: 16), label: const Text("Add Leader"))
      ],
    );
  }

  void _addLeader(String teamName, List leaders, Map allDetails) {
    TextEditingController roleCtrl = TextEditingController();
    TextEditingController nameCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Add Leader"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role")), const SizedBox(height: 10), TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name"))]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          if(roleCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
            leaders.add({'role': roleCtrl.text, 'name': nameCtrl.text});
            allDetails[teamName]['leaders'] = leaders;
            await db.collection('settings').doc('general').update({'teamDetails': allDetails});
            Navigator.pop(ctx);
          }
        }, child: const Text("Add"))
      ],
    ));
  }

  void _editLeader(String teamName, int index, List leaders, Map allDetails) {
    TextEditingController roleCtrl = TextEditingController(text: leaders[index]['role']);
    TextEditingController nameCtrl = TextEditingController(text: leaders[index]['name']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit Leader"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role")), const SizedBox(height: 10), TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name"))]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          leaders[index] = {'role': roleCtrl.text, 'name': nameCtrl.text};
          allDetails[teamName]['leaders'] = leaders;
          await db.collection('settings').doc('general').update({'teamDetails': allDetails});
          Navigator.pop(ctx);
        }, child: const Text("Update"))
      ],
    ));
  }

  void _deleteLeader(String teamName, int index, List leaders, Map allDetails) async {
    if(await _confirm("Delete Leader?", "Remove this leader?")) {
      leaders.removeAt(index);
      allDetails[teamName]['leaders'] = leaders;
      await db.collection('settings').doc('general').update({'teamDetails': allDetails});
    }
  }

  // ================= 6. DANGER ZONE =================
  Widget _buildDangerZone() {
    return Card(
      color: Colors.red.shade50, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("DANGER ZONE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _unlockWithDetailedWarning,
              icon: const Icon(Icons.delete_forever),
              label: const Text("FACTORY RESET DATA"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}