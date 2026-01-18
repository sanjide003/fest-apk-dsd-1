import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const AuthGuard(),
    );
  }
}

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
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('config').doc('main').snapshots(),
          builder: (context, configSnap) {
            if (!configSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            final data = configSnap.data!.data() as Map<String, dynamic>?;
            if (data == null || data['setupDone'] != true) return const InitialSetupScreen();
            return const MainDashboard();
          },
        );
      },
    );
  }
}

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});
  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  String _mode = 'mixed';
  bool _isLoading = false;

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final catRef = await FirebaseFirestore.instance.collection('categories').add({'name': 'General', 'createdAt': DateTime.now().millisecondsSinceEpoch});
      await FirebaseFirestore.instance.collection('config').doc('main').set({'mode': _mode, 'setupDone': true, 'locked': true, 'defaultCategoryId': catRef.id, 'createdAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.school_rounded, size: 64, color: Color(0xFF6366F1))),
              const SizedBox(height: 24),
              const Text("Welcome to Fest Manager", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text("Choose your fest mode to continue.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              _optionCard("Mixed (Boys & Girls)", "Separate filters for gender categories.", 'mixed', Icons.people),
              const SizedBox(height: 16),
              _optionCard("Boys Only", "No gender filters needed.", 'boys', Icons.person),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _saveConfig, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("START APPLICATION", style: TextStyle(fontSize: 16)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionCard(String title, String subt, String val, IconData icon) {
    bool selected = _mode == val;
    return InkWell(
      onTap: () => setState(() => _mode = val),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: selected ? const Color(0xFF6366F1).withOpacity(0.08) : Colors.white, border: Border.all(color: selected ? const Color(0xFF6366F1) : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.grey.shade100, shape: BoxShape.circle), child: Icon(icon, color: selected ? const Color(0xFF6366F1) : Colors.grey, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: selected ? const Color(0xFF6366F1) : Colors.black87)), const SizedBox(height: 4), Text(subt, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))])), Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF6366F1) : Colors.grey)]),
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _idx = 0;
  final List<Widget> _screens = [const DashboardTab(), const EventsView(), const RegistrationView(), const SettingsView()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: const Color(0xFF6366F1).withOpacity(0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF6366F1)), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events, color: Color(0xFF6366F1)), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people, color: Color(0xFF6366F1)), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: Color(0xFF6366F1)), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c, s) => _statCard("Total Students", s.hasData ? s.data!.docs.length.toString() : '0', Colors.blue, Icons.people))), const SizedBox(width: 12), Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('events').snapshots(), builder: (c, s) => _statCard("Total Events", s.hasData ? s.data!.docs.length.toString() : '0', Colors.orange, Icons.emoji_events)))]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('teams').snapshots(), builder: (c, s) => _statCard("Total Teams", s.hasData ? s.data!.docs.length.toString() : '0', Colors.green, Icons.flag))), const SizedBox(width: 12), Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('categories').snapshots(), builder: (c, s) => _statCard("Categories", s.hasData ? s.data!.docs.length.toString() : '0', Colors.purple, Icons.category)))]),
            const SizedBox(height: 24),
            const Text("Team-wise Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(stream: db.collection('teams').snapshots(), builder: (c, tSnap) => StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c, sSnap) {
              if (!tSnap.hasData || !sSnap.hasData) return const SizedBox();
              return Column(children: tSnap.data!.docs.map((t) {
                int count = sSnap.data!.docs.where((s) => s['teamId'] == t.id).length;
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: CircleAvatar(backgroundColor: Color(t['color']), radius: 20), title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Color(t['color']).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("$count Students", style: TextStyle(fontWeight: FontWeight.bold, color: Color(t['color']))))));
              }).toList());
            })),
            const SizedBox(height: 24),
            const Text("Category-wise Distribution", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(stream: db.collection('categories').snapshots(), builder: (c, catSnap) => StreamBuilder<QuerySnapshot>(stream: db.collection('students').snapshots(), builder: (c, sSnap) {
              if (!catSnap.hasData || !sSnap.hasData) return const SizedBox();
              return Column(children: catSnap.data!.docs.map((cat) {
                int count = sSnap.data!.docs.where((s) => s['categoryId'] == cat.id).length;
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFF6366F1), child: Icon(Icons.category, color: Colors.white, size: 20)), title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("$count Students", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))))));
              }).toList());
            })),
            const SizedBox(height: 24),
            const Text("Events per Category", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(stream: db.collection('categories').snapshots(), builder: (c, catSnap) => StreamBuilder<QuerySnapshot>(stream: db.collection('events').snapshots(), builder: (c, eSnap) {
              if (!catSnap.hasData || !eSnap.hasData) return const SizedBox();
              return Column(children: catSnap.data!.docs.map((cat) {
                int count = eSnap.data!.docs.where((e) => e['categoryId'] == cat.id).length;
                return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.emoji_events, color: Colors.white, size: 20)), title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("$count Events", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)))));
              }).toList());
            })),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center)])));
  }
}

