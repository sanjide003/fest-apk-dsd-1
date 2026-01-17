import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. MAIN ENTRY POINT
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ഫയർബേസ് കണക്ട് ചെയ്യുന്നു
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
  runApp(const FestManagerApp());
}

class FestManagerApp extends StatelessWidget {
  const FestManagerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'College Fest',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const AuthWrapper(),
    );
  }
}

// 2. AUTHENTICATION WRAPPER
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
    // അഡ്മിൻ ലോഗിൻ (Anonymous)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const MainScreen();
        return const Scaffold(
          body: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Connecting to Database...")
            ],
          )),
        );
      },
    );
  }
}

// 3. MAIN DASHBOARD SCREEN
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  static const List<Widget> _pages = <Widget>[
    DashboardTab(),
    RegistrationTab(),
    EventsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fest Manager'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Register'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Events'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// 4. HOME DASHBOARD TAB
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard(db.collection('students'), 'Students', Colors.blue),
              const SizedBox(width: 10),
              _statCard(db.collection('events'), 'Events', Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Recent Registrations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('students').orderBy('createdAt', descending: true).limit(10).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) => Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${doc['chestNo']}")),
                      title: Text(doc['name']),
                      subtitle: Text("Cat: ${doc['category']}"),
                    ),
                  )).toList(),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _statCard(CollectionReference col, String title, Color color) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
            child: Column(
              children: [
                Text("$count", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: TextStyle(color: color)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 5. REGISTRATION TAB
class RegistrationTab extends StatefulWidget {
  const RegistrationTab({super.key});
  @override
  State<RegistrationTab> createState() => _RegistrationTabState();
}

class _RegistrationTabState extends State<RegistrationTab> {
  final _nameCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final db = FirebaseFirestore.instance;
  
  // സിമ്പിൾ ചെസ്റ്റ് നമ്പർ ലോജിക് (റാൻഡം നമ്പർ താൽക്കാലികമായി)
  void _register() async {
    if (_nameCtrl.text.isEmpty) return;
    
    // അടുത്ത ചെസ്റ്റ് നമ്പർ എടുക്കുന്നു (നിലവിലുള്ള എണ്ണം + 100)
    final snapshot = await db.collection('students').get();
    final chestNo = 100 + snapshot.docs.length + 1;

    await db.collection('students').add({
      'name': _nameCtrl.text,
      'category': _catCtrl.text.isEmpty ? 'General' : _catCtrl.text,
      'chestNo': chestNo,
      'createdAt': DateTime.now().millisecondsSinceEpoch
    });

    _nameCtrl.clear();
    _catCtrl.clear();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registered: Chest No $chestNo")));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Student Name", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _catCtrl, decoration: const InputDecoration(labelText: "Category (e.g., Senior)", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _register,
              icon: const Icon(Icons.save),
              label: const Text("Register Student"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}

// 6. EVENTS TAB
class EventsTab extends StatefulWidget {
  const EventsTab({super.key});
  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _eventCtrl = TextEditingController();
  final db = FirebaseFirestore.instance;

  void _addEvent() {
    if (_eventCtrl.text.isEmpty) return;
    db.collection('events').add({
      'name': _eventCtrl.text,
      'createdAt': DateTime.now().millisecondsSinceEpoch
    });
    _eventCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: TextField(controller: _eventCtrl, decoration: const InputDecoration(hintText: "New Event Name"))),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 30), onPressed: _addEvent)
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('events').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return ListView(
                children: snapshot.data!.docs.map((doc) => ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(doc['name']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => doc.reference.delete(),
                  ),
                )).toList(),
              );
            },
          ),
        )
      ],
    );
  }
}
