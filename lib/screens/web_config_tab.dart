// File: lib/screens/web_config_tab.dart
// Version: 5.0
// Description: Fixed 'padding' parameter error in Card and Null Safety Warning.

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

  final _festNameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _btnColorCtrl = TextEditingController(text: "#2563EB"); 
  Color _currentColor = const Color(0xFF2563EB);

  final _aboutSubCtrl = TextEditingController();
  final _aboutTextCtrl = TextEditingController();
  final _socialLinkCtrl = TextEditingController();

  Map<String, String> _socialLinks = {}; 
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

          if(d['social'] != null) _socialLinks = Map<String, String>.from(d['social']);
          if(d['leaders'] != null) _officials = List<Map<String, dynamic>>.from(d['leaders']);
          if(d['gallery'] != null) _gallery = List<String>.from(d['gallery']);
        });
      }
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    String fixedLogo = _fixDriveLink(_logoUrlCtrl.text);

    Map<String, dynamic> data = {
      'festName1': _festNameCtrl.text,
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
    setState(() => _isLoading = false);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuration Saved Successfully!")));
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
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Branding", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 16),
        TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name")),
        const SizedBox(height: 10),
        TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
        const SizedBox(height: 10),
        TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo URL", prefixIcon: Icon(Icons.link)), onChanged: (v)=>setState((){})),
        if(_logoUrlCtrl.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Image.network(_fixDriveLink(_logoUrlCtrl.text), height: 50, errorBuilder: (c,e,s)=>const Text("Invalid Image"))),
        const SizedBox(height: 10),
        Row(children: [const Text("Button Color: "), InkWell(onTap: _pickColor, child: Container(width: 30, height: 30, color: _currentColor)), const SizedBox(width: 10), Expanded(child: TextField(controller: _btnColorCtrl, decoration: const InputDecoration(labelText: "Hex Code"), onChanged: (v){ try{setState(()=>_currentColor=Color(int.parse(v.replaceAll('#','0xFF'))));}catch(e){}}))])
    ])));
  }

  void _pickColor() {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Pick Color"), content: Wrap(spacing: 5, children: [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple].map((co) => InkWell(onTap: (){ setState((){ _currentColor=co; _btnColorCtrl.text='#${co.value.toRadixString(16).substring(2).toUpperCase()}'; }); Navigator.pop(c); }, child: CircleAvatar(backgroundColor: co))).toList())));
  }

  Widget _buildAboutSection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       const Text("About Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
       const SizedBox(height: 10),
       TextField(controller: _aboutSubCtrl, decoration: const InputDecoration(labelText: "Subtitle")),
       const SizedBox(height: 10),
       TextField(controller: _aboutTextCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Description")),
    ])));
  }

  Widget _buildSmartSocialSection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Social Media Links", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: _socialLinkCtrl, decoration: const InputDecoration(labelText: "Paste Profile Link Here", hintText: "WhatsApp, YouTube, Insta etc.", prefixIcon: Icon(Icons.link), isDense: true))), const SizedBox(width: 8), IconButton.filled(onPressed: _addSmartLink, icon: const Icon(Icons.add), tooltip: "Add Link")]),
        const SizedBox(height: 15),
        if (_socialLinks.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text("No links added.", style: TextStyle(color: Colors.grey)))
        else Wrap(spacing: 8, runSpacing: 8, children: _socialLinks.entries.map((e) => Chip(avatar: Icon(_getSocialIcon(e.key), size: 16, color: Colors.white), label: Text(_getSocialName(e.key)), backgroundColor: _getSocialColor(e.key), labelStyle: const TextStyle(color: Colors.white), deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white), onDeleted: () => setState(() => _socialLinks.remove(e.key)))).toList())
    ])));
  }

  void _addSmartLink() {
    String url = _socialLinkCtrl.text.trim();
    if (url.isEmpty) return;
    String platform = 'web';
    if (url.contains('whatsapp') || url.contains('wa.me')) platform = 'wa';
    else if (url.contains('instagram')) platform = 'ig';
    else if (url.contains('youtube') || url.contains('youtu.be')) platform = 'yt';
    else if (url.contains('facebook') || url.contains('fb.com')) platform = 'fb';
    else if (url.contains('telegram') || url.contains('t.me')) platform = 'tg';
    setState(() => _socialLinks[platform] = url);
    _socialLinkCtrl.clear();
  }

  IconData _getSocialIcon(String key) {
    switch(key) { case 'wa': return Icons.chat; case 'ig': return Icons.camera_alt; case 'yt': return Icons.play_circle_fill; case 'fb': return Icons.facebook; case 'tg': return Icons.send; default: return Icons.public; }
  }
  Color _getSocialColor(String key) {
    switch(key) { case 'wa': return Colors.green; case 'ig': return Colors.pink; case 'yt': return Colors.red; case 'fb': return Colors.blue.shade800; case 'tg': return Colors.blue; default: return Colors.grey; }
  }
  String _getSocialName(String key) {
    const names = {'wa': 'WhatsApp', 'ig': 'Instagram', 'yt': 'YouTube', 'fb': 'Facebook', 'tg': 'Telegram', 'web': 'Website'};
    return names[key] ?? 'Link';
  }

  Widget _buildOfficialsSection() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      _officials[index] = d; // Safe assignment without ! operator
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

  Widget _buildTeamLeadersSection() {
    return Card(color: Colors.blue.shade50, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.groups, color: Colors.blue), SizedBox(width: 8), Text("Team Leaders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))]),
        const Text("Add images here. Names/Roles sync from Settings.", style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot>(stream: db.collection('settings').doc('general').snapshots(), builder: (context, snap) {
            if(!snap.hasData) return const Center(child: CircularProgressIndicator());
            var data = snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : {};
            Map details = data['teamDetails'] ?? {};
            List teams = data['teams'] ?? [];
            if(teams.isEmpty) return const Text("No teams found.");
            return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: teams.length, itemBuilder: (c, i) {
                String tName = teams[i];
                Map tData = details[tName] ?? {};
                List leaders = tData['leaders'] ?? [];
                int colorVal = tData['color'] ?? 0xFF000000;
                return ExpansionTile(title: Text(tName, style: const TextStyle(fontWeight: FontWeight.bold)), leading: CircleAvatar(backgroundColor: Color(colorVal), radius: 10), children: [...leaders.asMap().entries.map((entry) { int lIdx = entry.key; Map leader = entry.value; String img = _fixDriveLink(leader['img'] ?? ''); return ListTile(leading: CircleAvatar(backgroundImage: img.isNotEmpty ? NetworkImage(img) : null, child: img.isEmpty ? const Icon(Icons.person) : null), title: Text(leader['role'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text(leader['name']), trailing: IconButton(icon: const Icon(Icons.add_a_photo, size: 20, color: Colors.blue), onPressed: () => _updateTeamLeaderImage(tName, lIdx, leader, details))); }).toList()]);
            });
        })
    ])));
  }

  void _updateTeamLeaderImage(String teamName, int index, Map leaderData, Map allDetails) {
    TextEditingController imgCtrl = TextEditingController(text: leaderData['img'] ?? '');
    showDialog(context: context, builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        String currentUrl = _fixDriveLink(imgCtrl.text);
        return AlertDialog(title: Text("Update Image for ${leaderData['name']}"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL"), onChanged: (v) => setDialogState((){})), const SizedBox(height: 10), if(currentUrl.isNotEmpty) Container(height: 100, width: 100, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(currentUrl, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error)))]), actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () async { List leaders = List.from(allDetails[teamName]['leaders']); leaders[index]['img'] = _fixDriveLink(imgCtrl.text); allDetails[teamName]['leaders'] = leaders; await db.collection('settings').doc('general').update({'teamDetails': allDetails}); Navigator.pop(c); }, child: const Text("Update"))]);
    }));
  }

  Widget _buildGalleryGrid() {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), IconButton(icon: const Icon(Icons.add_photo_alternate), onPressed: _addGallery)]),
        _gallery.isEmpty ? const Text("No images.", style: TextStyle(color: Colors.grey)) : GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1), itemCount: _gallery.length, itemBuilder: (context, index) { return Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_gallery[index], fit: BoxFit.cover, errorBuilder: (c,e,s)=>Container(color: Colors.grey.shade200, child: const Icon(Icons.error)))), Positioned(top: 4, right: 4, child: InkWell(onTap: () => setState(() => _gallery.removeAt(index)), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))))]); })
    ])));
  }

  void _addGallery() {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Add Image URL"), content: TextField(controller: c), actions: [ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { setState(()=>_gallery.add(_fixDriveLink(c.text))); Navigator.pop(ctx); }}, child: const Text("Add"))]));
  }
}