class EventsView extends StatefulWidget {
  const EventsView({super.key});
  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final db = FirebaseFirestore.instance;

  void _showEventDialog({DocumentSnapshot? event}) {
    showDialog(context: context, builder: (context) => EventDialog(event: event));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Events", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text("New Event"), backgroundColor: const Color(0xFF6366F1), onPressed: () => _showEventDialog()),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('events').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text("No events yet", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)), const SizedBox(height: 8), Text("Tap the + button to add your first event", style: TextStyle(color: Colors.grey.shade500))]));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) => _buildEventCard(snap.data!.docs[i]));
        },
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot event) {
    final data = event.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEventDialog(event: event),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text(data['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.edit, size: 20), color: const Color(0xFF6366F1), onPressed: () => _showEventDialog(event: event)), IconButton(icon: const Icon(Icons.delete, size: 20), color: Colors.red, onPressed: () => _confirmDelete(event.reference))]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [_chip(data['type'].toString().toUpperCase(), Colors.blue, Icons.group), _chip(data['stage'], Colors.purple, Icons.stage), if (data['gender'] != null) _chip(data['gender'].toString().toUpperCase(), data['gender'] == 'boys' ? Colors.indigo : data['gender'] == 'girls' ? Colors.pink : Colors.orange, data['gender'] == 'boys' ? Icons.male : data['gender'] == 'girls' ? Icons.female : Icons.people)]),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot>(stream: db.collection('categories').doc(data['categoryId']).snapshots(), builder: (context, catSnap) {
                String catName = catSnap.hasData ? (catSnap.data!.data() as Map<String, dynamic>)['name'] : 'Loading...';
                return Row(children: [const Icon(Icons.category, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(catName, style: TextStyle(color: Colors.grey.shade600))]);
              }),
              const Divider(height: 24),
              Row(children: [const Text("Points: ", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), _pointBadge("1st", data['pts'][0], Colors.amber), const SizedBox(width: 8), _pointBadge("2nd", data['pts'][1], Colors.grey), const SizedBox(width: 8), _pointBadge("3rd", data['pts'][2], Colors.brown)]),
              const SizedBox(height: 8),
              if (data['type'] == 'single') Text("Participants: ${data['participantLimit'] ?? 3} per team", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)) else Text("Groups: ${data['groupCount'] ?? 2} × ${data['membersPerGroup'] ?? 5} members", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]));
  Widget _pointBadge(String label, int points, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Text("$label: $points", style: TextStyle(color: color.shade700, fontSize: 12, fontWeight: FontWeight.bold)));

  void _confirmDelete(DocumentReference ref) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Event?"), content: const Text("This action cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () {ref.delete(); Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted successfully")));}, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete"))]));
  }
}

