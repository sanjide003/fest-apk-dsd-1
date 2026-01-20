import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final db = FirebaseFirestore.instance;
  // Web Config Controllers
  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  Future<void> _saveWebConfig() async {
    await db.collection('settings').doc('home_config').set({
      'festName': _festNameCtrl.text,
      'tagline': _taglineCtrl.text,
      'logoUrl': _logoUrlCtrl.text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Website Config Updated!")));
  }

  @override
  void initState() {
    super.initState();
    // Load existing config
    db.collection('settings').doc('home_config').get().then((doc) {
      if(doc.exists) {
        setState(() {
          _festNameCtrl.text = doc['festName'] ?? '';
          _taglineCtrl.text = doc['tagline'] ?? '';
          _logoUrlCtrl.text = doc['logoUrl'] ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Teams & Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Use existing logic here for Teams/Cats management...", style: TextStyle(color: Colors.grey)),
          const Divider(height: 40),
          
          const Text("Public Website Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 15),
          TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name", prefixIcon: Icon(Icons.text_fields))),
          const SizedBox(height: 10),
          TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline", prefixIcon: Icon(Icons.short_text))),
          const SizedBox(height: 10),
          TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo Image URL", prefixIcon: Icon(Icons.link))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveWebConfig, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text("UPDATE WEBSITE"))),
        ],
      ),
    );
  }
}
