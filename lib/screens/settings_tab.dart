// File: lib/screens/settings_tab.dart
// Version: 6.0
// Description: Advanced Settings. Team Edit (Color/Pass), Category Edit, Matrix Edit/Save Mode, Team Leaders with Drag & Drop.

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
  bool _isMatrixEditing = false; // Toggle for Matrix Edit Mode

  // Colors Palette
  final List<Color> _colors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.brown, 
    Colors.indigo, Colors.cyan, Colors.lime, Colors.amber
  ];

  // Helper: Confirmation Dialog
  Future<bool> _confirm(String title, String msg, {bool isDestructive = false}) async {
    return await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? Colors.red : Colors.indigo, foregroundColor: Colors.white),
            child: Text(isDestructive ? "Confirm" : "Yes")
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
                _buildTeamLeadersSection(), // New Section
                const SizedBox(height: 40),
                _buildDangerZone(),
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  // ================= 1. MODE CONFIGURATION =================
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
                    child: Row(children: [const Icon(Icons.lock, color: Colors.green), const SizedBox(width: 10), Expanded(child: Text("Mode Locked: ${mode.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))), OutlinedButton(onPressed: _unlockWithReset, child: const Text("Unlock"))]),
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
    if (await _confirm("Lock Mode?", "This will define the structure.")) {
      await db.collection('config').doc('main').set({'mode': _selectedMode, 'locked': true});
    }
  }

  Future<void> _unlockWithReset() async {
    if (await _confirm("RESET REQUIRED", "Unlocking will DELETE ALL DATA. Are you sure?", isDestructive: true)) {
      setState(() => _isLoading = true);
      var batch = db.batch();
      // Add deletion logic here for all collections if needed
      batch.set(db.collection('config').doc('main'), {'locked': false, 'mode': 'mixed'});
      await batch.commit();
      setState(() { _isLoading = false; _selectedMode = 'mixed'; });
    }
  }

  // ================= 2. TEAMS MANAGEMENT (IMPROVED) =================
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
                    return InkWell(
                      onTap: () => _showEditTeamDialog(tName, teams, details),
                      child: Chip(
                        avatar: CircleAvatar(backgroundColor: Color(d['color'] ?? 0xFF000000), radius: 8),
                        label: Text(tName),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      ),
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
            details[name] = {'color': Colors.blue.value, 'passcode': '1234'}; // Default
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
            TextButton(onPressed: () async {
              if(await _confirm("Delete Team?", "Deleting '$name' might cause issues.", isDestructive: true)) {
                allTeams.remove(name); allDetails.remove(name);
                await db.collection('settings').doc('general').update({'teams': allTeams, 'teamDetails': allDetails});
                Navigator.pop(ctx);
              }
            }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete")),
            ElevatedButton(onPressed: () async {
              String newName = editNameCtrl.text.trim();
              if(newName.isNotEmpty) {
                // Handle Rename
                if (newName != name) {
                  int idx = allTeams.indexOf(name);
                  if(idx != -1) allTeams[idx] = newName;
                  allDetails.remove(name);
                }
                allDetails[newName] = {'color': selectedColor.value, 'passcode': editPassCtrl.text};
                await db.collection('settings').doc('general').update({'teams': allTeams, 'teamDetails': allDetails});
                Navigator.pop(ctx);
              }
            }, child: const Text("Save"))
          ],
        );
      }
    ));
  }

  // ================= 3. CATEGORIES MANAGEMENT =================
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
                
                Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) => InputChip(
                  label: Text(c),
                  onDeleted: () async {
                    if(await _confirm("Delete?", "Remove category '$c'?")) {
                      cats.remove(c);
                      await db.collection('settings').doc('general').update({'categories': cats});
                    }
                  },
                  onPressed: () {
                    TextEditingController editCtrl = TextEditingController(text: c);
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text("Edit Category"),
                      content: TextField(controller: editCtrl),
                      actions: [
                        ElevatedButton(onPressed: () async {
                          int idx = cats.indexOf(c);
                          if(idx != -1) { cats[idx] = editCtrl.text.trim(); await db.collection('settings').doc('general').update({'categories': cats}); }
                          Navigator.pop(ctx);
                        }, child: const Text("Save"))
                      ],
                    ));
                  },
                )).toList())
              ],
            ),
          ),
        );
      }
    );
  }

  // ================= 4. CHEST MATRIX (EDIT/SAVE MODE) =================
  Widget _buildChestMatrixSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = data['teams'] ?? [];
        List cats = data['categories'] ?? [];
        Map chestConfig = data['chestConfig'] ?? {};

        // Temporary map to hold edits before saving
        Map<String, int> tempEdits = {};

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(children: [Icon(Icons.confirmation_number, color: Colors.orange), SizedBox(width: 8), Text("Chest Number Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_isMatrixEditing) {
                          // SAVE LOGIC
                          db.collection('settings').doc('general').update({'chestConfig': chestConfig}); // In real app, merge tempEdits
                        }
                        setState(() => _isMatrixEditing = !_isMatrixEditing);
                      },
                      icon: Icon(_isMatrixEditing ? Icons.save : Icons.edit),
                      label: Text(_isMatrixEditing ? "Save Changes" : "Edit"),
                      style: ElevatedButton.styleFrom(backgroundColor: _isMatrixEditing ? Colors.green : Colors.blue, foregroundColor: Colors.white),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                    border: TableBorder.all(color: Colors.grey.shade200),
                    columns: [
                      const DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                      ...teams.map((t) => DataColumn(label: Text(t, style: TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                    rows: cats.map((c) => DataRow(cells: [
                      DataCell(Text(c, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ...teams.map((t) {
                        String key = "$t-$c-Male"; // Default key structure
                        String val = (chestConfig[key] ?? "").toString();
                        return DataCell(
                          _isMatrixEditing 
                          ? TextFormField(
                              initialValue: val,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: "0"),
                              onChanged: (v) {
                                if(v.isNotEmpty) chestConfig[key] = int.parse(v);
                              },
                            )
                          : Center(child: Text(val.isEmpty ? "-" : val)),
                        );
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

  // ================= 5. TEAM LEADERS (DRAG & DROP) =================
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
                const Text("Add leaders here. Drag to reorder positions. Photos can be added in Web Config.", style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                key: ValueKey(leaders[i]), // Use object itself or unique ID if available
                dense: true,
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(leaders[i]['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: Text(leaders[i]['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _editLeader(name, i, leaders, allTeams, allDetails)),
                    IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), onPressed: () => _deleteLeader(name, i, leaders, allTeams, allDetails)),
                  ],
                ),
              )
          ],
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = leaders.removeAt(oldIndex);
            leaders.insert(newIndex, item);
            
            // Save Reorder
            allDetails[name]['leaders'] = leaders;
            await db.collection('settings').doc('general').update({'teamDetails': allDetails});
          },
        ),
        TextButton.icon(
          onPressed: () => _addLeader(name, leaders, allTeams, allDetails),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Add Leader"),
        )
      ],
    );
  }

  void _addLeader(String teamName, List leaders, List allTeams, Map allDetails) {
    TextEditingController roleCtrl = TextEditingController();
    TextEditingController nameCtrl = TextEditingController();
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Add Leader"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role (e.g. Captain)")),
        const SizedBox(height: 10),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
      ]),
      actions: [
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

  void _editLeader(String teamName, int index, List leaders, List allTeams, Map allDetails) {
    TextEditingController roleCtrl = TextEditingController(text: leaders[index]['role']);
    TextEditingController nameCtrl = TextEditingController(text: leaders[index]['name']);
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit Leader"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role")),
        const SizedBox(height: 10),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
      ]),
      actions: [
        ElevatedButton(onPressed: () async {
          leaders[index] = {'role': roleCtrl.text, 'name': nameCtrl.text};
          allDetails[teamName]['leaders'] = leaders;
          await db.collection('settings').doc('general').update({'teamDetails': allDetails});
          Navigator.pop(ctx);
        }, child: const Text("Update"))
      ],
    ));
  }

  void _deleteLeader(String teamName, int index, List leaders, List allTeams, Map allDetails) async {
    if(await _confirm("Delete?", "Remove this leader?")) {
      leaders.removeAt(index);
      allDetails[teamName]['leaders'] = leaders;
      await db.collection('settings').doc('general').update({'teamDetails': allDetails});
    }
  }

  // ================= 6. DANGER ZONE =================
  Widget _buildDangerZone() {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("DANGER ZONE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
            const SizedBox(height: 10),
            const Text("Actions here are irreversible.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                 if(await _confirm("FACTORY RESET", "DELETE ALL DATA?", isDestructive: true)) {
                   // Add full reset logic here
                 }
              },
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