import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;

  // Controllers for Adding
  final _teamNameCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();
  
  // Controllers for Web Config
  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _socialIgCtrl = TextEditingController();
  final _socialYtCtrl = TextEditingController();

  // Local State
  String _tempMode = 'mixed'; // For Radio selection before saving
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWebConfig();
  }

  // Load existing web config values
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FEST MODE SETUP (Critical Section)
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
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // SECTION 1: MODE CONFIGURATION (LOCKING SYSTEM)
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
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isLocked ? Colors.white : Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isLocked ? Icons.lock : Icons.lock_open_rounded, 
                         color: isLocked ? Colors.green : Colors.indigo, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isLocked ? "CONFIGURATION LOCKED" : "SETUP COMPETITION MODE", 
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(isLocked ? "Mode: ${currentMode.toUpperCase()}" : "Select mode carefully",
                             style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
                
                if (!isLocked) ...[
                  const Divider(height: 30),
                  Row(
                    children: [
                      _radioOption('Mixed (Boys & Girls)', 'mixed'),
                      const SizedBox(width: 20),
                      _radioOption('Boys Only', 'boys'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _lockMode,
                      icon: const Icon(Icons.check_circle),
                      label: const Text("SAVE & LOCK CONFIGURATION"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text("* Once locked, you cannot change this without a factory reset.", 
                      style: TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
                  )
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 12),
                        const Expanded(child: Text("To change the mode, you must reset all data.", style: TextStyle(color: Colors.red, fontSize: 12))),
                        TextButton(
                          onPressed: _factoryReset,
                          child: const Text("UNLOCK / RESET", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                      ],
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

  Widget _radioOption(String label, String val) {
    return Row(
      children: [
        Radio(
          value: val, 
          groupValue: _tempMode, 
          activeColor: Colors.indigo,
          onChanged: (v) => setState(() => _tempMode = v.toString())
        ),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _lockMode() async {
    await db.collection('config').doc('main').set({
      'mode': _tempMode,
      'locked': true,
      'setupDone': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Also initialize settings/general if not exists
    await db.collection('settings').doc('general').set({
      'updated': true
    }, SetOptions(merge: true));
  }

  // ==============================================================================
  // SECTION 2: MASTER DATA (TEAMS & CATS)
  // ==============================================================================
  Widget _buildMasterDataSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('settings').doc('general').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        
        var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
        List teams = data['teams'] ?? [];
        List cats = data['categories'] ?? [];
        Map passcodes = data['teamPasscodes'] ?? {};

        return Column(
          children: [
            // TEAMS CARD
            _masterDataCard(
              title: "Manage Teams",
              icon: Icons.shield,
              color: Colors.blue,
              inputCtrl: _teamNameCtrl,
              hint: "Enter Team Name (e.g. Red House)",
              onAdd: () => _addTeam(teams, passcodes),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: teams.length,
                separatorBuilder: (c,i) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  String name = teams[i];
                  String pass = passcodes[name] ?? 'Not Set';
                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Passcode: $pass"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () => _showEditTeamDialog(name, pass, teams, passcodes),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removeTeam(name, teams, passcodes),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),

            // CATEGORIES CARD
            _masterDataCard(
              title: "Manage Categories",
              icon: Icons.category,
              color: Colors.orange,
              inputCtrl: _catNameCtrl,
              hint: "Enter Category (e.g. Senior)",
              onAdd: () => _addCat(cats),
              child: Wrap(
                spacing: 8,
                children: cats.map((c) => Chip(
                  label: Text(c),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeCat(c, cats),
                  backgroundColor: Colors.orange.shade50,
                  side: BorderSide(color: Colors.orange.shade200),
                )).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _masterDataCard({required String title, required IconData icon, required Color color, required TextEditingController inputCtrl, required String hint, required VoidCallback onAdd, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: inputCtrl, decoration: InputDecoration(hintText: hint, isDense: true))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  child: const Text("Add"),
                )
              ],
            ),
            const SizedBox(height: 16),
            child
          ],
        ),
      ),
    );
  }

  // --- TEAM LOGIC ---
  Future<void> _addTeam(List current, Map passcodes) async {
    if (_teamNameCtrl.text.isEmpty) return;
    String name = _teamNameCtrl.text.trim();
    if (!current.contains(name)) {
      current.add(name);
      // Default passcode can be set later
      await db.collection('settings').doc('general').set({
        'teams': current,
        'teamPasscodes': passcodes // keeps existing
      }, SetOptions(merge: true));
      _teamNameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Team Added! Set Passcode via Edit.")));
    }
  }

  Future<void> _showEditTeamDialog(String oldName, String oldPass, List teams, Map passcodes) {
    final nameCtrl = TextEditingController(text: oldName);
    final passCtrl = TextEditingController(text: oldPass == 'Not Set' ? '' : oldPass);

    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Edit Team: $oldName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Team Name")),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Team Portal Passcode")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String newName = nameCtrl.text.trim();
              String newPass = passCtrl.text.trim();
              
              if(newName.isNotEmpty) {
                // Remove old, Add new (to keep array clean)
                int idx = teams.indexOf(oldName);
                if(idx != -1) teams[idx] = newName;
                
                // Update Passcode Key
                passcodes.remove(oldName);
                if(newPass.isNotEmpty) passcodes[newName] = newPass;

                await db.collection('settings').doc('general').update({
                  'teams': teams,
                  'teamPasscodes': passcodes
                });
                
                if(mounted) Navigator.pop(c);
              }
            },
            child: const Text("Save Changes"),
          )
        ],
      ),
    );
  }

  Future<void> _removeTeam(String name, List current, Map passcodes) async {
    current.remove(name);
    passcodes.remove(name);
    await db.collection('settings').doc('general').update({
      'teams': current,
      'teamPasscodes': passcodes
    });
  }

  // --- CAT LOGIC ---
  Future<void> _addCat(List current) async {
    if (_catNameCtrl.text.isEmpty) return;
    String name = _catNameCtrl.text.trim();
    if (!current.contains(name)) {
      current.add(name);
      await db.collection('settings').doc('general').update({'categories': current});
      _catNameCtrl.clear();
    }
  }

  Future<void> _removeCat(String name, List current) async {
    current.remove(name);
    await db.collection('settings').doc('general').update({'categories': current});
  }

  // ==============================================================================
  // SECTION 3: CHEST MATRIX
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
                const Text("Chest Number Starting Values", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                    columns: [
                      const DataColumn(label: Text("Cat \\ Team", style: TextStyle(fontStyle: FontStyle.italic))),
                      ...teams.map((t) => DataColumn(label: Text(t.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)))),
                    ],
                    rows: cats.map((c) {
                      return DataRow(cells: [
                        DataCell(Text(c.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ...teams.map((t) {
                          String key = "$t-$c"; // Key Format compatible with HTML
                          return DataCell(
                            Container(
                              width: 70,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TextFormField(
                                initialValue: (chestConfig[key] ?? "").toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  hintText: "100",
                                  contentPadding: const EdgeInsets.all(8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                ),
                                onChanged: (val) {
                                  // Auto-save on change (Debounce could be added for optimization)
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
  // SECTION 4: WEBSITE CONFIG
  // ==============================================================================
  Widget _buildWebConfigSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.language, color: Colors.purple), SizedBox(width: 8), Text("Website Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16),
            TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name (Main Title)")),
            const SizedBox(height: 12),
            TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
            const SizedBox(height: 12),
            TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL (Image Link)")),
            const SizedBox(height: 12),
            const Text("Social Media Links", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _socialIgCtrl, decoration: const InputDecoration(labelText: "Instagram Link", prefixIcon: Icon(Icons.camera_alt, size: 16)))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _socialYtCtrl, decoration: const InputDecoration(labelText: "YouTube Link", prefixIcon: Icon(Icons.video_library, size: 16)))),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveWebConfig,
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

  Future<void> _saveWebConfig() async {
    setState(() => _isLoading = true);
    await db.collection('settings').doc('home_config').set({
      'festName1': _festNameCtrl.text,
      'tagline': _taglineCtrl.text,
      'logoUrl': _logoUrlCtrl.text,
      'social': {
        'ig': _socialIgCtrl.text,
        'yt': _socialYtCtrl.text,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Website Settings Updated Successfully!")));
  }

  // ==============================================================================
  // SECTION 5: FACTORY RESET
  // ==============================================================================
  Future<void> _factoryReset() async {
    // Confirmation Logic
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("FACTORY RESET"),
      content: const Text("WARNING: This will delete ALL Data:\n\n- All Students\n- All Events & Results\n- All Registrations\n- Team Configuration\n\nThe app will be unlocked for fresh setup.\nAre you sure?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text("YES, WIPE EVERYTHING"),
        )
      ],
    )) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      var batch = db.batch();

      // Reset Configs
      batch.delete(db.collection('config').doc('main'));
      batch.delete(db.collection('settings').doc('general'));
      // Optional: keep home_config or delete it too. Let's keep home config to avoid re-typing urls.

      // Delete Collections (Note: Client SDK cannot delete entire collection easily, usually requires Cloud Function)
      // We will loop and delete visible docs for now.
      var sSnap = await db.collection('students').get();
      for (var d in sSnap.docs) batch.delete(d.reference);

      var eSnap = await db.collection('events').get();
      for (var d in eSnap.docs) batch.delete(d.reference);
      
      var rSnap = await db.collection('results').get();
      for (var d in rSnap.docs) batch.delete(d.reference);

      var regSnap = await db.collection('registrations').get();
      for (var d in regSnap.docs) batch.delete(d.reference);

      await batch.commit();

      setState(() {
        _isLoading = false;
        _tempMode = 'mixed';
        // Clear Lists
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System Reset Complete. You can now change the mode.")));
    }
  }
}
