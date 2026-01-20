import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // For Clipboard

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});
  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final db = FirebaseFirestore.instance;
  final _nameCtrl = TextEditingController();
  String? _teamId, _catId, _gender = 'male';
  
  // CSV Export Logic
  void _exportData(List<QueryDocumentSnapshot> docs) {
    String csv = "ChestNo,Name,Team,Category,Gender\n";
    for (var d in docs) {
      csv += "${d['chestNo']},${d['name']},${d['teamId']},${d['categoryId']},${d['gender']}\n";
    }
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data copied to Clipboard! Paste in Excel.")));
  }

  // ലളിതമായ ആഡ് ലോജിക് (മുമ്പത്തെ പോലെ)
  void _showAddSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
         const Text("Add Student", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 10),
         TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Name")),
         const SizedBox(height: 10),
         // ലളിതമാക്കാൻ ഹാർഡ് കോഡ് ചെയ്യുന്നു. യഥാർത്ഥ ആപ്പിൽ മുൻപത്തെ പോലെ ഡ്രോപ്പ് ഡൗൺ ഉപയോഗിക്കുക
         ElevatedButton(onPressed: (){ 
           // Add Logic here (Refer previous main.dart logic)
           Navigator.pop(context);
         }, child: const Text("Save"))
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _showAddSheet, child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('students').orderBy('createdAt', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () => _exportData(snap.data!.docs),
                  icon: const Icon(Icons.copy),
                  label: const Text("Copy Data for Excel"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (c, i) {
                    var d = snap.data!.docs[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text("${d['chestNo']}")),
                      title: Text(d['name']),
                      subtitle: Text("${d['teamId']} • ${d['categoryId']}"),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
