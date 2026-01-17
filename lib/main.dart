import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==============================================================================
// 1. MAIN ENTRY & CONFIGURATION
// ==============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCOT73k7YWxlh0qYFYGKa1W_NW29LjwsgQ",
      appId: "1:476270819694:web:2689cf709656cfde1d697f",
      messagingSenderId: "476270819694",
      projectId: "fest-21d67",
      storageBucket: "fest-21d67.firebasestorage.app",
      authDomain: "fest-21d67.firebaseapp.com",
      measurementId: "G-93HHHL4H2P",
    ),
  );
  runApp(const FestApp());
}

class FestApp extends StatelessWidget {
  const FestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'College Fest',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo Primary
          background: const Color(0xFFF8FAFC), // Light Slate Background
        ),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==============================================================================
// 2. AUTH & NAVIGATION WRAPPER
// ==============================================================================

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint("Auth Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MainLayout();
        }
        return const Scaffold(body: Center(child: Text("Connecting to Database...")));
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _activeTab = 'dashboard';
  bool _isMenuOpen = false;

  final List<Map<String, dynamic>> _tabs = [
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.space_dashboard_rounded},
    {'id': 'registration', 'label': 'Registration', 'icon': Icons.person_add_alt_1_rounded},
    {'id': 'events', 'label': 'Events', 'icon': Icons.emoji_events_rounded},
    {'id': 'settings', 'label': 'Settings', 'icon': Icons.settings_rounded},
  ];

  void _switchTab(String id) {
    setState(() {
      _activeTab = id;
      _isMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // MAIN CONTENT AREA
          Padding(
            padding: const EdgeInsets.only(top: 90, left: 16, right: 16, bottom: 20),
            child: _buildBody(),
          ),

          // FLOATING HEADER
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
                border: Border.all(color: Colors.white),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                                child: Icon(_isMenuOpen ? Icons.close_rounded : Icons.menu_rounded, color: Colors.indigo, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text("FestManager", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(20)),
                          child: Text(_activeTab.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                  
                  // DROPDOWN MENU
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isMenuOpen
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: _tabs.map((t) => ListTile(
                                leading: Icon(t['icon'], color: _activeTab == t['id'] ? Colors.indigo : Colors.grey.shade400),
                                title: Text(t['label'], style: TextStyle(fontWeight: _activeTab == t['id'] ? FontWeight.bold : FontWeight.normal, color: _activeTab == t['id'] ? Colors.indigo : Colors.black54)),
                                onTap: () => _switchTab(t['id']),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              )).toList(),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 'dashboard': return const DashboardView();
      case 'registration': return const RegistrationView();
      case 'events': return const EventsView();
      case 'settings': return const SettingsView();
      default: return const DashboardView();
    }
  }
}

// ==============================================================================
// 3. SETTINGS VIEW (Edit/Delete Teams, Categories, Chest Matrix)
// ==============================================================================

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;
  final _teamCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  Color _selectedColor = Colors.red;

  final List<Color> _colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.brown];

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 10), Text(msg)]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red : Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // Edit Dialog
  void _showEditDialog(String coll, String docId, String currentName, {int? currentColor}) {
    final editCtrl = TextEditingController(text: currentName);
    Color editColor = currentColor != null ? Color(currentColor) : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${coll == 'teams' ? 'Team' : 'Category'}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editCtrl, decoration: const InputDecoration(labelText: "Name")),
            if (coll == 'teams') ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _colors.map((c) => GestureDetector(
                    onTap: () { editColor = c; (context as Element).markNeedsBuild(); }, // Force rebuild for simplicity
                    child: Container(margin: const EdgeInsets.all(4), width: 30, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300))),
                  )).toList(),
                ),
              )
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              db.collection(coll).doc(docId).update({
                'name': editCtrl.text,
                if(coll == 'teams') 'color': editColor.value
              });
              Navigator.pop(context);
              _showToast("Updated Successfully");
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. CONFIGURATION
          StreamBuilder<DocumentSnapshot>(
            stream: db.collection('config').doc('main').snapshots(),
            builder: (context, snap) {
              final data = snap.hasData && snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {'mode': 'mixed', 'locked': false};
              bool isLocked = data['locked'] ?? false;
              String mode = data['mode'] ?? 'mixed';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text("Fest Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if(isLocked) const Chip(label: Text("LOCKED", style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.redAccent)
                      ]),
                      const SizedBox(height: 12),
                      DropdownButtonFormField(
                        value: mode,
                        decoration: const InputDecoration(labelText: "Participation Mode", prefixIcon: Icon(Icons.people_alt_rounded)),
                        items: const [
                          DropdownMenuItem(value: 'mixed', child: Text("Mixed (Boys & Girls)")),
                          DropdownMenuItem(value: 'boys', child: Text("Boys Only")),
                        ],
                        onChanged: isLocked ? null : (v) => db.collection('config').doc('main').set({'mode': v}, SetOptions(merge: true)),
                      ),
                      const SizedBox(height: 12),
                      if(!isLocked)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock_outline),
                            label: const Text("Lock Configuration"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                            onPressed: () => _confirmDialog("Lock Configuration?", "You cannot change mode after locking.", () => db.collection('config').doc('main').set({'locked': true}, SetOptions(merge: true))),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // B. MANAGE TEAMS & CATEGORIES
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildManager("Teams", "teams", _teamCtrl, hasColor: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildManager("Categories", "categories", _catCtrl, hasColor: false)),
            ],
          ),
          const SizedBox(height: 16),

          // C. CHEST NUMBER MATRIX
          const Text("Chest Number Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: db.collection('teams').snapshots(),
            builder: (ctx, tSnap) {
              if(!tSnap.hasData) return const SizedBox();
              return StreamBuilder(
                stream: db.collection('categories').snapshots(),
                builder: (ctx, cSnap) {
                  if(!cSnap.hasData) return const SizedBox();
                  return StreamBuilder<DocumentSnapshot>(
                    stream: db.collection('config').doc('chest_ranges').snapshots(),
                    builder: (ctx, rSnap) {
                      final ranges = rSnap.hasData && rSnap.data!.exists ? rSnap.data!.data() as Map<String,dynamic> : {};
                      return Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 40,
                            columnSpacing: 20,
                            columns: [
                              const DataColumn(label: Text("Cat")),
                              ...tSnap.data!.docs.map((t) => DataColumn(label: Text(t['name'], style: TextStyle(color: Color(t['color']), fontWeight: FontWeight.bold)))),
                            ],
                            rows: cSnap.data!.docs.map((c) {
                              return DataRow(cells: [
                                DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.w600))),
                                ...tSnap.data!.docs.map((t) {
                                  String key = "${t.id}_${c.id}";
                                  return DataCell(SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      initialValue: (ranges[key] ?? 0).toString(),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: "0"),
                                      onChanged: (v) => db.collection('config').doc('chest_ranges').set({key: int.tryParse(v)??0}, SetOptions(merge: true)),
                                    ),
                                  ));
                                })
                              ]);
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 30),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text("Reset All Data", style: TextStyle(color: Colors.red)),
              onPressed: () => _confirmDialog("Reset All?", "This will delete ALL Students & Events!", () => _showToast("Contact Admin for Full Reset", isError: true)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildManager(String title, String coll, TextEditingController ctrl, {required bool hasColor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if(hasColor)
               SizedBox(
                 height: 30,
                 child: ListView(
                   scrollDirection: Axis.horizontal,
                   children: _colors.map((c) => GestureDetector(
                     onTap: () => setState(() => _selectedColor = c),
                     child: Container(margin: const EdgeInsets.all(2), width: 22, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: _selectedColor == c ? Colors.black : Colors.transparent, width: 2))),
                   )).toList(),
                 ),
               ),
            const SizedBox(height: 5),
            TextField(controller: ctrl, decoration: InputDecoration(isDense: true, hintText: "New $title", contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), suffixIcon: IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo), onPressed: () {
                if(ctrl.text.isNotEmpty) {
                  db.collection(coll).add({
                    'name': ctrl.text,
                    if(hasColor) 'color': _selectedColor.value,
                    'createdAt': DateTime.now().millisecondsSinceEpoch
                  });
                  ctrl.clear();
                  _showToast("$title Added");
                }
              }))),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: db.collection(coll).orderBy('createdAt').snapshots(),
              builder: (ctx, snap) {
                if(!snap.hasData) return const SizedBox();
                return Column(
                  children: snap.data!.docs.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        if(hasColor) CircleAvatar(backgroundColor: Color(d['color']), radius: 5),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d['name'], style: const TextStyle(fontSize: 13))),
                        InkWell(onTap: () => _showEditDialog(coll, d.id, d['name'], currentColor: hasColor ? d['color'] : null), child: const Icon(Icons.edit, size: 16, color: Colors.blue)),
                        const SizedBox(width: 8),
                        InkWell(onTap: () => _confirmDialog("Delete?", "Remove ${d['name']}?", () => d.reference.delete()), child: const Icon(Icons.delete, size: 16, color: Colors.red)),
                      ],
                    ),
                  )).toList(),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  void _confirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title), content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { onConfirm(); Navigator.pop(ctx); }, child: const Text("Confirm"))],
      ),
    );
  }
}

