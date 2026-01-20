// File: lib/screens/web_config_tab.dart
// Version: 1.3
// Description: വെബ്സൈറ്റ് ക്രമീകരണങ്ങൾ. Fest Officials-നെയും Team Leaders-നെയും വെവ്വേറെ മാനേജ് ചെയ്യുന്നു.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebConfigView extends StatefulWidget {
  const WebConfigView({super.key});
  @override
  State<WebConfigView> createState() => _WebConfigViewState();
}

class _WebConfigViewState extends State<WebConfigView> {
  final db = FirebaseFirestore.instance;
  bool _isLoading = false;

  // Controllers - Basic Info
  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  
  // Controller - Button Color
  final _btnColorCtrl = TextEditingController(text: "#2563EB"); 
  Color _currentColor = const Color(0xFF2563EB);

  // Controllers - About Section
  final _aboutSubCtrl = TextEditingController();
  final _aboutTextCtrl = TextEditingController();

  // Controllers - Social Media
  final _waCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _ytCtrl = TextEditingController();
  final _tgCtrl = TextEditingController();

  // Fest Officials List (Local State for home_config)
  List<Map<String, dynamic>> _officials = [];
  // Gallery List
  List<String> _gallery = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // home_config ഡാറ്റ ലോഡ് ചെയ്യുന്നു
  void _loadData() {
    db.collection('settings').doc('home_config').get().then((doc) {
      if(doc.exists) {
        var d = doc.data()!;
        setState(() {
          _festNameCtrl.text = d['festName1'] ?? '';
          _taglineCtrl.text = d['tagline'] ?? '';
          _logoUrlCtrl.text = d['logoUrl'] ?? '';
          
          String colorHex = d['btnColor'] ?? '#2563EB';
          _btnColorCtrl.text = colorHex;
          try { _currentColor = Color(int.parse(colorHex.replaceAll('#', '0xFF'))); } catch (e) { _currentColor = Colors.blue; }

          _aboutSubCtrl.text = d['aboutSubtitle'] ?? '';
          _aboutTextCtrl.text = d['aboutText'] ?? '';

          if(d['social'] != null) {
            _waCtrl.text = d['social']['wa'] ?? '';
            _igCtrl.text = d['social']['ig'] ?? '';
            _fbCtrl.text = d['social']['fb'] ?? '';
            _ytCtrl.text = d['social']['yt'] ?? '';
            _tgCtrl.text = d['social']['tg'] ?? '';
          }

          if(d['leaders'] != null) {
            _officials = List<Map<String, dynamic>>.from(d['leaders']);
          }

          if(d['gallery'] != null) {
            _gallery = List<String>.from(d['gallery']);
          }
        });
      }
    });
  }

