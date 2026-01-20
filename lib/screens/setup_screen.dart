import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
                const Text("Fest Manager Setup", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Select the competition mode. This cannot be changed later.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
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
