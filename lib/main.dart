import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==============================================================================
// 1. MAIN ENTRY
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
      title: 'College Fest Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo color
          background: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const AuthGuard(),
    );
  }
}

// ==============================================================================
// 2. AUTH GUARD
// ==============================================================================

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});
  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) await FirebaseAuth.instance.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (!authSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // Check Setup
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('config').doc('main').snapshots(),
          builder: (context, configSnap) {
            if (!configSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final data = configSnap.data!.data() as Map<String, dynamic>?;
            
            // ലോക്ക് ചെയ്തിട്ടില്ലെങ്കിൽ സെറ്റപ്പ് സ്ക്രീൻ കാണിക്കും
            if (data == null || data['setupDone'] != true) {
              return const InitialSetupScreen();
            }
            return const MainDashboard();
          },
        );
      },
    );
  }
}

// ==============================================================================
// 3. INITIAL SETUP (One Time)
// ==============================================================================

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});
  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  String _mode = 'mixed';

  Future<void> _saveConfig() async {
    await FirebaseFirestore.instance.collection('config').doc('main').set({
      'mode': _mode, 'setupDone': true, 'locked': true, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 64, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text("Welcome to Fest Manager", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Choose your fest mode to continue.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              _optionCard("Mixed (Boys & Girls)", "Separate filters for gender.", 'mixed'),
              const SizedBox(height: 10),
              _optionCard("Boys Only", "No gender filters needed.", 'boys'),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveConfig, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("START APPLICATION"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard(String title, String subt, String val) {
    bool selected = _mode == val;
    return GestureDetector(
      onTap: () => setState(() => _mode = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo.shade50 : Colors.white,
          border: Border.all(color: selected ? Colors.indigo : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Colors.indigo : Colors.grey),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.indigo : Colors.black87)),
            Text(subt, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])
        ]),
      ),
    );
  }
}

