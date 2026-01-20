// File: lib/main.dart
// Version: 1.0
// Description: ആപ്പിന്റെ പ്രധാന എൻട്രി പോയിന്റ്. ഓതന്റിക്കേഷൻ ചെക്ക് ചെയ്ത് നേരെ ലേഔട്ടിലേക്ക് വിടുന്നു.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_config.dart';
import 'layout/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ഫയർബേസ് ഇനിഷ്യലൈസ് ചെയ്യുന്നു
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
      title: 'Fest Admin Panel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo Primary
          surface: const Color(0xFFF8FAFC),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        // ഇൻപുട്ട് ബോക്സുകളുടെ ഡിസൈൻ
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

// ലോഗിൻ പരിശോധന
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

  // അഡ്മിൻ പാനലിലേക്ക് കയറാൻ Anonymous Login ഉപയോഗിക്കുന്നു
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
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // ലോഗിൻ ആണെങ്കിൽ നേരെ പ്രധാന ലേഔട്ടിലേക്ക്
        return const ResponsiveMainLayout();
      },
    );
  }
}
