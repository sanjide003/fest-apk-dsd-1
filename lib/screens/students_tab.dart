// File: lib/screens/students_tab.dart
// Version: 2.0
// Description: വിദ്യാർത്ഥികളുടെ രജിസ്‌ട്രേഷൻ, ലിസ്റ്റ്, എഡിറ്റിംഗ്, എക്സ്പോർട്ട് എന്നിവ.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// വെബ്ബിൽ ഫയൽ ഡൗൺലോഡ് ചെയ്യാൻ
import 'dart:html' as html;
import 'dart:convert';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final db = FirebaseFirestore.instance;
  
  // ഫിൽറ്ററുകൾ
  String? _filterTeam;
  String? _filterCategory;
  String _searchQuery = "";
  final _searchCtrl = TextEditingController();

  // ഡാറ്റ ലിസ്റ്റുകൾ (Dropdown-ന് വേണ്ടി)
  List<String> _teams = [];
  List<String> _categories = [];
  bool _isMixedMode = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  // സെറ്റിംഗ്സിൽ നിന്ന് ടീമുകളും കാറ്റഗറികളും എടുക്കുന്നു
  void _fetchSettings() {
    db.collection('settings').doc('general').snapshots().listen((snap) {
      if (snap.exists) {
        setState(() {
          _teams = List<String>.from(snap.data()?['teams'] ?? []);
          _categories = List<String>.from(snap.data()?['categories'] ?? []);
        });
      }
    });
    db.collection('config').doc('main').get().then((snap) {
      if (snap.exists) {
        setState(() {
          _isMixedMode = (snap.data()?['mode'] ?? 'mixed') == 'mixed';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- TOP BAR (SEARCH & FILTER) ---
            _buildTopBar(),
            const SizedBox(height: 16),
            
            // --- STUDENT LIST ---
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
      // Add Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddStudentDialog(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("REGISTER STUDENT", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 1. TOP BAR
  Widget _buildTopBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search & Export Buttons
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search by Name or Chest No...",
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = "");
                        },
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                // Export Excel
                IconButton(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.table_view, color: Colors.green),
                  tooltip: "Download Excel (CSV)",
                ),
                // Print/PDF
                IconButton(
                  onPressed: _printList,
                  icon: const Icon(Icons.print, color: Colors.blue),
                  tooltip: "Print List / Save PDF",
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterTeam,
                    decoration: const InputDecoration(labelText: "Filter Team", isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Teams")),
                      ..._teams.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    ],
                    onChanged: (v) => setState(() => _filterTeam = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterCategory,
                    decoration: const InputDecoration(labelText: "Filter Category", isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("All Categories")),
                      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    ],
                    onChanged: (v) => setState(() => _filterCategory = v),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // 2. STUDENT LIST
  Widget _buildStudentList() {
    Query query = db.collection('students').orderBy('chestNo');

    if (_filterTeam != null) query = query.where('teamId', isEqualTo: _filterTeam);
    if (_filterCategory != null) query = query.where('categoryId', isEqualTo: _filterCategory);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Center(child: Text("No students found."));

        // Client-side Search Filtering
        var docs = snap.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          String name = data['name'].toString().toLowerCase();
          String chest = data['chestNo'].toString();
          return name.contains(_searchQuery) || chest.contains(_searchQuery);
        }).toList();

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            
            return ListTile(
              tileColor: Colors.white,
              leading: CircleAvatar(
                backgroundColor: Colors.indigo.shade50,
                foregroundColor: Colors.indigo,
                child: Text(data['chestNo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${data['teamId']} • ${data['categoryId']} ${_isMixedMode ? '• ${data['gender']}' : ''}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _openEditDialog(docId, data),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteStudent(docId, data['name']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==============================================================================
  // 3. REGISTRATION (ADD STUDENT)
  // ==============================================================================
  void _openAddStudentDialog() {
    String? selTeam;
    String? selCat;
    String selGender = 'Male';
    bool isBulk = false;
    
    final nameCtrl = TextEditingController();
    final bulkCtrl = TextEditingController(); // For Bulk Import
    int nextChest = 0;
    bool loadingChest = false;

    // ചെസ്റ്റ് നമ്പർ കണ്ടുപിടിക്കാനുള്ള ഫംഗ്ഷൻ
    Future<void> calcChest(StateSetter setState) async {
      if (selTeam == null || selCat == null) return;
      setState(() => loadingChest = true);

      // 1. Get Start Value from Matrix (settings/general -> chestConfig)
      var settingsSnap = await db.collection('settings').doc('general').get();
      Map chestConfig = settingsSnap.data()?['chestConfig'] ?? {};
      String key = "$selTeam-$selCat";
      int startVal = chestConfig[key] ?? 100; // Default 100 if not set

      // 2. Get Max existing chest no
      var studentSnap = await db.collection('students')
          .where('teamId', isEqualTo: selTeam)
          .where('categoryId', isEqualTo: selCat)
          .orderBy('chestNo', descending: true)
          .limit(1)
          .get();

      if (studentSnap.docs.isNotEmpty) {
        nextChest = (studentSnap.docs.first['chestNo'] as int) + 1;
      } else {
        nextChest = startVal;
      }
      setState(() => loadingChest = false);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Register Student"),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TEAM & CAT Selection
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selTeam,
                          hint: const Text("Team"),
                          items: _teams.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) { setDialogState(() => selTeam = v); calcChest(setDialogState); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selCat,
                          hint: const Text("Category"),
                          items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) { setDialogState(() => selCat = v); calcChest(setDialogState); },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    
                    // Gender (Only if Mixed)
                    if (_isMixedMode)
                      Row(
                        children: [
                          const Text("Gender: "),
                          Radio(value: "Male", groupValue: selGender, onChanged: (v) => setDialogState(() => selGender = v.toString())),
                          const Text("Male"),
                          Radio(value: "Female", groupValue: selGender, onChanged: (v) => setDialogState(() => selGender = v.toString())),
                          const Text("Female"),
                        ],
                      ),
                    
                    const Divider(),

                    // MODE SWITCH (Single vs Bulk)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Bulk Import", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Switch(value: isBulk, onChanged: (v) => setDialogState(() => isBulk = v)),
                      ],
                    ),

                    if (!isBulk) ...[
                      // SINGLE ENTRY
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Student Name", prefixIcon: Icon(Icons.person))),
                      const SizedBox(height: 15),
                      // Chest No Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Assigned Chest No: ", style: TextStyle(color: Colors.indigo)),
                            if (loadingChest)
                              const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              Text("$nextChest", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          ],
                        ),
                      )
                    ] else ...[
                      // BULK ENTRY
                      TextField(
                        controller: bulkCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: "Paste Names (One per line)",
                          hintText: "Arun\nBinu\nCiya",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("Starting Chest No: $nextChest (Will increment automatically)", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (selTeam == null || selCat == null) return;

                  var batch = db.batch();
                  int currentCNo = nextChest;

                  if (isBulk) {
                    // Bulk Save
                    List<String> names = bulkCtrl.text.split('\n').where((s) => s.trim().isNotEmpty).toList();
                    if (names.isEmpty) return;
                    for (var name in names) {
                      var ref = db.collection('students').doc();
                      batch.set(ref, {
                        'name': name.trim(),
                        'teamId': selTeam,
                        'categoryId': selCat,
                        'gender': selGender,
                        'chestNo': currentCNo++,
                        'createdAt': FieldValue.serverTimestamp()
                      });
                    }
                  } else {
                    // Single Save
                    if (nameCtrl.text.isEmpty) return;
                    var ref = db.collection('students').doc();
                    batch.set(ref, {
                      'name': nameCtrl.text.trim(),
                      'teamId': selTeam,
                      'categoryId': selCat,
                      'gender': selGender,
                      'chestNo': currentCNo,
                      'createdAt': FieldValue.serverTimestamp()
                    });
                  }

                  await batch.commit();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful!")));
                },
                child: const Text("Register"),
              )
            ],
          );
        },
      ),
    );
  }

  // ==============================================================================
  // 4. EDIT STUDENT (MANUAL CHEST NO)
  // ==============================================================================
  void _openEditDialog(String docId, Map data) {
    final nameCtrl = TextEditingController(text: data['name']);
    final chestCtrl = TextEditingController(text: data['chestNo'].toString());
    String selTeam = data['teamId'];
    String selCat = data['categoryId'];
    String selGender = data['gender'] ?? 'Male';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Edit Student"),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Student Name")),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField(
                          value: selTeam,
                          items: _teams.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setDialogState(() => selTeam = v.toString()),
                          decoration: const InputDecoration(labelText: "Team"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField(
                          value: selCat,
                          items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setDialogState(() => selCat = v.toString()),
                          decoration: const InputDecoration(labelText: "Category"),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    // Manual Chest No Edit
                    TextField(
                      controller: chestCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Chest No (Manual Edit)",
                        helperText: "Change only if necessary (Duplicates allowed)",
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white
                      ),
                    ),
                    if (_isMixedMode) ...[
                      const SizedBox(height: 10),
                       Row(
                        children: [
                          const Text("Gender: "),
                          Radio(value: "Male", groupValue: selGender, onChanged: (v) => setDialogState(() => selGender = v.toString())),
                          const Text("Male"),
                          Radio(value: "Female", groupValue: selGender, onChanged: (v) => setDialogState(() => selGender = v.toString())),
                          const Text("Female"),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                   await db.collection('students').doc(docId).update({
                     'name': nameCtrl.text,
                     'teamId': selTeam,
                     'categoryId': selCat,
                     'gender': selGender,
                     'chestNo': int.tryParse(chestCtrl.text) ?? data['chestNo'],
                   });
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated Successfully")));
                },
                child: const Text("Update"),
              )
            ],
          );
        },
      ),
    );
  }

  // Delete
  Future<void> _deleteStudent(String docId, String name) async {
    bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Student?"),
      content: Text("Are you sure you want to delete '$name'?"),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text("Cancel")),
        ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete"))
      ],
    )) ?? false;

    if(confirm) {
      await db.collection('students').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted")));
    }
  }

  // ==============================================================================
  // 5. EXPORT & PRINT
  // ==============================================================================
  
  // Excel Export (CSV Format) - Works on Web
  Future<void> _exportToExcel() async {
    var snap = await db.collection('students').orderBy('chestNo').get();
    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export")));
      return;
    }

    // CSV Header
    String csvContent = "Chest No,Name,Team,Category,Gender\n";
    
    // Rows
    for (var doc in snap.docs) {
      var d = doc.data();
      csvContent += "${d['chestNo']},${d['name']},${d['teamId']},${d['categoryId']},${d['gender']}\n";
    }

    // Web Download Logic
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Students_List.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Print List (Browser Native Print -> PDF)
  void _printList() {
    // Web-ൽ പ്രിന്റ് വിൻഡോ തുറക്കുന്നത് വഴി PDF ആയി സേവ് ചെയ്യാം.
    // ലളിതമായ രീതിയിൽ ഇപ്പോൾ കാണുന്ന പേജ് പ്രിന്റ് ചെയ്യും.
    html.window.print();
  }
}