// ==============================================================================
// 4. MAIN DASHBOARD (4 Tabs Navigation)
// ==============================================================================

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _idx = 0;
  
  // 4 പ്രധാന പേജുകൾ
  final List<Widget> _screens = [
    const DashboardTab(),
    const EventsView(),
    const RegistrationView(), // Students List & Add
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: Colors.white,
        elevation: 5,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==============================================================================
// 5. SETTINGS VIEW (Master Data Management)
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

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings & Config")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TEAMS MANAGEMENT
            const Text("Manage Teams", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            _buildManager("Teams", "teams", _teamCtrl, hasColor: true),
            
            const SizedBox(height: 24),
            
            // 2. CATEGORIES MANAGEMENT
            const Text("Manage Categories", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            _buildManager("Categories", "categories", _catCtrl, hasColor: false),

            const SizedBox(height: 24),

            // 3. CHEST NUMBER MATRIX
            const Text("Chest Number Starting Points", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            _buildChestMatrix(),

            const SizedBox(height: 40),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _resetAll(),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("Reset All Data", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _resetAll() async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("RESET EVERYTHING?"), content: const Text("This will delete all students and events. Cannot be undone."), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("RESET"))])) ?? false;
    if(confirm) {
      await db.collection('config').doc('main').delete(); // Force Re-setup
    }
  }

  Widget _buildManager(String title, String coll, TextEditingController ctrl, {required bool hasColor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: "Add New ${title.substring(0, title.length-1)}"))),
              const SizedBox(width: 10),
              if(hasColor) ...[
                DropdownButtonHideUnderline(
                  child: DropdownButton<Color>(
                    value: _selectedColor,
                    items: _colors.map((c) => DropdownMenuItem(value: c, child: CircleAvatar(backgroundColor: c, radius: 8))).toList(),
                    onChanged: (c) => setState(() => _selectedColor = c!),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton(
                onPressed: () {
                  if(ctrl.text.isNotEmpty) {
                    db.collection(coll).add({'name': ctrl.text, if(hasColor)'color': _selectedColor.value, 'createdAt': DateTime.now().millisecondsSinceEpoch});
                    ctrl.clear();
                    _showToast("Saved");
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                child: const Text("Add"),
              )
            ]),
            const Divider(height: 30),
            StreamBuilder<QuerySnapshot>(
              stream: db.collection(coll).orderBy('createdAt').snapshots(),
              builder: (ctx, snap) {
                if(!snap.hasData) return const SizedBox();
                return Wrap(
                  spacing: 8, runSpacing: 8,
                  children: snap.data!.docs.map((d) => Chip(
                    avatar: hasColor ? CircleAvatar(backgroundColor: Color(d['color']), radius: 8) : null,
                    label: Text(d['name']),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _confirmDelete(d.reference),
                  )).toList(),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChestMatrix() {
    return StreamBuilder(
      stream: db.collection('teams').snapshots(),
      builder: (ctx, tSnap) => StreamBuilder(
        stream: db.collection('categories').snapshots(),
        builder: (ctx, cSnap) => StreamBuilder<DocumentSnapshot>(
          stream: db.collection('config').doc('chest_ranges').snapshots(),
          builder: (ctx, rSnap) {
            if(!tSnap.hasData || !cSnap.hasData) return const SizedBox();
            final ranges = rSnap.hasData && rSnap.data!.exists ? rSnap.data!.data() as Map<String,dynamic> : {};
            return Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [const DataColumn(label: Text("Category")), ...tSnap.data!.docs.map((t) => DataColumn(label: Text(t['name'], style: TextStyle(color: Color(t['color'])))))],
                  rows: cSnap.data!.docs.map((c) {
                    return DataRow(cells: [
                      DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      ...tSnap.data!.docs.map((t) {
                        String key = "${t.id}_${c.id}";
                        return DataCell(SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: (ranges[key] ?? 0).toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
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
        ),
      ),
    );
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete?"), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("No")), ElevatedButton(onPressed: (){ref.delete(); Navigator.pop(c);}, child: const Text("Yes"))]));
  }
}

// ==============================================================================
// 6. STUDENTS VIEW (List & Add)
// ==============================================================================

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final db = FirebaseFirestore.instance;
  bool _isFormVisible = false;
  bool _isBulk = false;
  final _nameCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  String? _teamId, _catId, _gender = 'male';
  int _nextChest = 0;

  void _calculateChest(List<QueryDocumentSnapshot> students, Map<String, dynamic> ranges) {
    if(_teamId == null || _catId == null) { setState(() => _nextChest = 0); return; }
    int start = ranges["${_teamId}_$_catId"] ?? 0;
    int count = students.where((s) => s['teamId'] == _teamId && s['categoryId'] == _catId).length;
    setState(() => _nextChest = start + count);
  }

  Future<void> _submit() async {
    if(_teamId == null || _catId == null) return;
    int chest = _nextChest;
    WriteBatch batch = db.batch();

    if(_isBulk) {
      List<String> names = _bulkCtrl.text.split('\n').where((e)=>e.trim().isNotEmpty).toList();
      for(var n in names) {
        batch.set(db.collection('students').doc(), {'name': n.trim(), 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender, 'chestNo': chest++, 'createdAt': FieldValue.serverTimestamp()});
      }
    } else {
      if(_nameCtrl.text.isEmpty) return;
      batch.set(db.collection('students').doc(), {'name': _nameCtrl.text, 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender, 'chestNo': chest, 'createdAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    setState(() => _isFormVisible = false); _nameCtrl.clear(); _bulkCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Students Directory"), actions: [IconButton(icon: Icon(_isFormVisible ? Icons.close : Icons.person_add), onPressed: () => setState(() => _isFormVisible = !_isFormVisible))]),
      body: Column(
        children: [
          if(_isFormVisible)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: StreamBuilder(stream: db.collection('teams').snapshots(), builder: (c,s) => _dropdown(s, "Team", _teamId, (v)=>setState(()=>_teamId=v)))),
                      const SizedBox(width: 10),
                      Expanded(child: StreamBuilder(stream: db.collection('categories').snapshots(), builder: (c,s) => _dropdown(s, "Category", _catId, (v)=>setState(()=>_catId=v)))),
                    ]),
                    const SizedBox(height: 10),
                    StreamBuilder<DocumentSnapshot>(stream: db.collection('config').doc('main').snapshots(), builder: (c,s) {
                      if(s.hasData && s.data!.get('mode')=='boys') return const SizedBox();
                      return Row(children: [const Text("Gender: "), Radio(value: 'male', groupValue: _gender, onChanged: (v)=>setState(()=>_gender=v.toString())), const Text("Boy"), Radio(value: 'female', groupValue: _gender, onChanged: (v)=>setState(()=>_gender=v.toString())), const Text("Girl")]);
                    }),
                    Row(children: [TextButton(onPressed: ()=>setState(()=>_isBulk=false), child: Text("Single", style: TextStyle(fontWeight: !_isBulk?FontWeight.bold:FontWeight.normal))), TextButton(onPressed: ()=>setState(()=>_isBulk=true), child: Text("Bulk", style: TextStyle(fontWeight: _isBulk?FontWeight.bold:FontWeight.normal)))]),
                    if(_isBulk) TextField(controller: _bulkCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Paste Names (New Line)"))
                    else TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Student Name")),
                    const SizedBox(height: 10),
                    StreamBuilder(stream: db.collection('students').snapshots(), builder: (c,s)=>StreamBuilder(stream: db.collection('config').doc('chest_ranges').snapshots(), builder: (c,r){
                      if(s.hasData && r.hasData) WidgetsBinding.instance.addPostFrameCallback((_) => _calculateChest(s.data!.docs, r.data!.data() as Map<String,dynamic>));
                      return Text("Next Chest No: $_nextChest", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo));
                    })),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: const Text("Register")))
                  ],
                ),
              ),
            ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('students').orderBy('createdAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if(!snap.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (c,i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    var d = snap.data!.docs[i];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                      leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: Text("${d['chestNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
                      title: Text(d['name']),
                      subtitle: Text(d['gender'].toString().toUpperCase()),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>d.reference.delete()),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
  Widget _dropdown(AsyncSnapshot snap, String hint, String? val, Function(String?) chg) => DropdownButtonFormField(value: val, decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 10), labelText: hint), items: snap.hasData ? (snap.data!.docs as List).map((d) => DropdownMenuItem(value: d.id as String, child: Text(d['name']))).toList() : [], onChanged: chg);
}

// ==============================================================================
// 7. EVENTS VIEW
// ==============================================================================

class EventsView extends StatefulWidget {
  const EventsView({super.key});
  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final db = FirebaseFirestore.instance;
  final _nameCtrl = TextEditingController();
  String _type = 'single', _stage = 'off-stage'; 
  final _pts1 = TextEditingController(text: '5'), _pts2 = TextEditingController(text: '3'), _pts3 = TextEditingController(text: '1');

  void _addEvent() {
    if(_nameCtrl.text.isEmpty) return;
    db.collection('events').add({'name': _nameCtrl.text, 'type': _type, 'stage': _stage, 'pts': [int.parse(_pts1.text), int.parse(_pts2.text), int.parse(_pts3.text)], 'createdAt': DateTime.now().millisecondsSinceEpoch});
    _nameCtrl.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Events List")),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text("New Event"),
        onPressed: () => showDialog(context: context, builder: (c) => AlertDialog(
          title: const Text("Add Event"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _dd("Type", _type, ['single', 'group'], (v)=>setState(()=>_type=v!))), const SizedBox(width: 10), Expanded(child: _dd("Stage", _stage, ['off-stage', 'on-stage'], (v)=>setState(()=>_stage=v!)))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: _pts1, decoration: const InputDecoration(labelText: "1st"))), const SizedBox(width: 5), Expanded(child: TextField(controller: _pts2, decoration: const InputDecoration(labelText: "2nd"))), const SizedBox(width: 5), Expanded(child: TextField(controller: _pts3, decoration: const InputDecoration(labelText: "3rd")))]),
          ]),
          actions: [ElevatedButton(onPressed: _addEvent, child: const Text("Save"))],
        )),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('events').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if(!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              var e = snap.data!.docs[i];
              return Card(
                child: ListTile(
                  title: Text(e['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${e['type'].toString().toUpperCase()}  •  ${e['stage']}"),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: ()=>e.reference.delete()),
                ),
              );
            },
          );
        },
      ),
    );
  }
  Widget _dd(String l, String v, List<String> i, Function(String?) c) => DropdownButtonFormField(value: v, decoration: InputDecoration(labelText: l), items: i.map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: c);
}

