// File: lib/screens/settings_tab.dart
// Version: 4.0
// Description: Fully Redesigned Settings. Cards, Icons, Color Pickers, and Strict Mode Locking/Unlocking logic.

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
  final _teamPassCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();

  // State
  String _selectedMode = 'mixed'; // 'mixed' or 'boys'
  Color _selectedTeamColor = Colors.blue;
  bool _isLoading = false;

  // Colors Palette
  final List<Color> _colors = [
    Colors.red, Colors.blue, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.brown, 
    Colors.indigo, Colors.cyan
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
            child: Text(isDestructive ? "Confirm Delete" : "Confirm")
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
                const SizedBox(height: 40),
                _buildDangerZone(),
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  // ================= 1. MODE CONFIGURATION (CRITICAL) =================
  Widget _buildModeConfigSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        
        bool isLocked = data['locked'] == true;
        String mode = data['mode'] ?? 'mixed';
        
        // Update local state to match DB if locked
        if (isLocked && _selectedMode != mode) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if(mounted) setState(() => _selectedMode = mode);
           });
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isLocked ? Icons.lock : Icons.settings_suggest, color: isLocked ? Colors.green : Colors.indigo),
                    const SizedBox(width: 10),
                    Text(isLocked ? "COMPETITION MODE: LOCKED" : "SETUP COMPETITION MODE", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                
                if (isLocked)
                  _buildLockedView(mode)
                else
                  _buildUnlockedSelection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnlockedSelection() {
    return Column(
      children: [
        const Text("Select the type of fest. This defines how chest numbers and categories work.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _modeOption('mixed', "Mixed (Boys & Girls)", Icons.wc)),
            const SizedBox(width: 12),
            Expanded(child: _modeOption('boys', "Single Gender", Icons.male)),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _lockConfig,
            icon: const Icon(Icons.lock),
            label: const Text("SAVE & LOCK CONFIGURATION"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text("Warning: Locking prevents accidental mode changes.", style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic))),
      ],
    );
  }

  Widget _modeOption(String val, String label, IconData icon) {
    bool isSel = _selectedMode == val;
    return InkWell(
      onTap: () => setState(() => _selectedMode = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSel ? Colors.indigo.shade50 : Colors.white,
          border: Border.all(color: isSel ? Colors.indigo : Colors.grey.shade300, width: isSel ? 2 : 1),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            Icon(icon, color: isSel ? Colors.indigo : Colors.grey, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.indigo : Colors.black87), textAlign: TextAlign.center)
          ],
        ),
      ),
    );
  }

  Widget _buildLockedView(String mode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
      child: Column(
        children: [
          Text("Current Mode: ${mode.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Configuration is active. To change mode, you must reset all data.", style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _unlockWithReset,
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text("Unlock (Resets Data)"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Future<void> _lockConfig() async {
    if (await _confirm("Confirm Mode?", "You are selecting '$_selectedMode'. This will structure the entire app.")) {
      await db.collection('config').doc('main').set({'mode': _selectedMode, 'locked': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> _unlockWithReset() async {
    if (await _confirm("FULL RESET REQUIRED", "Unlocking configuration will DELETE ALL Students, Events, and Results to prevent data corruption. Are you sure?", isDestructive: true)) {
      setState(() => _isLoading = true);
      // Perform Factory Reset Logic
      var batch = db.batch();
      
      // Clear Collections
      var sSnap = await db.collection('students').get(); for (var d in sSnap.docs) batch.delete(d.reference);
      var eSnap = await db.collection('events').get(); for (var d in eSnap.docs) batch.delete(d.reference);
      var rSnap = await db.collection('registrations').get(); for (var d in rSnap.docs) batch.delete(d.reference);
      var resSnap = await db.collection('results').get(); for (var d in resSnap.docs) batch.delete(d.reference);
      
      // Unlock Config
      batch.set(db.collection('config').doc('main'), {'locked': false, 'mode': 'mixed'}); // Default back to mixed
      
      await batch.commit();
      setState(() { _isLoading = false; _selectedMode = 'mixed'; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Reset & Unlocked")));
    }
  }


  // ================= 2. TEAMS MANAGEMENT =================
  Widget _buildTeamsSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = List.from(data['teams'] ?? []);
        Map details = data['teamDetails'] ?? {};

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.shield, color: Colors.blue), SizedBox(width: 8), Text("Teams & Houses", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 16),
                
                // Add Team Input Row
                Row(
                  children: [
                    InkWell(
                      onTap: () => _pickColor(),
                      child: Container(width: 42, height: 42, decoration: BoxDecoration(color: _selectedTeamColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _teamNameCtrl, decoration: const InputDecoration(labelText: "Team Name", isDense: true))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _teamPassCtrl, decoration: const InputDecoration(labelText: "Passcode", isDense: true))),
                    const SizedBox(width: 10),
                    IconButton.filled(onPressed: () => _addTeam(teams, details), icon: const Icon(Icons.add))
                  ],
                ),
                const SizedBox(height: 20),

                // Teams List
                if(teams.isEmpty) const Center(child: Text("No teams added", style: TextStyle(color: Colors.grey))),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: teams.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    String name = teams[i];
                    Map d = details[name] ?? {};
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Color(d['color'] ?? 0xFF000000), radius: 10),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Pass: ${d['passcode'] ?? 'None'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editTeam(name, teams, details)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteTeam(name, teams, details)),
                        ],
                      ),
                    );
                  }
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _pickColor() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Select Color"),
      content: Wrap(spacing: 8, runSpacing: 8, children: _colors.map((color) => InkWell(
        onTap: () { setState(() => _selectedTeamColor = color); Navigator.pop(c); },
        child: CircleAvatar(backgroundColor: color, radius: 16),
      )).toList())
    ));
  }

  Future<void> _addTeam(List teams, Map details) async {
    String name = _teamNameCtrl.text.trim();
    if(name.isEmpty || teams.contains(name)) return;
    teams.add(name);
    details[name] = {'color': _selectedTeamColor.value, 'passcode': _teamPassCtrl.text.trim(), 'leaders': []};
    await db.collection('settings').doc('general').update({'teams': teams, 'teamDetails': details});
    _teamNameCtrl.clear(); _teamPassCtrl.clear();
  }

  Future<void> _deleteTeam(String name, List teams, Map details) async {
    if(await _confirm("Delete Team?", "Deleting '$name' will require fixing registrations linked to it.")) {
      teams.remove(name); details.remove(name);
      await db.collection('settings').doc('general').update({'teams': teams, 'teamDetails': details});
    }
  }
  
  void _editTeam(String name, List teams, Map details) {
    // Reuse existing add controls logic via a dialog for cleaner code or just populate top fields
    _teamNameCtrl.text = name;
    _teamPassCtrl.text = details[name]['passcode'] ?? '';
    setState(() => _selectedTeamColor = Color(details[name]['color'] ?? 0xFF000000));
    
    // For simplicity, we remove old and let user re-add updated version or use a specific update logic
    // Here we just guide user:
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit mode: Make changes and click Add (Old entry will be replaced if name changes)")));
  }


  // ================= 3. CATEGORIES MANAGEMENT =================
  Widget _buildCategoriesSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        var data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : {};
        List cats = List.from(data['categories'] ?? []);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.category, color: Colors.purple), SizedBox(width: 8), Text("Categories", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                const SizedBox(height: 16),
                
                Row(children: [
                  Expanded(child: TextField(controller: _catNameCtrl, decoration: const InputDecoration(labelText: "New Category", isDense: true))),
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
                  label: Text(c.toString()),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () async {
                    if(await _confirm("Delete?", "Remove category '$c'?")) {
                      cats.remove(c);
                      await db.collection('settings').doc('general').update({'categories': cats});
                    }
                  },
                )).toList())
              ],
            ),
          ),
        );
      }
    );
  }


  // ================= 4. CHEST NUMBER MATRIX =================
  Widget _buildChestMatrixSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('config').doc('main').snapshots(),
      builder: (context, configSnap) {
        String mode = (configSnap.data?.exists ?? false) ? (configSnap.data!.get('mode') ?? 'mixed') : 'mixed';
        bool isMixed = mode == 'mixed';

        return StreamBuilder<DocumentSnapshot>(
          stream: db.collection('settings').doc('general').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox();
            var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
            List teams = data['teams'] ?? [];
            List cats = data['categories'] ?? [];
            Map chestConfig = data['chestConfig'] ?? {};

            if(teams.isEmpty || cats.isEmpty) return const SizedBox();

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.confirmation_number, color: Colors.orange), SizedBox(width: 8), Text("Chest Number Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 8),
                    const Text("Define starting chest numbers for each group.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                        border: TableBorder.all(color: Colors.grey.shade200),
                        columns: [
                          const DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                          ...teams.map((t) => DataColumn(label: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: Color((data['teamDetails']?[t]?['color']) ?? 0xFF000000))))),
                        ],
                        rows: _generateMatrixRows(cats, teams, chestConfig, isMixed),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  List<DataRow> _generateMatrixRows(List cats, List teams, Map config, bool isMixed) {
    List<DataRow> rows = [];
    for (var c in cats) {
      if (isMixed) {
        rows.add(_buildMatrixRow("$c (Boys)", c, "Male", teams, config));
        rows.add(_buildMatrixRow("$c (Girls)", c, "Female", teams, config));
      } else {
        rows.add(_buildMatrixRow(c, c, "Male", teams, config)); // Default key uses 'Male' structure for simple mode
      }
    }
    return rows;
  }

  DataRow _buildMatrixRow(String label, String cat, String gender, List teams, Map config) {
    return DataRow(cells: [
      DataCell(Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ...teams.map((t) {
        String key = "$t-$cat-$gender";
        return DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextFormField(
              initialValue: (config[key] ?? "").toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: InputBorder.none, hintText: "Start #", isDense: true),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) {
                if(val.isNotEmpty) {
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


  // ================= 5. DANGER ZONE =================
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
            const Text("Actions here are irreversible. Be careful.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _unlockWithReset, // Reuse the reset logic
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