class EventDialog extends StatefulWidget {
  final DocumentSnapshot? event;
  const EventDialog({super.key, this.event});
  @override
  State<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final db = FirebaseFirestore.instance;
  final _nameCtrl = TextEditingController();
  final _pts1Ctrl = TextEditingController(text: '5');
  final _pts2Ctrl = TextEditingController(text: '3');
  final _pts3Ctrl = TextEditingController(text: '1');
  final _participantLimitCtrl = TextEditingController(text: '3');
  final _groupCountCtrl = TextEditingController(text: '2');
  final _membersPerGroupCtrl = TextEditingController(text: '5');
  String _type = 'single', _stage = 'off-stage';
  String? _gender, _categoryId;
  bool _isMixed = false, _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    if (widget.event != null) _loadEventData();
  }

  Future<void> _loadConfig() async {
    final config = await db.collection('config').doc('main').get();
    if (config.exists && mounted) setState(() => _isMixed = config.data()?['mode'] == 'mixed');
  }

  void _loadEventData() {
    final data = widget.event!.data() as Map<String, dynamic>;
    _nameCtrl.text = data['name'];
    _type = data['type'];
    _stage = data['stage'];
    _gender = data['gender'];
    _categoryId = data['categoryId'];
    _pts1Ctrl.text = data['pts'][0].toString();
    _pts2Ctrl.text = data['pts'][1].toString();
    _pts3Ctrl.text = data['pts'][2].toString();
    if (data['type'] == 'single') _participantLimitCtrl.text = (data['participantLimit'] ?? 3).toString(); else {_groupCountCtrl.text = (data['groupCount'] ?? 2).toString(); _membersPerGroupCtrl.text = (data['membersPerGroup'] ?? 5).toString();}
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _categoryId == null) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields"))); return;}
    if (_isMixed && _gender == null) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select gender category"))); return;}
    setState(() => _isLoading = true);
    final data = {'name': _nameCtrl.text, 'type': _type, 'stage': _stage, 'gender': _gender, 'categoryId': _categoryId, 'pts': [int.parse(_pts1Ctrl.text), int.parse(_pts2Ctrl.text), int.parse(_pts3Ctrl.text)], if (_type == 'single') 'participantLimit': int.parse(_participantLimitCtrl.text) else ..{'groupCount': int.parse(_groupCountCtrl.text), 'membersPerGroup': int.parse(_membersPerGroupCtrl.text)}, 'createdAt': widget.event == null ? DateTime.now().millisecondsSinceEpoch : (widget.event!.data() as Map<String, dynamic>)['createdAt']};
    try {
      if (widget.event == null) await db.collection('events').add(data); else await widget.event!.reference.update(data);
      if (mounted) {Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.event == null ? "Event created successfully" : "Event updated successfully")));}
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.event == null ? "Add New Event" : "Edit Event", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Event Name *")),
                const SizedBox(height: 16),
                Row(children: [Expanded(child: _dropdown("Type", _type, ['single', 'group'], (v) => setState(() => _type = v!))), const SizedBox(width: 12), Expanded(child: _dropdown("Stage", _stage, ['off-stage', 'on-stage'], (v) => setState(() => _stage = v!)))]),
                const SizedBox(height: 16),
                if (_isMixed) _dropdown("Gender Category *", _gender, ['boys', 'girls', 'open'], (v) => setState(() => _gender = v)),
                if (_isMixed) const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(stream: db.collection('categories').snapshots(), builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return DropdownButtonFormField<String>(value: _categoryId, decoration: const InputDecoration(labelText: "Category *"), items: snap.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(), onChanged: (v) => setState(() => _categoryId = v));
                }),
                const SizedBox(height: 20),
                const Text("Points Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: TextField(controller: _pts1Ctrl, decoration: const InputDecoration(labelText: "1st Place"), keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: TextField(controller: _pts2Ctrl, decoration: const InputDecoration(labelText: "2nd Place"), keyboardType: TextInputType.number)), const SizedBox(width: 8), Expanded(child: TextField(controller: _pts3Ctrl, decoration: const InputDecoration(labelText: "3rd Place"), keyboardType: TextInputType.number))]),
                const SizedBox(height: 20),
                const Text("Participant Limits", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (_type == 'single') TextField(controller: _participantLimitCtrl, decoration: const InputDecoration(labelText: "Participants per Team", hintText: "Default: 3"), keyboardType: TextInputType.number) else Row(children: [Expanded(child: TextField(controller: _groupCountCtrl, decoration: const InputDecoration(labelText: "Number of Groups", hintText: "Default: 2"), keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: TextField(controller: _membersPerGroupCtrl, decoration: const InputDecoration(labelText: "Members per Group", hintText: "Default: 5"), keyboardType: TextInputType.number))]),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), const SizedBox(width: 12), ElevatedButton(onPressed: _isLoading ? null : _save, child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.event == null ? "Create" : "Update"))]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String? value, List<String> items, void Function(String?)? onChanged) {
    return DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged);
  }
}

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final db = FirebaseFirestore.instance;
  bool _isFormVisible = false, _isBulk = false, _isMixed = false;
  final _nameCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  String? _teamId, _catId, _gender = 'male';
  int _nextChest = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await db.collection('config').doc('main').get();
    if (config.exists && mounted) setState(() => _isMixed = config.data()?['mode'] == 'mixed');
  }

  void _calculateChest(List<QueryDocumentSnapshot> students, Map<String, dynamic> ranges) {
    if (_teamId == null || _catId == null) {setState(() => _nextChest = 0); return;}
    String key = _isMixed ? "${_teamId}_${_catId}_$_gender" : "${_teamId}_$_catId";
    int start = ranges[key] ?? 0;
    int count = students.where((s) => s['teamId'] == _teamId && s['categoryId'] == _catId && (!_isMixed || s['gender'] == _gender)).length;
    setState(() => _nextChest = start + count);
  }

  Future<void> _submit() async {
    if (_teamId == null || _catId == null) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Team and Category"))); return;}
    int chest = _nextChest;
    WriteBatch batch = db.batch();
    if (_isBulk) {
      List<String> names = _bulkCtrl.text.split('\n').where((e) => e.trim().isNotEmpty).toList();
      if (names.isEmpty) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter at least one name"))); return;}
      for (var n in names) batch.set(db.collection('students').doc(), {'name': n.trim(), 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender, 'chestNo': chest++, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      if (_nameCtrl.text.isEmpty) {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter student name"))); return;}
      batch.set(db.collection('students').doc(), {'name': _nameCtrl.text, 'teamId': _teamId, 'categoryId': _catId, 'gender': _gender, 'chestNo': chest, 'createdAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
    setState(() {_isFormVisible = false; _isBulk = false;});
    _nameCtrl.clear();
    _bulkCtrl.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Students registered successfully")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Students Directory", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: Icon(_isFormVisible ? Icons.close : Icons.person_add), onPressed: () => setState(() => _isFormVisible = !_isFormVisible))]),
      body: Column(
        children: [
          if (_isFormVisible) Card(margin: const EdgeInsets.all(16), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Add Students", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Row(children: [Expanded(child: StreamBuilder(stream: db.collection('teams').snapshots(), builder: (c, s) => _dropdown(s, "Team", _teamId, (v) => setState(() => _teamId = v)))), const SizedBox(width: 12), Expanded(child: StreamBuilder(stream: db.collection('categories').snapshots(), builder: (c, s) => _dropdown(s, "Category", _catId, (v) => setState(() => _catId = v))))]), if (_isMixed) ...[const SizedBox(height: 16), Row(children: [const Text("Gender: ", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: Row(children: [Radio<String>(value: 'male', groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)), const Text("Boy"), const SizedBox(width: 12), Radio<String>(value: 'female', groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)), const Text("Girl")]))])], const SizedBox(height: 16), Row(children: [TextButton(onPressed: () => setState(() => _isBulk = false), style: TextButton.styleFrom(backgroundColor: !_isBulk ? const Color(0xFF6366F1).withOpacity(0.1) : null), child: Text("Single", style: TextStyle(fontWeight: !_isBulk ? FontWeight.bold : FontWeight.normal, color: !_isBulk ? const Color(0xFF6366F1) : Colors.grey))), const SizedBox(width: 8), TextButton(onPressed: () => setState(() => _isBulk = true), style: TextButton.styleFrom(backgroundColor: _isBulk ? const Color(0xFF6366F1).withOpacity(0.1) : null), child: Text("Bulk", style: TextStyle(fontWeight: _isBulk ? FontWeight.bold : FontWeight.normal, color: _isBulk ? const Color(0xFF6366F1) : Colors.grey)))]), const SizedBox(height: 12), if (_isBulk) TextField(controller: _bulkCtrl, maxLines: 5, decoration: const InputDecoration(labelText: "Paste Names (One per line)", hintText: "Name 1\nName 2\nName 3", alignLabelWithHint: true)) else TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Student Name", hintText: "Enter full name")), const SizedBox(height: 16), StreamBuilder(stream: db.collection('students').snapshots(), builder: (c, s) => StreamBuilder(stream: db.collection('config').doc('chest_ranges').snapshots(), builder: (c, r) {
            if (s.hasData && r.hasData && r.data!.exists) WidgetsBinding.instance.addPostFrameCallback((_) => _calculateChest(s.data!.docs, r.data!.data() as Map<String, dynamic>));
            return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.confirmation_number_outlined, color: Color(0xFF6366F1)), const SizedBox(width: 12), Text("Next Chest No: $_nextChest", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 16))]));
          })), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: const Text("Register")))]))),
          Expanded(child: StreamBuilder<QuerySnapshot>(stream: db.collection('students').orderBy('createdAt', descending: true).snapshots(), builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), Text("No students registered yet", style: TextStyle(fontSize: 18, color: Colors.grey.shade600))]));
            return ListView.separated(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, separatorBuilder: (c, i) => const SizedBox(height: 8), itemBuilder: (ctx, i) => _buildStudentCard(snap.data!.docs[i]));
          })),
        ],
      ),
    );
  }

  Widget _buildStudentCard(DocumentSnapshot student) {
    final data = student.data() as Map<String, dynamic>;
    return Card(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF6366F1).withOpacity(0.15), child: Text("${data['chestNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)))), title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Row(children: [StreamBuilder<DocumentSnapshot>(stream: db.collection('teams').doc(data['teamId']).snapshots(), builder: (context, teamSnap) {
      if (!teamSnap.hasData) return const SizedBox();
      final teamData = teamSnap.data!.data() as Map<String, dynamic>;
      return Row(children: [CircleAvatar(backgroundColor: Color(teamData['color']), radius: 6), const SizedBox(width: 6), Text(teamData['name'])]);
    }), if (_isMixed) ...[const SizedBox(width: 12), Icon(data['gender'] == 'male' ? Icons.male : Icons.female, size: 16, color: data['gender'] == 'male' ? Colors.blue : Colors.pink)]]), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(student.reference))));
  }

  Widget _dropdown(AsyncSnapshot snap, String hint, String? val, void Function(String?)? chg) {
    List<DropdownMenuItem<String>> items = [];
    if (snap.hasData) items = (snap.data!.docs as List).map((d) => DropdownMenuItem<String>(value: d.id.toString(), child: Text(d['name'].toString()))).toList();
    return DropdownButtonFormField<String>(value: val, decoration: InputDecoration(labelText: hint), items: items, onChanged: chg);
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Student?"), content: const Text("This action cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () {ref.delete(); Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student deleted successfully")));}, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete"))]));
  }
}

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
  bool _isMixed = false;
  final List<Color> _colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.brown, Colors.indigo, Colors.amber];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await db.collection('config').doc('main').get();
    if (config.exists && mounted) setState(() => _isMixed = config.data()?['mode'] == 'mixed');
  }

  void _showToast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings & Config", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage Teams", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            const SizedBox(height: 12),
            _buildManager("Teams", "teams", _teamCtrl, hasColor: true),
            const SizedBox(height: 24),
            const Text("Manage Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            const SizedBox(height: 12),
            _buildManager("Categories", "categories", _catCtrl, hasColor: false),
            const SizedBox(height: 24),
            const Text("Chest Number Starting Points", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
            const SizedBox(height: 12),
            _buildChestMatrix(),
            const SizedBox(height: 40),
            Center(child: OutlinedButton.icon(onPressed: () => _resetAll(), icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text("Reset All Data", style: TextStyle(color: Colors.red)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 2), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _resetAll() async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("RESET EVERYTHING?"), content: const Text("This will delete all students, events, teams, and categories. This action cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("RESET"))])) ?? false;
    if (confirm) await db.collection('config').doc('main').delete();
  }

  Widget _buildManager(String title, String coll, TextEditingController ctrl, {required bool hasColor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(hintText: "Add New ${title.substring(0, title.length - 1)}"))), const SizedBox(width: 10), if (hasColor) ...[DropdownButtonHideUnderline(child: DropdownButton<Color>(value: _selectedColor, items: _colors.map((c) => DropdownMenuItem(value: c, child: CircleAvatar(backgroundColor: c, radius: 10))).toList(), onChanged: (c) => setState(() => _selectedColor = c!))), const SizedBox(width: 10)], ElevatedButton(onPressed: () {if (ctrl.text.isNotEmpty) {db.collection(coll).add({'name': ctrl.text, if (hasColor) 'color': _selectedColor.value, 'createdAt': DateTime.now().millisecondsSinceEpoch}); ctrl.clear(); _showToast("Saved");}}, child: const Text("Add"))]),
            const Divider(height: 30),
            StreamBuilder<QuerySnapshot>(stream: db.collection(coll).orderBy('createdAt').snapshots(), builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox();
              return Wrap(spacing: 8, runSpacing: 8, children: snap.data!.docs.map((d) => Chip(avatar: hasColor ? CircleAvatar(backgroundColor: Color(d['color']), radius: 10) : null, label: Text(d['name']), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () => _confirmDelete(d.reference))).toList());
            })
          ],
        ),
      ),
    );
  }

  Widget _buildChestMatrix() {
    return StreamBuilder(stream: db.collection('teams').snapshots(), builder: (ctx, tSnap) => StreamBuilder(stream: db.collection('categories').snapshots(), builder: (ctx, cSnap) => StreamBuilder<DocumentSnapshot>(stream: db.collection('config').doc('chest_ranges').snapshots(), builder: (ctx, rSnap) {
      if (!tSnap.hasData || !cSnap.hasData) return const SizedBox();
      final ranges = rSnap.hasData && rSnap.data!.exists ? rSnap.data!.data() as Map<String, dynamic> : {};
      
      if (_isMixed) {
        return Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [const DataColumn(label: Text("Category")), ...tSnap.data!.docs.expand((t) => [DataColumn(label: Text("${t['name']} (M)", style: TextStyle(color: Color(t['color'])))), DataColumn(label: Text("${t['name']} (F)", style: TextStyle(color: Color(t['color']))))]).toList()], rows: cSnap.data!.docs.map((c) {
          return DataRow(cells: [DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))), ...tSnap.data!.docs.expand((t) => [DataCell(SizedBox(width: 60, child: TextFormField(initialValue: (ranges["${t.id}_${c.id}_male"] ?? 0).toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (v) => db.collection('config').doc('chest_ranges').set({"${t.id}_${c.id}_male": int.tryParse(v) ?? 0}, SetOptions(merge: true))))), DataCell(SizedBox(width: 60, child: TextFormField(initialValue: (ranges["${t.id}_${c.id}_female"] ?? 0).toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (v) => db.collection('config').doc('chest_ranges').set({"${t.id}_${c.id}_female": int.tryParse(v) ?? 0}, SetOptions(merge: true)))))]).toList()]);
        }).toList())));
      } else {
        return Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: [const DataColumn(label: Text("Category")), ...tSnap.data!.docs.map((t) => DataColumn(label: Text(t['name'], style: TextStyle(color: Color(t['color'])))))], rows: cSnap.data!.docs.map((c) {
          return DataRow(cells: [DataCell(Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold))), ...tSnap.data!.docs.map((t) {
            String key = "${t.id}_${c.id}";
            return DataCell(SizedBox(width: 60, child: TextFormField(initialValue: (ranges[key] ?? 0).toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (v) => db.collection('config').doc('chest_ranges').set({key: int.tryParse(v) ?? 0}, SetOptions(merge: true)))));
          })]);
        }).toList())));
      }
    })));
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete?"), content: const Text("This action cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")), ElevatedButton(onPressed: () {ref.delete(); Navigator.pop(c); _showToast("Deleted");}, child: const Text("Yes"))]));
  }
}