// ==============================================================================
// 8. DASHBOARD (Stats)
// ==============================================================================

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c,s) {
              int count = s.hasData ? s.data!.docs.length : 0;
              return _statCard("Total Students", count.toString(), Colors.blue, Icons.people);
            }),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(stream: db.collection('events').snapshots(), builder: (c,s) {
              int count = s.hasData ? s.data!.docs.length : 0;
              return _statCard("Total Events", count.toString(), Colors.orange, Icons.emoji_events);
            }),
            const SizedBox(height: 20),
            const Text("House Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(stream: db.collection('teams').snapshots(), builder: (c,tSnap) => StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c,sSnap) {
              if(!tSnap.hasData || !sSnap.hasData) return const SizedBox();
              return Column(children: tSnap.data!.docs.map((t) {
                int count = sSnap.data!.docs.where((s)=>s['teamId']==t.id).length;
                return Card(child: ListTile(leading: CircleAvatar(backgroundColor: Color(t['color']), radius: 10), title: Text(t['name']), trailing: Text("$count Students", style: const TextStyle(fontWeight: FontWeight.bold))));
              }).toList());
            }))
          ],
        ),
      ),
    );
  }
  Widget _dropdown(AsyncSnapshot snap, String hint, String? val, void Function(String?)? chg) {
  if (!snap.hasData) return const SizedBox();
  
  // Extract items ensuring they are strings
  List<DropdownMenuItem<String>> items = [];
  if (snap.data != null && snap.data!.docs.isNotEmpty) {
    items = (snap.data!.docs as List).map((d) {
      return DropdownMenuItem<String>(
        value: d.id.toString(),
        child: Text(d['name'].toString()),
      );
    }).toList();
  }

  return DropdownButtonFormField<String>(
    value: val,
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      labelText: hint,
    ),
    items: items,
    onChanged: chg,
  );
}