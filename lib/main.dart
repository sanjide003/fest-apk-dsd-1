import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_config.dart';
import 'layout/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FestApp());
}

class FestApp extends StatelessWidget {
  const FestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fest Manager Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo Primary
          surface: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const AuthGuard(),
    );
  }
}

// ലോഗിൻ ചെക്കിംഗും സെറ്റപ്പ് പരിശോധനയും
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
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('config').doc('main').snapshots(),
          builder: (context, configSnap) {
            if (configSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));

            final data = configSnap.data?.data() as Map<String, dynamic>?;
            
            // സെറ്റപ്പ് ചെയ്തിട്ടില്ലെങ്കിൽ Setup Screen കാണിക്കുക
            if (data == null || data['setupDone'] != true) {
              return const InitialSetupScreen();
            }

            return const ResponsiveMainLayout();
          },
        );
      },
    );
  }
}

// ആദ്യ തവണ മാത്രം കാണുന്ന സെറ്റപ്പ് സ്ക്രീൻ
class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});
  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  String _mode = 'mixed';

  Future<void> _saveConfig() async {
    await FirebaseFirestore.instance.collection('config').doc('main').set({
      'mode': _mode,
      'setupDone': true,
      'locked': true, // ലോക്കിംഗ് സിസ്റ്റം
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
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.school_rounded, size: 60, color: Colors.indigo),
                const SizedBox(height: 20),
                const Text("Fest Setup", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Select competition mode. Cannot be changed later.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                _modeOption('Mixed Mode', 'Boys & Girls', Icons.wc, 'mixed'),
                const SizedBox(height: 10),
                _modeOption('Boys Only', 'Single Gender', Icons.male, 'boys'),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveConfig, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("LOCK & START"))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeOption(String title, String sub, IconData icon, String val) {
    bool sel = _mode == val;
    return InkWell(
      onTap: () => setState(() => _mode = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: sel ? Colors.indigo.shade50 : Colors.white, border: Border.all(color: sel ? Colors.indigo : Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(icon, color: sel ? Colors.indigo : Colors.grey), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.indigo : Colors.black)), Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey))])]),
      ),
    );
  }
}
