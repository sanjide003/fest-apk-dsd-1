// File: lib/screens/web_config_tab.dart
// Version: 9.0
// Description: Fixed Social Media Edit/Remove Issue (Map Mutability Fix). Added logic to remove link if text is empty on save.

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

  // Controllers
  final _festNameCtrl = TextEditingController();
  final _festYearCtrl = TextEditingController(); 
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _btnColorCtrl = TextEditingController(text: "#2563EB"); 
  Color _currentColor = const Color(0xFF2563EB);

  final _aboutSubCtrl = TextEditingController();
  final _aboutTextCtrl = TextEditingController();

  // Social Media Data (Initialized as empty mutable map)
  Map<String, String> _socialLinks = {}; 
  
  // Supported Platforms
  final Map<String, Map<String, dynamic>> _socialMeta = {
    'wa': {'name': 'WhatsApp', 'icon': Icons.message, 'color': Colors.green, 'hint': 'https://wa.me/919876543210'},
    'ig': {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink, 'hint': 'https://instagram.com/username'},
    'yt': {'name': 'YouTube', 'icon': Icons.play_circle_fill, 'color': Colors.red, 'hint': 'https://youtube.com/@channel'},
    'fb': {'name': 'Facebook', 'icon': Icons.facebook, 'color': Colors.blue.shade900, 'hint': 'https://facebook.com/page'},
    'tg': {'name': 'Telegram', 'icon': Icons.send, 'color': Colors.blue, 'hint': 'https://t.me/username'},
  };

  List<Map<String, dynamic>> _officials = [];
  List<String> _gallery = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _fixDriveLink(String url) {
    if (url.contains('drive.google.com')) {
      RegExp regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
      Match? match = regExp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return 'https://lh3.googleusercontent.com/d/${match.group(1)}';
      }
    }
    return url;
  }

  Future<void> _loadData() async {
    try {
      var doc = await db.collection('settings').doc('home_config').get();
      if(doc.exists) {
        var d = doc.data()!;
        if(mounted) {
          setState(() {
            _festNameCtrl.text = d['festName1'] ?? '';
            _festYearCtrl.text = d['festName2'] ?? '';
            _taglineCtrl.text = d['tagline'] ?? '';
            _logoUrlCtrl.text = d['logoUrl'] ?? '';
            
            String colorHex = d['btnColor'] ?? '#2563EB';
            _btnColorCtrl.text = colorHex;
            try { _currentColor = Color(int.parse(colorHex.replaceAll('#', '0xFF'))); } catch (e) { _currentColor = Colors.blue; }

            _aboutSubCtrl.text = d['aboutSubtitle'] ?? '';
            _aboutTextCtrl.text = d['aboutText'] ?? '';

            // FIXED: Ensure Map is Mutable
            if(d['social'] != null) {
              Map<String, dynamic> raw = d['social'];
              _socialLinks = Map<String, String>.from(raw.map((k, v) => MapEntry(k, v.toString())));
            } else {
              _socialLinks = {};
            }
            
            if(d['leaders'] != null) _officials = List<Map<String, dynamic>>.from(d['leaders']);
            if(d['gallery'] != null) _gallery = List<String>.from(d['gallery']);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading config: $e");
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    String fixedLogo = _fixDriveLink(_logoUrlCtrl.text);

    Map<String, dynamic> data = {
      'festName1': _festNameCtrl.text,
      'festName2': _festYearCtrl.text,
      'tagline': _taglineCtrl.text,
      'logoUrl': fixedLogo,
      'btnColor': _btnColorCtrl.text,
      'aboutSubtitle': _aboutSubCtrl.text,
      'aboutText': _aboutTextCtrl.text,
      'social': _socialLinks,
      'leaders': _officials,
      'gallery': _gallery,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await db.collection('settings').doc('home_config').set(data, SetOptions(merge: true));
    if(mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuration Saved Successfully!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            _buildSmartSocialSection(),
            const SizedBox(height: 20),
            _buildOfficialsSection(),
            const SizedBox(height: 20),
            _buildTeamLeadersSection(),
            const SizedBox(height: 20),
            _buildGalleryGrid(),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Text("Branding", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 16),
            TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name (Line 1)")),
            const SizedBox(height: 10),
            TextField(controller: _festYearCtrl, decoration: const InputDecoration(labelText: "Fest Year / Line 2 (e.g. 2k25)")),
            const SizedBox(height: 10),
            TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
            const SizedBox(height: 10),
            TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL", prefixIcon: Icon(Icons.link)), onChanged: (v)=>setState((){})),
            if(_logoUrlCtrl.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Image.network(_fixDriveLink(_logoUrlCtrl.text), height: 50, errorBuilder: (c,e,s)=>const Text("Invalid Image"))),
            const SizedBox(height: 10),
            Row(children: [const Text("Button Color: "), InkWell(onTap: _pickColor, child: Container(width: 30, height: 30, color: _currentColor)), const SizedBox(width: 10), Expanded(child: TextField(controller: _btnColorCtrl, decoration: const InputDecoration(labelText: "Hex Code"), onChanged: (v){ try{setState(()=>_currentColor=Color(int.parse(v.replaceAll('#','0xFF'))));}catch(e){}}))])
          ]
        )
      )
    );
  }

  void _pickColor() {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Pick Color"), content: Wrap(spacing: 5, children: [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple].map((co) => InkWell(onTap: (){ setState((){ _currentColor=co; _btnColorCtrl.text='#${co.value.toRadixString(16).substring(2).toUpperCase()}'; }); Navigator.pop(c); }, child: CircleAvatar(backgroundColor: co))).toList())));
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         const Text("About Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
         const SizedBox(height: 10),
         TextField(controller: _aboutSubCtrl, decoration: const InputDecoration(labelText: "Subtitle")),
         const SizedBox(height: 10),
         TextField(controller: _aboutTextCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
      ]))
    );
  }

  // --- SOCIAL MEDIA SECTION (FIXED) ---
  Widget _buildSmartSocialSection() {
    List<String> activeKeys = _socialLinks.keys.where((k) => _socialMeta.containsKey(k)).toList();
    List<String> availableKeys = _socialMeta.keys.where((k) => !_socialLinks.containsKey(k)).toList();

    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Text("Social Media Links", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 4),
            const Text("Configure links to show on the website footer.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            
            // 1. ACTIVE LINKS
            if (activeKeys.isNotEmpty) ...[
              const Text("Active Links:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: activeKeys.map((key) {
                  var meta = _socialMeta[key]!;
                  return InkWell(
                    onTap: () => _openSocialDialog(key),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                      decoration: BoxDecoration(
                        color: (meta['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: (meta['color'] as Color).withOpacity(0.3))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: meta['color'],
                            child: Icon(meta['icon'], size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(meta['name'], style: TextStyle(fontWeight: FontWeight.bold, color: meta['color'], fontSize: 13)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 12, color: meta['color'])
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 2. AVAILABLE LINKS
            if (availableKeys.isNotEmpty) ...[
              const Text("Add Social Links:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: availableKeys.map((key) {
                  var meta = _socialMeta[key]!;
                  return IconButton.filled(
                    onPressed: () => _openSocialDialog(key),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                    icon: Icon(meta['icon'], color: Colors.grey),
                    tooltip: "Add ${meta['name']}",
                  );
                }).toList(),
              ),
            ]
          ]
        )
      )
    );
  }

  void _openSocialDialog(String key) {
    var meta = _socialMeta[key]!;
    final linkCtrl = TextEditingController(text: _socialLinks[key] ?? '');
    
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Row(children: [
        Icon(meta['icon'], color: meta['color']), 
        const SizedBox(width: 10), 
        Text(meta['name'])
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: linkCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: "${meta['name']} URL",
              hintText: meta['hint'],
              border: const OutlineInputBorder(),
              helperText: "Leave empty to remove",
              isDense: true
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        if (_socialLinks.containsKey(key))
          TextButton(
            onPressed: () {
              setState(() => _socialLinks.remove(key));
              Navigator.pop(c);
            }, 
            child: const Text("Remove", style: TextStyle(color: Colors.red))
          ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              if (linkCtrl.text.trim().isNotEmpty) {
                _socialLinks[key] = linkCtrl.text.trim();
              } else {
                _socialLinks.remove(key); // Remove if empty text
              }
            });
            Navigator.pop(c);
          }, 
          child: const Text("Save")
        )
      ],
    ));
  }

  // --- TEAM LEADERS SECTION ---
  Widget _buildTeamLeadersSection() {
    return Card(
      color: Colors.blue.shade50, 
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            const Row(children: [Icon(Icons.groups, color: Colors.blue), SizedBox(width: 8), Text("Team Leaders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))]),
            const SizedBox(height: 4),
            const Text("Add/Edit images for leaders added in Settings tab.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            
            StreamBuilder<DocumentSnapshot>(
              stream: db.collection('settings').doc('general').snapshots(), 
              builder: (context, snap) {
                if(!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
                Map details = data['teamDetails'] ?? {};
                List teams = data['teams'] ?? [];
                
                if(teams.isEmpty) return const Text("No teams found. Add teams in Settings.");

                return ListView.builder(
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(), 
                  itemCount: teams.length, 
                  itemBuilder: (c, i) {
                    String tName = teams[i];
                    Map tData = details[tName] ?? {};
                    List leaders = tData['leaders'] ?? [];
                    int colorVal = tData['color'] ?? 0xFF000000;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: Colors.white,
                      child: ExpansionTile(
                        shape: Border.all(color: Colors.transparent),
                        title: Text(tName, style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorVal))), 
                        leading: CircleAvatar(backgroundColor: Color(colorVal), radius: 10),
                        children: leaders.isEmpty 
                          ? [const Padding(padding: EdgeInsets.all(8.0), child: Text("No leaders added yet.", style: TextStyle(color: Colors.grey, fontSize: 12)))]
                          : leaders.asMap().entries.map((entry) { 
                              int lIdx = entry.key; 
                              Map leader = entry.value; 
                              String img = _fixDriveLink(leader['img'] ?? ''); 
                              
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: img.isNotEmpty ? NetworkImage(img) : null, 
                                  child: img.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null
                                ), 
                                title: Text(leader['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                                subtitle: Text(leader['name']), 
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_a_photo, size: 20, color: Colors.blue), 
                                  tooltip: "Update Photo",
                                  onPressed: () => _updateTeamLeaderImage(tName, lIdx, leader, details)
                                )
                              ); 
                            }).toList()
                      ),
                    );
                  }
                );
              }
            )
          ]
        )
      )
    );
  }

  void _updateTeamLeaderImage(String teamName, int index, Map leaderData, Map allDetails) {
    TextEditingController imgCtrl = TextEditingController(text: leaderData['img'] ?? '');
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        String currentUrl = _fixDriveLink(imgCtrl.text);
        return AlertDialog(
          title: Text("Update Photo: ${leaderData['name']}"), 
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL"), onChanged: (v) => setDialogState((){})), 
            const SizedBox(height: 10), 
            if(currentUrl.isNotEmpty) Container(height: 100, width: 100, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(currentUrl, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error)))
          ]), 
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), 
            ElevatedButton(
              onPressed: () async { 
                List leaders = List.from(allDetails[teamName]['leaders']); 
                leaders[index]['img'] = _fixDriveLink(imgCtrl.text); 
                allDetails[teamName]['leaders'] = leaders; 
                await db.collection('settings').doc('general').update({'teamDetails': allDetails}); 
                Navigator.pop(c); 
              }, 
              child: const Text("Update")
            )
          ]
        );
    }));
  }

  Widget _buildOfficialsSection() {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Fest Officials", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo), onPressed: () => _editOfficial())]),
        ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), onReorder: (o, n) { setState(() { if (n > o) n -= 1; final item = _officials.removeAt(o); _officials.insert(n, item); }); }, children: [for (int i = 0; i < _officials.length; i++) ListTile(key: ValueKey(_officials[i]['name'] + i.toString()), leading: CircleAvatar(backgroundImage: _officials[i]['img'] != null && _officials[i]['img'].isNotEmpty ? NetworkImage(_fixDriveLink(_officials[i]['img'])) : null, child: _officials[i]['img'] == null || _officials[i]['img'].isEmpty ? const Icon(Icons.person) : null), title: Text(_officials[i]['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text(_officials[i]['name']), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue), onPressed: () => _editOfficial(index: i)), IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => setState(() => _officials.removeAt(i))) ]))])
    ])));
  }

  void _editOfficial({int? index}) {
    final nameCtrl = TextEditingController(text: index != null ? _officials[index]['name'] : '');
    final roleCtrl = TextEditingController(text: index != null ? _officials[index]['role'] : '');
    final imgCtrl = TextEditingController(text: index != null ? _officials[index]['img'] : '');
    
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        String currentUrl = _fixDriveLink(imgCtrl.text);
        return AlertDialog(
          title: Text(index == null ? "Add Official" : "Edit Official"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role")), 
            const SizedBox(height: 10), 
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")), 
            const SizedBox(height: 10), 
            TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL"), onChanged: (v) => setDialogState((){})), 
            const SizedBox(height: 10), 
            if(currentUrl.isNotEmpty) Container(height: 80, width: 80, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(currentUrl, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.broken_image)))
          ]),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  Map<String, dynamic> d = {'name': nameCtrl.text, 'role': roleCtrl.text, 'img': _fixDriveLink(imgCtrl.text)};
                  setState(() {
                    if (index == null) {
                      _officials.add(d);
                    } else {
                      _officials[index] = d; 
                    }
                  });
                  Navigator.pop(c);
                }
              },
              child: const Text("Save")
            )
          ]
        );
    }));
  }

  Widget _buildGalleryGrid() {
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), IconButton(icon: const Icon(Icons.add_photo_alternate), onPressed: _addGallery)]),
        _gallery.isEmpty ? const Text("No images.", style: TextStyle(color: Colors.grey)) : GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1), itemCount: _gallery.length, itemBuilder: (context, index) { return Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_gallery[index], fit: BoxFit.cover, errorBuilder: (c,e,s)=>Container(color: Colors.grey.shade200, child: const Icon(Icons.error)))), Positioned(top: 4, right: 4, child: InkWell(onTap: () => setState(() => _gallery.removeAt(index)), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))))]); })
    ])));
  }

  void _addGallery() {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Add Image URL"), content: TextField(controller: c), actions: [ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { setState(()=>_gallery.add(_fixDriveLink(c.text))); Navigator.pop(ctx); }}, child: const Text("Add"))]));
  }
}
