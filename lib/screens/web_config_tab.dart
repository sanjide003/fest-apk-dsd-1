// File: lib/screens/web_config_tab.dart
// Version: 1.0
// Description: വെബ്സൈറ്റ് ക്രമീകരണങ്ങൾ (പേര്, ലോഗോ, സോഷ്യൽ മീഡിയ) നിയന്ത്രിക്കുന്ന പേജ്.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebConfigView extends StatefulWidget {
  const WebConfigView({super.key});
  @override
  State<WebConfigView> createState() => _WebConfigViewState();
}

class _WebConfigViewState extends State<WebConfigView> {
  final db = FirebaseFirestore.instance;

  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _socialIgCtrl = TextEditingController();
  final _socialYtCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
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

  Future<void> _saveConfig() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.language, color: Colors.purple), SizedBox(width: 8), Text("Website Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 20),
                
                TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name (Main Title)")),
                const SizedBox(height: 12),
                
                TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline / Subtitle")),
                const SizedBox(height: 12),
                
                TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL (Image Link)", prefixIcon: Icon(Icons.link))),
                const SizedBox(height: 12),
                
                const Divider(height: 30),
                const Text("Social Media Links", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(child: TextField(controller: _socialIgCtrl, decoration: const InputDecoration(labelText: "Instagram Link", prefixIcon: Icon(Icons.camera_alt, size: 16)))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _socialYtCtrl, decoration: const InputDecoration(labelText: "YouTube Link", prefixIcon: Icon(Icons.video_library, size: 16)))),
                  ],
                ),
                
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveConfig,
                    icon: _isLoading ? const SizedBox() : const Icon(Icons.save),
                    label: Text(_isLoading ? "SAVING..." : "UPDATE WEBSITE"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
