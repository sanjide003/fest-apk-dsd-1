import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb detection
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// ==============================================================================
// 1. MAIN ENTRY & CONFIG
// ==============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with your provided config
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
          seedColor: const Color(0xFF6366F1), // Indigo Primary
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFC), // Slate-50 background
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          scrolledUnderElevation: 2,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const AuthGuard(),
    );
  }
}

// ==============================================================================
// 2. AUTH & SETUP GUARD
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
    // Anonymous Login for Security Rules
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Listen to Config to decide Setup vs Dashboard
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('config').doc('main').snapshots(),
          builder: (context, configSnap) {
            if (configSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final data = configSnap.data?.data() as Map<String, dynamic>?;
            
            // If setup is not done, show Setup Screen
            if (data == null || data['setupDone'] != true) {
              return const InitialSetupScreen();
            }

            // If setup is done, go to Main Dashboard
            return const ResponsiveMainLayout();
          },
        );
      },
    );
  }
}

// ==============================================================================
// 3. INITIAL SETUP SCREEN
// ==============================================================================

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});
  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  String _mode = 'mixed'; // mixed or boys

  Future<void> _saveConfig() async {
    // Lock the mode forever until hard reset
    await FirebaseFirestore.instance.collection('config').doc('main').set({
      'mode': _mode,
      'setupDone': true,
      'locked': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.school_rounded, size: 60, color: Colors.indigo),
                ),
                const SizedBox(height: 30),
                const Text("Fest Manager Setup", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                const Text("Select the competition mode. This cannot be changed later without a full reset.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                const SizedBox(height: 40),
                _modeCard("Mixed Mode", "Boys & Girls (Separate & Common)", Icons.wc, 'mixed'),
                const SizedBox(height: 16),
                _modeCard("Boys Only", "Single Gender Competition", Icons.male, 'boys'),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, elevation: 2),
                    child: const Text("LOCK CONFIGURATION & START", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard(String title, String subt, IconData icon, String val) {
    bool selected = _mode == val;
    return InkWell(
      onTap: () => setState(() => _mode = val),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo.shade50 : Colors.white,
          border: Border.all(color: selected ? Colors.indigo : Colors.grey.shade200, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? [BoxShadow(color: Colors.indigo.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          Icon(icon, size: 30, color: selected ? Colors.indigo : Colors.grey),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: selected ? Colors.indigo : Colors.black87)),
            Text(subt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ])),
          if (selected) const Icon(Icons.check_circle, color: Colors.indigo),
        ]),
      ),
    );
  }
}

// ==============================================================================
// 4. RESPONSIVE MAIN LAYOUT (Web vs Mobile)
// ==============================================================================

class ResponsiveMainLayout extends StatefulWidget {
  const ResponsiveMainLayout({super.key});
  @override
  State<ResponsiveMainLayout> createState() => _ResponsiveMainLayoutState();
}

class _ResponsiveMainLayoutState extends State<ResponsiveMainLayout> {
  int _idx = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = [
    const DashboardTab(),
    const EventsView(),
    const RegistrationView(),
    const SettingsView(),
  ];

  final List<String> _titles = ["Dashboard", "Events Management", "Student Registry", "Settings"];