// ==============================================================================
// 4. REGISTRATION VIEW (Edit/Delete Student, Bulk)
// ==============================================================================

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final db = FirebaseFirestore.instance;
  bool _isBulk = false;
  String? _teamId;
  String? _catId;
  String _gender = 'male';
  final _nameCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  int _nextChest = 0;

  void _calculateChest(List<QueryDocumentSnapshot> students, Map<String, dynamic> ranges) {
    if(_teamId == null || _catId == null) { setState(() => _nextChest = 0); return; }
    int start = ranges["${_teamId}_$_catId"] ?? 0;
    int count = students.where((s) => s['teamId'] == _teamId && s['categoryId'] == _catId).length;
    setState(() => _nextChest = start + count);
  }

  Future<void> _submit() async {
    if(_teamId == null || _catId == null) return;
    
    if(_isBulk) {
      List<String> names = _bulkCtrl.text.split(RegExp(r'[\n,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      int currentChest = _nextChest;
      WriteBatch batch = db.batch();
      for(String name in names) {
        batch.set(db.collection('students').doc(), {
          'name': name, 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender,
          'chestNo': currentChest++, 'createdAt': DateTime.now().millisecondsSinceEpoch
        });
      }
      await batch.commit();
      _bulkCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${names.length} Imported")));
    } else {
      if(_nameCtrl.text.isEmpty) return;
      await db.collection('students').add({
        'name': _nameCtrl.text, 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender,
        'chestNo': _nextChest, 'createdAt': DateTime.now().millisecondsSinceEpoch
      });
      _nameCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registered Chest No: $_nextChest")));
    }
  }

  void _editStudent(DocumentSnapshot doc) {
    final nameCtrl = TextEditingController(text: doc['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Student"),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Student Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () { doc.reference.update({'name': nameCtrl.text}); Navigator.pop(ctx); }, child: const Text("Update"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [_toggleBtn("Single Entry", !_isBulk, () => setState(() => _isBulk = false)), _toggleBtn("Bulk Import", _isBulk, () => setState(() => _isBulk = true))]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: StreamBuilder(stream: db.collection('teams').snapshots(), builder: (c,s) => _dropdown(s, "Team", _teamId, (v) => setState(() => _teamId = v)))),
                  const SizedBox(width: 10),
                  Expanded(child: StreamBuilder(stream: db.collection('categories').snapshots(), builder: (c,s) => _dropdown(s, "Category", _catId, (v) => setState(() => _catId = v)))),
                ]),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot>(
                   stream: db.collection('config').doc('main').snapshots(),
                   builder: (c, s) {
                     String mode = s.hasData && s.data!.exists ? s.data!.get('mode') : 'mixed';
                     if(mode == 'boys') return const SizedBox();
                     return Row(children: [
                        const Text("Gender: ", style: TextStyle(fontWeight: FontWeight.bold)),
                        Radio(value: 'male', groupValue: _gender, onChanged: (v) => setState(() => _gender = v.toString())), const Text("Boy"),
                        const SizedBox(width: 10),
                        Radio(value: 'female', groupValue: _gender, onChanged: (v) => setState(() => _gender = v.toString())), const Text("Girl"),
                     ]);
                   },
                ),
                const SizedBox(height: 8),
                if(_isBulk) TextField(controller: _bulkCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Names (Copy from Excel)", hintText: "Name 1, Name 2..."))
                else TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Student Name")),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: db.collection('students').snapshots(),
                  builder: (ctx, sSnap) => StreamBuilder<DocumentSnapshot>(
                    stream: db.collection('config').doc('chest_ranges').snapshots(),
                    builder: (ctx, rSnap) {
                      if(sSnap.hasData && rSnap.hasData) WidgetsBinding.instance.addPostFrameCallback((_) => _calculateChest(sSnap.data!.docs, rSnap.data!.data() as Map<String,dynamic>));
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("Next Chest No:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("$_nextChest", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo))
                        ]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.check), label: Text(_isBulk ? "Import All" : "Register"), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12))))
              ],
            ),
          ),
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('students').orderBy('createdAt', descending: true).snapshots(),
            builder: (ctx, snap) {
              if(!snap.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                padding: const EdgeInsets.only(top: 10),
                itemCount: snap.data!.docs.length,
                itemBuilder: (ctx, i) {
                  var d = snap.data!.docs[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.indigo.shade100, child: Text("${d['chestNo']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      title: Text(d['name']),
                      subtitle: Text(d['gender'].toString().toUpperCase()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editStudent(d)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")), ElevatedButton(onPressed: () { d.reference.delete(); Navigator.pop(c); }, child: const Text("Yes"))]))),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  Widget _toggleBtn(String txt, bool active, VoidCallback onTap) => Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center, decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6), boxShadow: active ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null), child: Text(txt, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.black : Colors.grey)))));
  Widget _dropdown(AsyncSnapshot snap, String hint, String? val, Function(String?) chg) {
    if(!snap.hasData) return const SizedBox();
    return DropdownButtonFormField(value: val, decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), labelText: hint), items: (snap.data!.docs as List).map((d) => DropdownMenuItem(value: d.id as String, child: Text(d['name']))).toList(), onChanged: chg);
  }
}

// ==============================================================================
// 5. EVENTS VIEW (Edit/Delete Events)
// ==============================================================================

class EventsView extends StatefulWidget {
  const EventsView({super.key});
  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final db = FirebaseFirestore.instance;
  bool _showForm = false;
  
  final _nameCtrl = TextEditingController();
  String _type = 'single';
  String _stage = 'off-stage';
  String _participation = 'open';
  String _catType = 'general';
  
  final _pts1Ctrl = TextEditingController(text: '5');
  final _pts2Ctrl = TextEditingController(text: '3');
  final _pts3Ctrl = TextEditingController(text: '1');
  final _limitCtrl = TextEditingController(text: '3');

  void _onTypeChange(String? v) {
    setState(() {
      _type = v!;
      if(_type == 'single') { _pts1Ctrl.text = '5'; _pts2Ctrl.text = '3'; _pts3Ctrl.text = '1'; _limitCtrl.text = '3'; } 
      else { _pts1Ctrl.text = '10'; _pts2Ctrl.text = '8'; _pts3Ctrl.text = '5'; _limitCtrl.text = '2'; }
    });
  }

  Future<void> _saveEvent() async {
    if(_nameCtrl.text.isEmpty) return;
    await db.collection('events').add({
      'name': _nameCtrl.text, 'type': _type, 'stage': _stage, 'participation': _participation, 'category': _catType,
      'pts': [int.parse(_pts1Ctrl.text), int.parse(_pts2Ctrl.text), int.parse(_pts3Ctrl.text)], 'limit': int.parse(_limitCtrl.text), 'createdAt': DateTime.now().millisecondsSinceEpoch
    });
    setState(() => _showForm = false); _nameCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event Created")));
  }

  void _editEvent(DocumentSnapshot doc) {
    // Basic Edit: For full edit, you would populate all controllers.
    // Here we allow editing Name & Points for simplicity.
    final eNameCtrl = TextEditingController(text: doc['name']);
    final ePts1 = TextEditingController(text: doc['pts'][0].toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Edit Event"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: eNameCtrl, decoration: const InputDecoration(labelText: "Event Name")),
        const SizedBox(height: 10),
        TextField(controller: ePts1, decoration: const InputDecoration(labelText: "1st Points"), keyboardType: TextInputType.number),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")), ElevatedButton(onPressed: () { 
        doc.reference.update({'name': eNameCtrl.text, 'pts': [int.parse(ePts1.text), doc['pts'][1], doc['pts'][2]]}); 
        Navigator.pop(ctx); 
      }, child: const Text("Update"))]
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if(!_showForm) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => setState(() => _showForm = true), icon: const Icon(Icons.add), label: const Text("Create New Event"), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white))),
        if(_showForm) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Event Name")),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _dd("Type", _type, ['single', 'group'], _onTypeChange)), const SizedBox(width: 10), Expanded(child: _dd("Stage", _stage, ['off-stage', 'on-stage'], (v) => setState(() => _stage = v!)))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _dd("Participate", _participation, ['open', 'boys', 'girls'], (v) => setState(() => _participation = v!))), const SizedBox(width: 10), Expanded(child: StreamBuilder(stream: db.collection('categories').snapshots(), builder: (c,s) { List<DropdownMenuItem<String>> items = [const DropdownMenuItem(value: 'general', child: Text("General"))]; if(s.hasData) items.addAll(s.data!.docs.map((d) => DropdownMenuItem(value: d.id as String, child: Text(d['name'])))); return DropdownButtonFormField(value: _catType, decoration: const InputDecoration(labelText: "Category", contentPadding: EdgeInsets.symmetric(horizontal: 10)), items: items, onChanged: (v) => setState(() => _catType = v!));}))]),
          const SizedBox(height: 10),
          const Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Row(children: [Expanded(child: TextField(controller: _pts1Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: _pts2Ctrl, keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: _pts3Ctrl, keyboardType: TextInputType.number))]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => setState(() => _showForm = false), child: const Text("Cancel")), ElevatedButton(onPressed: _saveEvent, child: const Text("Save"))])
        ]))),
        
        const SizedBox(height: 10),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('events').orderBy('createdAt', descending: true).snapshots(), builder: (ctx, snap) {
           if(!snap.hasData) return const SizedBox();
           return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
             var e = snap.data!.docs[i];
             return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                 Text(e['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 Row(children: [
                   IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _editEvent(e)),
                   IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Event?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")), ElevatedButton(onPressed: () { e.reference.delete(); Navigator.pop(c); }, child: const Text("Yes"))]))),
                 ])
               ]),
               Row(children: [_tag(e['stage'] == 'on-stage' ? Colors.orange : Colors.blue, e['stage']), const SizedBox(width: 4), _tag(Colors.grey, e['type']), const SizedBox(width: 4), _tag(Colors.green, e['participation'])]),
               const SizedBox(height: 4), Text("Points: ${e['pts'][0]}-${e['pts'][1]}-${e['pts'][2]}  •  Cat: ${e['category'] == 'general' ? 'Gen' : 'Spec'}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
             ])));
           });
        }))
      ],
    );
  }

  Widget _dd(String label, String val, List<String> opts, Function(String?) chg) => DropdownButtonFormField(value: val, decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 10)), items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(), onChanged: chg);
  Widget _tag(Color c, String txt) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withOpacity(0.3))), child: Text(txt.toUpperCase(), style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.bold)));
}

