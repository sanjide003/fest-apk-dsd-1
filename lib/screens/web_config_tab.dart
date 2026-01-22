// File: lib/screens/web_config_tab.dart
// Version: 4.0
// Description: Fixed 'padding' parameter error in Card widget.

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      var doc = await db.collection('web_config').doc('main').get();
      if (doc.exists) {
        var data = doc.data()!;
        _festNameCtrl.text = data['festName'] ?? '';
        _taglineCtrl.text = data['tagline'] ?? '';
        _logoUrlCtrl.text = data['logoUrl'] ?? '';
        _btnColorCtrl.text = data['primaryColor'] ?? '#2563EB';
        _aboutSubCtrl.text = data['aboutSubtitle'] ?? '';
        _aboutTextCtrl.text = data['aboutText'] ?? '';
        
        _socialLinks = Map<String, String>.from(data['socialLinks'] ?? {});
        _gallery = List<String>.from(data['gallery'] ?? []);
        
        List<dynamic> offs = data['officials'] ?? [];
        _officials = offs.map((e) => Map<String, dynamic>.from(e)).toList();

        try {
          String hex = _btnColorCtrl.text.replaceAll("#", "");
          if (hex.length == 6) {
            _currentColor = Color(int.parse("0xFF$hex"));
          }
        } catch (_) {}
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await db.collection('web_config').doc('main').set({
        'festName': _festNameCtrl.text,
        'tagline': _taglineCtrl.text,
        'logoUrl': _fixDriveLink(_logoUrlCtrl.text),
        'primaryColor': _btnColorCtrl.text,
        'aboutSubtitle': _aboutSubCtrl.text,
        'aboutText': _aboutTextCtrl.text,
        'socialLinks': _socialLinks,
        'officials': _officials,
        'gallery': _gallery
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Website Config Updated!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveConfig,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text("Save Changes", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Hero Section"),
            _buildCard([
              _input(_festNameCtrl, "Fest Name", Icons.event),
              const SizedBox(height: 10),
              _input(_taglineCtrl, "Tagline / Date", Icons.short_text),
              const SizedBox(height: 10),
              _input(_logoUrlCtrl, "Logo Image URL", Icons.image),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _input(_btnColorCtrl, "Primary Color (Hex)", Icons.color_lens)),
                const SizedBox(width: 10),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: _currentColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)))
              ])
            ]),

            _sectionTitle("About Section"),
            _buildCard([
              _input(_aboutSubCtrl, "About Subtitle", Icons.subtitles),
              const SizedBox(height: 10),
              TextField(
                controller: _aboutTextCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "About Description",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: Colors.white
                ),
              )
            ]),

            _sectionTitle("Officials (Contact)"),
            _buildOfficialsList(),

            _sectionTitle("Gallery"),
            _buildGalleryGrid(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      color: Colors.white,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true, fillColor: Colors.white
      ),
    );
  }

  // --- OFFICIALS ---
  Widget _buildOfficialsList() {
    return Card(
      color: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        children: [
          ..._officials.asMap().entries.map((entry) {
            int idx = entry.key;
            Map d = entry.value;
            return ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(d['img'] ?? ''), child: const Icon(Icons.person)),
              title: Text(d['name']),
              subtitle: Text(d['role']),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addOfficial(index: idx)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _officials.removeAt(idx))),
              ]),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.indigo),
            title: const Text("Add Official"),
            onTap: () => _addOfficial(),
          )
        ],
      ),
    );
  }

  void _addOfficial({int? index}) {
    final nameCtrl = TextEditingController(text: index != null ? _officials[index]['name'] : '');
    final roleCtrl = TextEditingController(text: index != null ? _officials[index]['role'] : '');
    final imgCtrl = TextEditingController(text: index != null ? _officials[index]['img'] : '');
    String currentUrl = imgCtrl.text;

    showDialog(context: context, builder: (c) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(index == null ? "Add Official" : "Edit Official"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role")),
            const SizedBox(height: 10),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            const SizedBox(height: 10),
            TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL"), onChanged: (v) => setDialogState((){ currentUrl = v; })),
            const SizedBox(height: 10),
            if(currentUrl.isNotEmpty) Container(height: 80, width: 80, decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: Image.network(currentUrl, fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.broken_image)))
          ]),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
            ElevatedButton(onPressed: (){ 
              if(nameCtrl.text.isNotEmpty) { 
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
            }, child: const Text("Save"))
          ],
        );
      }
    ));
  }

  // --- GALLERY ---
  Widget _buildGalleryGrid() {
    return Card(
      color: Colors.white, elevation: 0,
      // FIX: Removed 'padding' parameter from Card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(12), // FIX: Added Padding widget here
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), IconButton(icon: const Icon(Icons.add_photo_alternate), onPressed: _addGallery)]),
          _gallery.isEmpty ? const Text("No images.", style: TextStyle(color: Colors.grey)) : GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1), itemCount: _gallery.length, itemBuilder: (context, index) { return Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_gallery[index], fit: BoxFit.cover, errorBuilder: (c,e,s)=>Container(color: Colors.grey.shade200, child: const Icon(Icons.error)))), Positioned(top: 4, right: 4, child: InkWell(onTap: () => setState(() => _gallery.removeAt(index)), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))))]); })
        ]),
      )
    );
  }

  void _addGallery() {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Add Image URL"), content: TextField(controller: c), actions: [ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { setState(() => _gallery.add(_fixDriveLink(c.text))); Navigator.pop(ctx); }}, child: const Text("Add"))]));
  }
}