  // സേവ് ചെയ്യുമ്പോൾ (ടീം ലീഡേഴ്സ് ഒഴികെ ബാക്കിയെല്ലാം home_config-ൽ സേവ് ആകും)
  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    
    Map<String, dynamic> data = {
      'festName1': _festNameCtrl.text,
      'tagline': _taglineCtrl.text,
      'logoUrl': _logoUrlCtrl.text,
      'btnColor': _btnColorCtrl.text,
      'aboutSubtitle': _aboutSubCtrl.text,
      'aboutText': _aboutTextCtrl.text,
      'social': {
        'wa': _waCtrl.text,
        'ig': _igCtrl.text,
        'fb': _fbCtrl.text,
        'yt': _ytCtrl.text,
        'tg': _tgCtrl.text,
      },
      'leaders': _officials, // Fest Officials
      'gallery': _gallery,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await db.collection('settings').doc('home_config').set(data, SetOptions(merge: true));
    
    setState(() => _isLoading = false);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Website Configuration Updated Successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // സേവ് ബട്ടൺ (പച്ച നിറത്തിൽ)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveConfig,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: _isLoading ? const SizedBox() : const Icon(Icons.save),
        label: Text(_isLoading ? "SAVING..." : "SAVE ALL CHANGES"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBasicSection(),
            const SizedBox(height: 20),
            _buildAboutSection(),
            const SizedBox(height: 20),
            _buildSocialSection(),
            const SizedBox(height: 20),
            
            // 1. FEST OFFICIALS SECTION
            _buildOfficialsSection(),
            const SizedBox(height: 20),

            // 2. TEAM LEADERS SECTION (Synced with Settings)
            _buildTeamLeadersSection(),
            const SizedBox(height: 20),
            
            _buildGallerySection(),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  // --- 1. BASIC INFO ---
  Widget _buildBasicSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Branding & Colors", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 16),
            TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name")),
            const SizedBox(height: 10),
            TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
            const SizedBox(height: 10),
            TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL", prefixIcon: Icon(Icons.link))),
            const SizedBox(height: 10),
            Row(children: [
              const Text("Button Color: "),
              InkWell(onTap: _pickColor, child: Container(width: 30, height: 30, color: _currentColor)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _btnColorCtrl, decoration: const InputDecoration(labelText: "Hex Code"), onChanged: (v){ try{setState(()=>_currentColor=Color(int.parse(v.replaceAll('#','0xFF'))));}catch(e){}}))
            ])
          ],
        ),
      ),
    );
  }

  void _pickColor() {
    // ലളിതമായ കളർ പിക്കർ
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Pick Color"),
      content: Wrap(spacing: 5, children: [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple].map((co) => InkWell(onTap: (){ setState((){ _currentColor=co; _btnColorCtrl.text='#${co.value.toRadixString(16).substring(2).toUpperCase()}'; }); Navigator.pop(c); }, child: CircleAvatar(backgroundColor: co))).toList()),
    ));
  }

  // --- 2. ABOUT & SOCIAL ---
  Widget _buildAboutSection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       const Text("About Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
       const SizedBox(height: 10),
       TextField(controller: _aboutSubCtrl, decoration: const InputDecoration(labelText: "Subtitle")),
       const SizedBox(height: 10),
       TextField(controller: _aboutTextCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
    ])));
  }

  Widget _buildSocialSection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       const Text("Social Links", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
       const SizedBox(height: 10),
       TextField(controller: _waCtrl, decoration: const InputDecoration(labelText: "WhatsApp", prefixIcon: Icon(Icons.chat))),
       const SizedBox(height: 10),
       TextField(controller: _igCtrl, decoration: const InputDecoration(labelText: "Instagram", prefixIcon: Icon(Icons.camera_alt))),
       // FB, YT, TG can be added similarly if space permits
    ])));
  }

  // --- 3. FEST OFFICIALS (home_config) ---
  Widget _buildOfficialsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Fest Officials", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo), onPressed: () => _editOfficial())
            ]),
            const Text("General committee members (Chairman, Convener etc.)", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = _officials.removeAt(oldIdx);
                  _officials.insert(newIdx, item);
                });
              },
              children: [
                for (int i = 0; i < _officials.length; i++)
                  ListTile(
                    key: ValueKey(_officials[i]['name'] + i.toString()),
                    leading: const Icon(Icons.drag_handle, color: Colors.grey),
                    title: Text(_officials[i]['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(_officials[i]['name']),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                       IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _editOfficial(index: i)),
                       IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => setState(() => _officials.removeAt(i))),
                    ]),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  void _editOfficial({int? index}) {
    final nameCtrl = TextEditingController(text: index != null ? _officials[index!]['name'] : '');
    final roleCtrl = TextEditingController(text: index != null ? _officials[index!]['role'] : '');
    final imgCtrl = TextEditingController(text: index != null ? _officials[index!]['img'] : '');

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(index == null ? "Add Official" : "Edit Official"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role (e.g. Chairman)")),
         const SizedBox(height: 10),
         TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
         const SizedBox(height: 10),
         TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL (Optional)")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: (){
          if(nameCtrl.text.isNotEmpty && roleCtrl.text.isNotEmpty) {
            Map<String, dynamic> d = {'name': nameCtrl.text, 'role': roleCtrl.text, 'img': imgCtrl.text};
            setState(() { index == null ? _officials.add(d) : _officials[index] = d; });
            Navigator.pop(c);
          }
        }, child: const Text("Add"))
      ],
    ));
  }

  // --- 4. TEAM LEADERS (Synced with Settings) ---
  Widget _buildTeamLeadersSection() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
               Icon(Icons.groups, color: Colors.blue), 
               SizedBox(width: 8), 
               Text("Team Leaders (Live Sync)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))
            ]),
            const Text("Edits here will automatically update 'Settings > Teams'.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),

            // settings/general-ൽ നിന്ന് ഡാറ്റ ലൈവ് ആയി എടുക്കുന്നു
            StreamBuilder<DocumentSnapshot>(
              stream: db.collection('settings').doc('general').snapshots(),
              builder: (context, snap) {
                if(!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
                Map details = data['teamDetails'] ?? {};
                List teams = data['teams'] ?? [];

                if(teams.isEmpty) return const Text("No teams found in Settings.");

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: teams.length,
                  itemBuilder: (c, i) {
                    String tName = teams[i];
                    Map tData = details[tName] ?? {};
                    List leaders = tData['leaders'] ?? [];
                    int colorVal = tData['color'] ?? 0xFF000000;

                    return ExpansionTile(
                      title: Text(tName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: CircleAvatar(backgroundColor: Color(colorVal), radius: 10),
                      children: [
                        if(leaders.isEmpty) 
                          const Padding(padding: EdgeInsets.all(8.0), child: Text("No leaders added for this team.")),
                        
                        ...leaders.asMap().entries.map((entry) {
                          int lIdx = entry.key;
                          Map leader = entry.value;
                          return ListTile(
                            dense: true,
                            title: Text(leader['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            subtitle: Text(leader['name']),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              onPressed: () {
                                // ടീം ലീഡറെ എഡിറ്റ് ചെയ്യാനുള്ള ഡയലോഗ്
                                _editTeamLeader(tName, lIdx, leader, details, teams);
                              },
                            ),
                          );
                        }).toList()
                      ],
                    );
                  },
                );
              },
            )
          ],
        ),
      ),
    );
  }

  // ടീം ലീഡറെ എഡിറ്റ് ചെയ്യാനും ഓട്ടോമാറ്റിക് ആയി Settings-ൽ അപ്ഡേറ്റ് ചെയ്യാനും
  void _editTeamLeader(String teamName, int index, Map leaderData, Map allDetails, List allTeams) {
    TextEditingController nameCtrl = TextEditingController(text: leaderData['name']);
    TextEditingController roleCtrl = TextEditingController(text: leaderData['role']);

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Edit $teamName Leader"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Position")),
         const SizedBox(height: 10),
         TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Student Name")),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          if(nameCtrl.text.isNotEmpty) {
            // Update logic
            List leaders = List.from(allDetails[teamName]['leaders']);
            leaders[index] = {'role': roleCtrl.text, 'name': nameCtrl.text};
            allDetails[teamName]['leaders'] = leaders;

            await db.collection('settings').doc('general').update({
              'teamDetails': allDetails
            });
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated in Settings!")));
          }
        }, child: const Text("Update"))
      ],
    ));
  }

  // --- 5. GALLERY ---
  Widget _buildGallerySection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
           IconButton(icon: const Icon(Icons.add_photo_alternate), onPressed: _addGallery)
        ]),
        const SizedBox(height: 10),
        ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _gallery.length, itemBuilder: (c,i) => ListTile(
           leading: Image.network(_gallery[i], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error)),
           title: Text(_gallery[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
           trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: ()=>setState(()=>_gallery.removeAt(i))),
        ))
    ])));
  }

  void _addGallery() {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Add Image URL"),
      content: TextField(controller: c),
      actions: [ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { setState(()=>_gallery.add(c.text)); Navigator.pop(ctx); }}, child: const Text("Add"))],
    ));
  }
}