// ==============================================================================
// 6. DASHBOARD VIEW
// ==============================================================================

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return SingleChildScrollView(
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c, sSnap) => StreamBuilder<QuerySnapshot>(stream: db.collection('events').snapshots(), builder: (c, eSnap) {
             int sCount = sSnap.hasData ? sSnap.data!.docs.length : 0;
             int eCount = eSnap.hasData ? eSnap.data!.docs.length : 0;
             return Row(children: [_stat(sCount.toString(), "Students", Colors.blue, Icons.people), const SizedBox(width: 12), _stat(eCount.toString(), "Events", Colors.purple, Icons.emoji_events)]);
          })),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("House Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(stream: db.collection('teams').snapshots(), builder: (c, tSnap) {
            if(!tSnap.hasData) return const SizedBox();
            return StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c, sSnap) {
              if(!sSnap.hasData) return const SizedBox();
              var students = sSnap.data!.docs;
              return Column(children: tSnap.data!.docs.map((t) {
                int count = students.where((s) => s['teamId'] == t.id).length;
                return Card(child: ListTile(leading: CircleAvatar(backgroundColor: Color(t['color']), child: Text(t['name'][0], style: const TextStyle(color: Colors.white))), title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text("$count Students", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))));
              }).toList());
            });
          })
        ],
      ),
    );
  }

  Widget _stat(String val, String lbl, Color col, IconData ic) => Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Column(children: [Icon(ic, color: col, size: 30), const SizedBox(height: 10), Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: col)), Text(lbl, style: TextStyle(color: Colors.grey.shade600))])));
}