  @override
  Widget build(BuildContext context) {
    // If Web: Show Floating Header
    if (kIsWeb && MediaQuery.of(context).size.width > 600) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // Main Content with padding for header
            Padding(
              padding: const EdgeInsets.only(top: 90), 
              child: Row(
                children: [
                   // Optional: Side Navigation for very large screens could go here
                   Expanded(child: _screens[_idx]),
                ],
              ),
            ),
            
            // Floating Header
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                constraints: const BoxConstraints(maxWidth: 1200),
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    const Icon(Icons.school, color: Colors.indigo),
                    const SizedBox(width: 12),
                    Text(_titles[_idx], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Spacer(),
                    _webNavItem(0, Icons.dashboard_rounded, "Dash"),
                    _webNavItem(1, Icons.emoji_events_rounded, "Events"),
                    _webNavItem(2, Icons.people_alt_rounded, "Students"),
                    _webNavItem(3, Icons.settings_rounded, "Settings"),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } 
    
    // If Mobile: Standard AppBar & BottomNav
    else {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_titles[_idx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: (){}),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.indigo),
                accountName: Text("Fest Admin"),
                accountEmail: Text("admin@college.edu"),
                currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.indigo)),
              ),
              ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () { setState(()=>_idx=0); Navigator.pop(context); }),
              ListTile(leading: const Icon(Icons.emoji_events), title: const Text("Events"), onTap: () { setState(()=>_idx=1); Navigator.pop(context); }),
              ListTile(leading: const Icon(Icons.people), title: const Text("Students"), onTap: () { setState(()=>_idx=2); Navigator.pop(context); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings), title: const Text("Settings"), onTap: () { setState(()=>_idx=3); Navigator.pop(context); }),
            ],
          ),
        ),
        body: _screens[_idx],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          backgroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black12,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dash'),
            NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Events'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Students'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Config'),
          ],
        ),
      );
    }
  }

  Widget _webNavItem(int index, IconData icon, String label) {
    bool isSel = _idx == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _idx = index),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? Colors.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isSel ? Colors.white : Colors.grey.shade600),
                if (isSel) ...[
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 5. DASHBOARD VIEW
// ==============================================================================

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _liveCountCard(db, "students", "Total Students", Icons.people_alt, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _liveCountCard(db, "events", "Total Events", Icons.emoji_events, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),
          const Text("House Standings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('teams').snapshots(),
            builder: (ctx, tSnap) {
              if(!tSnap.hasData) return const LinearProgressIndicator();
              return StreamBuilder<QuerySnapshot>(
                stream: db.collection('students').snapshots(),
                builder: (ctx, sSnap) {
                  if(!sSnap.hasData) return const SizedBox();
                  var students = sSnap.data!.docs;
                  
                  return Column(
                    children: tSnap.data!.docs.map((t) {
                      int count = students.where((s) => s['teamId'] == t.id).length;
                      Color tColor = Color(t['color']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(width: 4, height: 40, decoration: BoxDecoration(color: tColor, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 16),
                            CircleAvatar(backgroundColor: tColor.withOpacity(0.1), child: Icon(Icons.shield, color: tColor, size: 20)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                              child: Text("$count Students", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }
              );
            }
          )
        ],
      ),
    );
  }

  Widget _liveCountCard(FirebaseFirestore db, String coll, String label, IconData icon, Color color) {
    return StreamBuilder<AggregateQuerySnapshot>(
      stream: db.collection(coll).count().get().asStream(), // Using Count API for efficiency
      builder: (ctx, snap) {
        String count = snap.hasData ? snap.data!.count.toString() : "...";
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.8), size: 28),
              const SizedBox(height: 16),
              Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 6. EVENTS MANAGEMENT
// ==============================================================================

class EventsView extends StatefulWidget {
  const EventsView({super.key});
  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  // Logic remains similar, updated UI to Material 3
  final db = FirebaseFirestore.instance;
  
  // Controllers
  final _nameCtrl = TextEditingController();
  String _type = 'single';
  String _stage = 'off-stage';
  String _participation = 'open';
  final _pts1 = TextEditingController(text: '5');
  final _pts2 = TextEditingController(text: '3');
  final _pts3 = TextEditingController(text: '1');

  // Auto-Update Points Logic
  void _updatePointsDefaults(String type) {
    setState(() {
      _type = type;
      if (type == 'single') {
        _pts1.text = '5'; _pts2.text = '3'; _pts3.text = '1';
      } else {
        _pts1.text = '10'; _pts2.text = '8'; _pts3.text = '5';
      }
    });
  }

  void _addNewEvent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 0),
        child: StatefulBuilder( // Needed to update state inside BottomSheet
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create New Event", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Event Name", prefixIcon: Icon(Icons.edit_outlined))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _sheetDropdown("Type", _type, ['single', 'group'], (v) {
                       setSheetState(() => _type = v!); // Update local sheet state
                       _updatePointsDefaults(v!); // Update controllers
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _sheetDropdown("Stage", _stage, ['off-stage', 'on-stage'], (v) => setSheetState(() => _stage = v!))),
                  ]),
                  const SizedBox(height: 16),
                  _sheetDropdown("Participation", _participation, ['open', 'boys', 'girls'], (v) => setSheetState(() => _participation = v!)),
                  const SizedBox(height: 20),
                  const Text("Points (1st - 2nd - 3rd)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _pts1, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _pts2, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _pts3, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if(_nameCtrl.text.isNotEmpty) {
                          db.collection('events').add({
                            'name': _nameCtrl.text,
                            'type': _type,
                            'stage': _stage,
                            'participation': _participation,
                            'pts': [int.parse(_pts1.text), int.parse(_pts2.text), int.parse(_pts3.text)],
                            'createdAt': FieldValue.serverTimestamp()
                          });
                          Navigator.pop(context);
                          _nameCtrl.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      child: const Text("SAVE EVENT"),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _sheetDropdown(String label, String val, List<String> items, Function(String?) changed) {
    return DropdownButtonFormField<String>(
      value: val,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: changed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewEvent,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("New Event"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('events').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("No events created yet"));
          
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: snap.data!.docs.length,
            itemBuilder: (c, i) {
              var e = snap.data!.docs[i];
              var pts = e['pts'] as List;
              bool isGroup = e['type'] == 'group';
              bool isOnStage = e['stage'] == 'on-stage';
              
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {}, // Future: Open details
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isGroup ? Colors.purple.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(isGroup ? Icons.groups : Icons.person, color: isGroup ? Colors.purple : Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _tag(e['type'].toUpperCase(), Colors.grey.shade200, Colors.black),
                                  const SizedBox(width: 6),
                                  _tag(e['participation'] == 'open' ? 'ALL' : e['participation'].toUpperCase(), Colors.orange.shade50, Colors.orange.shade800),
                                  const SizedBox(width: 6),
                                  if(isOnStage) _tag("STAGE", Colors.red.shade50, Colors.red),
                                ],
                              )
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("PTS", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                            Text("${pts[0]} - ${pts[1]} - ${pts[2]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => e.reference.delete(),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

// ==============================================================================
// 7. STUDENT REGISTRATION & LIST
// ==============================================================================

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  
  bool _isBulk = false;
  String? _selectedTeam;
  String? _selectedCat;
  String _gender = 'male';
  
  // To Calculate Chest No
  int _calculatedChest = 0;
  bool _loadingChest = false;

  void _recalcChest() async {
    if (_selectedTeam == null || _selectedCat == null) return;
    
    setState(() => _loadingChest = true);
    
    // 1. Get Start Value from Matrix
    var configDoc = await db.collection('config').doc('chest_ranges').get();
    Map data = configDoc.exists ? configDoc.data() as Map : {};
    int startVal = data["${_selectedTeam}_$_selectedCat"] ?? 100; // Default 100 if not set

    // 2. Find Max current chest no for this combo
    // Optimization: Order by chestNo descending and limit 1
    var snap = await db.collection('students')
        .where('teamId', isEqualTo: _selectedTeam)
        .where('categoryId', isEqualTo: _selectedCat)
        .orderBy('chestNo', descending: true)
        .limit(1)
        .get();

    int nextVal = startVal;
    if (snap.docs.isNotEmpty) {
      nextVal = (snap.docs.first['chestNo'] as int) + 1;
    }

    if (mounted) {
      setState(() {
        _calculatedChest = nextVal;
        _loadingChest = false;
      });
    }
  }

  Future<void> _submitData() async {
    if (_selectedTeam == null || _selectedCat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select Team & Category")));
      return;
    }

    if (_isBulk && _bulkCtrl.text.isEmpty) return;
    if (!_isBulk && _nameCtrl.text.isEmpty) return;

    WriteBatch batch = db.batch();
    int currentChest = _calculatedChest;

    if (_isBulk) {
      List<String> names = _bulkCtrl.text.split('\n').where((s) => s.trim().isNotEmpty).toList();
      for (var name in names) {
        var doc = db.collection('students').doc();
        batch.set(doc, {
          'name': name.trim(),
          'teamId': _selectedTeam,
          'categoryId': _selectedCat,
          'gender': _gender,
          'chestNo': currentChest++,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      var doc = db.collection('students').doc();
      batch.set(doc, {
        'name': _nameCtrl.text.trim(),
        'teamId': _selectedTeam,
        'categoryId': _selectedCat,
        'gender': _gender,
        'chestNo': currentChest,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    _nameCtrl.clear();
    _bulkCtrl.clear();
    _recalcChest(); // Recalculate for next entry
    
    if (mounted) {
       Navigator.pop(context); // Close bottom sheet
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isBulk ? "Bulk Import Success" : "Student Registered")));
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Wrap with listener to call parent setState or use local logic
          // Simplified: We use parent variables but need to trigger rebuild of sheet
          
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Register Student", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _firestoreDropdown("Team", 'teams', _selectedTeam, (v) {
                      setState(()=>_selectedTeam=v); 
                      setSheetState((){});
                      _recalcChest();
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _firestoreDropdown("Category", 'categories', _selectedCat, (v) {
                      setState(()=>_selectedCat=v); 
                      setSheetState((){});
                      _recalcChest();
                    })),
                  ]),
                  const SizedBox(height: 16),
                  
                  // Gender Toggle (Check Global Config first)
                  StreamBuilder<DocumentSnapshot>(
                    stream: db.collection('config').doc('main').snapshots(),
                    builder: (c, s) {
                      if(s.hasData && s.data!['mode'] == 'boys') return const SizedBox();
                      return Row(
                        children: [
                          const Text("Gender: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          ChoiceChip(label: const Text("Boy"), selected: _gender == 'male', onSelected: (b){ setState(()=>_gender='male'); setSheetState((){}); }),
                          const SizedBox(width: 8),
                          ChoiceChip(label: const Text("Girl"), selected: _gender == 'female', onSelected: (b){ setState(()=>_gender='female'); setSheetState((){}); }),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 16),

                  // Mode Switch
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(child: InkWell(onTap: (){ setState(()=>_isBulk=false); setSheetState((){}); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: !_isBulk?Colors.white:null, borderRadius: BorderRadius.circular(12), boxShadow: !_isBulk?[const BoxShadow(color: Colors.black12, blurRadius: 4)]:[]), child: const Center(child: Text("Single Entry"))))),
                      Expanded(child: InkWell(onTap: (){ setState(()=>_isBulk=true); setSheetState((){}); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _isBulk?Colors.white:null, borderRadius: BorderRadius.circular(12), boxShadow: _isBulk?[const BoxShadow(color: Colors.black12, blurRadius: 4)]:[]), child: const Center(child: Text("Bulk Import"))))),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  if (_isBulk)
                    TextField(controller: _bulkCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "Paste Names (One per line)", alignLabelWithHint: true))
                  else
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Student Name", prefixIcon: Icon(Icons.person))),

                  const SizedBox(height: 16),
                  
                  // Chest Number Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number, color: Colors.indigo),
                        const SizedBox(width: 12),
                        const Text("Next Chest No: ", style: TextStyle(color: Colors.indigo)),
                        if (_loadingChest) 
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        else 
                          Text("$_calculatedChest", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submitData, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text("REGISTER"))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _firestoreDropdown(String label, String coll, String? val, Function(String?) onChange) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection(coll).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        var items = snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'], overflow: TextOverflow.ellipsis))).toList();
        return DropdownButtonFormField<String>(
          value: val,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          items: items,
          onChanged: onChange,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: _showAddSheet, child: const Icon(Icons.person_add)),
      body: Column(
        children: [
          // Filters could go here
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('students').orderBy('createdAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (c,i)=>const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    var d = snap.data!.docs[i];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade50, 
                        foregroundColor: Colors.indigo,
                        child: Text("${d['chestNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future: db.collection('teams').doc(d['teamId']).get(),
                        builder: (c, t) => Text(t.hasData ? t.data!.get('name') : "...", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDel(d.reference)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmDel(DocumentReference ref) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Student?"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
        TextButton(onPressed: (){ ref.delete(); Navigator.pop(c); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ]
    ));
  }
}

// ==============================================================================
// 8. SETTINGS & MATRIX
// ==============================================================================

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;
  final _teamNameCtrl = TextEditingController();
  final _catNameCtrl = TextEditingController();
  Color _selColor = Colors.red;
  
  final List<Color> _colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.brown, Colors.black];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Team Management"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: TextField(controller: _teamNameCtrl, decoration: const InputDecoration(hintText: "Team Name (e.g. Red House)"))),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<Color>(
                        value: _selColor,
                        items: _colors.map((c) => DropdownMenuItem(value: c, child: CircleAvatar(backgroundColor: c, radius: 10))).toList(),
                        onChanged: (c) => setState(() => _selColor = c!),
                      )
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _addTeam, child: const Text("Add"))
                  ]),
                  const SizedBox(height: 16),
                  _buildChipList('teams', true)
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader("Categories"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: TextField(controller: _catNameCtrl, decoration: const InputDecoration(hintText: "Category (e.g. Senior)"))),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _addCat, child: const Text("Add"))
                  ]),
                  const SizedBox(height: 16),
                  _buildChipList('categories', false)
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader("Chest Number Matrix (Starting Values)"),
          const Text("Set the starting chest number for each combination. If empty, defaults to 100.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          _buildMatrix(),

          const SizedBox(height: 40),
          Center(
            child: OutlinedButton.icon(
              onPressed: _resetAll,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text("FACTORY RESET DATA"),
            ),
          )
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)));

  void _addTeam() {
    if(_teamNameCtrl.text.isNotEmpty) {
      db.collection('teams').add({'name': _teamNameCtrl.text, 'color': _selColor.value, 'createdAt': DateTime.now().millisecondsSinceEpoch});
      _teamNameCtrl.clear();
    }
  }

  void _addCat() {
    if(_catNameCtrl.text.isNotEmpty) {
      db.collection('categories').add({'name': _catNameCtrl.text, 'createdAt': DateTime.now().millisecondsSinceEpoch});
      _catNameCtrl.clear();
    }
  }

  Widget _buildChipList(String coll, bool color) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection(coll).orderBy('createdAt').snapshots(),
      builder: (ctx, snap) {
        if(!snap.hasData) return const SizedBox();
        return Wrap(
          spacing: 8,
          children: snap.data!.docs.map((d) => Chip(
            avatar: color ? CircleAvatar(backgroundColor: Color(d['color']), radius: 8) : null,
            label: Text(d['name']),
            onDeleted: () => d.reference.delete(),
          )).toList(),
        );
      },
    );
  }

  Widget _buildMatrix() {
    return StreamBuilder(
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
                Map ranges = (rSnap.hasData && rSnap.data!.exists) ? rSnap.data!.data() as Map : {};
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                      columns: [
                        const DataColumn(label: Text("Category \\ Team", style: TextStyle(fontStyle: FontStyle.italic))),
                        ...tSnap.data!.docs.map((t) => DataColumn(label: Text(t['name'], style: TextStyle(color: Color(t['color']), fontWeight: FontWeight.bold))))
                      ],
                      rows: cSnap.data!.docs.map((c) {
                        return DataRow(
                          cells: [
                            DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                            ...tSnap.data!.docs.map((t) {
                              String key = "${t.id}_${c.id}";
                              int val = ranges[key] ?? 100; // Visual default
                              return DataCell(
                                TextFormField(
                                  initialValue: ranges[key]?.toString() ?? "",
                                  decoration: const InputDecoration(hintText: "100", border: InputBorder.none, isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                     int? newVal = int.tryParse(v);
                                     if(newVal != null) {
                                       db.collection('config').doc('chest_ranges').set({key: newVal}, SetOptions(merge: true));
                                     }
                                  },
                                ),
                              );
                            })
                          ]
                        );
                      }).toList(),
                    ),
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  Future<void> _resetAll() async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("FACTORY RESET"),
      content: const Text("This will wipe ALL students, events, and settings. The app will return to the Initial Setup screen."),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")),
        ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("WIPE EVERYTHING")),
      ]
    )) ?? false;

    if(confirm) {
      // Manual Wipe (In production, use a Cloud Function for this)
      await db.collection('config').doc('main').delete();
      await db.collection('config').doc('chest_ranges').delete();
      
      var s = await db.collection('students').get();
      for(var d in s.docs) await d.reference.delete();
      
      var e = await db.collection('events').get();
      for(var d in e.docs) await d.reference.delete();

      var t = await db.collection('teams').get();
      for(var d in t.docs) await d.reference.delete();

      var c = await db.collection('categories').get();
      for(var d in c.docs) await d.reference.delete();
      
      // Navigate to setup will happen automatically via StreamBuilder
    }
  }
}