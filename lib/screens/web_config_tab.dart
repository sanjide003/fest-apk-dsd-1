// File: lib/screens/web_config_tab.dart
// Version: 1.1
// Description: വെബ്സൈറ്റ് ക്രമീകരണങ്ങൾ (Branding, Colors, Leaders, Gallery, Social) നിയന്ത്രിക്കുന്ന പേജ്.

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
  
  // Controller - Button Color (Hex)
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

  // Lists for Leaders & Gallery
  List<Map<String, dynamic>> _leaders = [];
  List<String> _gallery = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ഫയർബേസിൽ നിന്നും നിലവിലെ വിവരങ്ങൾ ലോഡ് ചെയ്യുന്നു
  void _loadData() {
    db.collection('settings').doc('home_config').get().then((doc) {
      if(doc.exists) {
        var d = doc.data()!;
        setState(() {
          _festNameCtrl.text = d['festName1'] ?? '';
          _taglineCtrl.text = d['tagline'] ?? '';
          _logoUrlCtrl.text = d['logoUrl'] ?? '';
          
          // Button Color Parsing
          String colorHex = d['btnColor'] ?? '#2563EB';
          _btnColorCtrl.text = colorHex;
          try {
            _currentColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
          } catch (e) {
            _currentColor = Colors.blue;
          }

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
            _leaders = List<Map<String, dynamic>>.from(d['leaders']);
          }

          if(d['gallery'] != null) {
            _gallery = List<String>.from(d['gallery']);
          }
        });
      }
    });
  }

  // മാറ്റങ്ങൾ ഫയർബേസിലേക്ക് സേവ് ചെയ്യുന്നു
  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    
    Map<String, dynamic> data = {
      'festName1': _festNameCtrl.text,
      'tagline': _taglineCtrl.text,
      'logoUrl': _logoUrlCtrl.text,
      'btnColor': _btnColorCtrl.text, // Saving Hex Color
      'aboutSubtitle': _aboutSubCtrl.text,
      'aboutText': _aboutTextCtrl.text,
      'social': {
        'wa': _waCtrl.text,
        'ig': _igCtrl.text,
        'fb': _fbCtrl.text,
        'yt': _ytCtrl.text,
        'tg': _tgCtrl.text,
      },
      'leaders': _leaders,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveConfig,
        backgroundColor: Colors.indigo,
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
            _buildLeadersSection(),
            const SizedBox(height: 20),
            _buildGallerySection(),
            const SizedBox(height: 80), // FAB മറയ്ക്കാതിരിക്കാൻ സ്പേസ്
          ],
        ),
      ),
    );
  }

  // 1. അടിസ്ഥാന വിവരങ്ങൾ & ബട്ടൺ കളർ
  Widget _buildBasicSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Basic Info & Branding", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 16),
            TextField(controller: _festNameCtrl, decoration: const InputDecoration(labelText: "Fest Name")),
            const SizedBox(height: 10),
            TextField(controller: _taglineCtrl, decoration: const InputDecoration(labelText: "Tagline")),
            const SizedBox(height: 10),
            TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: "Logo Image URL", prefixIcon: Icon(Icons.link))),
            const SizedBox(height: 16),
            
            // Button Color Picker
            Row(
              children: [
                const Text("Website Button Color: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _pickColor,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _currentColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _btnColorCtrl, decoration: const InputDecoration(labelText: "Hex Code (e.g. #FF0000)"), onChanged: (v){
                  if(v.length == 7) {
                    try { setState(() => _currentColor = Color(int.parse(v.replaceAll('#', '0xFF')))); } catch(e){}
                  }
                })),
              ],
            )
          ],
        ),
      ),
    );
  }

  // കളർ പിക്കർ ഡയലോഗ്
  void _pickColor() {
    List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.black];
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Select Button Color"),
      content: Wrap(
        spacing: 10, runSpacing: 10,
        children: colors.map((co) => InkWell(
          onTap: () {
            setState(() {
              _currentColor = co;
              _btnColorCtrl.text = '#${co.value.toRadixString(16).substring(2).toUpperCase()}';
            });
            Navigator.pop(c);
          },
          child: CircleAvatar(backgroundColor: co, radius: 20, child: _currentColor.value == co.value ? const Icon(Icons.check, color: Colors.white) : null),
        )).toList(),
      ),
    ));
  }

  // 2. About Section
  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text("About Section", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
             const SizedBox(height: 16),
             TextField(controller: _aboutSubCtrl, decoration: const InputDecoration(labelText: "About Subtitle")),
             const SizedBox(height: 10),
             TextField(controller: _aboutTextCtrl, maxLines: 4, decoration: const InputDecoration(labelText: "Full Description", alignLabelWithHint: true)),
          ],
        ),
      ),
    );
  }

  // 3. Social Media Links
  Widget _buildSocialSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text("Social Media Links", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
             const SizedBox(height: 16),
             TextField(controller: _waCtrl, decoration: const InputDecoration(labelText: "WhatsApp Link", prefixIcon: Icon(Icons.chat))),
             const SizedBox(height: 10),
             TextField(controller: _igCtrl, decoration: const InputDecoration(labelText: "Instagram Link", prefixIcon: Icon(Icons.camera_alt))),
             const SizedBox(height: 10),
             TextField(controller: _fbCtrl, decoration: const InputDecoration(labelText: "Facebook Link", prefixIcon: Icon(Icons.facebook))),
             const SizedBox(height: 10),
             TextField(controller: _ytCtrl, decoration: const InputDecoration(labelText: "YouTube Link", prefixIcon: Icon(Icons.video_library))),
             const SizedBox(height: 10),
             TextField(controller: _tgCtrl, decoration: const InputDecoration(labelText: "Telegram Link", prefixIcon: Icon(Icons.send))),
          ],
        ),
      ),
    );
  }

  // 4. Fest Leaders (Reorderable List)
  Widget _buildLeadersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Fest Officials / Leaders", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo), onPressed: () => _editLeader())
              ],
            ),
            const Text("Drag to reorder. These appear on the home page.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = _leaders.removeAt(oldIdx);
                  _leaders.insert(newIdx, item);
                });
              },
              children: [
                for (int i = 0; i < _leaders.length; i++)
                  ListTile(
                    key: ValueKey(_leaders[i]['name'] + i.toString()), // Unique Key
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drag_handle, color: Colors.grey),
                    title: Text(_leaders[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_leaders[i]['role']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _editLeader(index: i)),
                         IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {
                           setState(() => _leaders.removeAt(i));
                         }),
                      ],
                    ),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  // Leader Add/Edit Dialog
  void _editLeader({int? index}) {
    final nameCtrl = TextEditingController(text: index != null ? _leaders[index!]['name'] : '');
    final roleCtrl = TextEditingController(text: index != null ? _leaders[index!]['role'] : '');
    final imgCtrl = TextEditingController(text: index != null ? _leaders[index!]['img'] : '');

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(index == null ? "Add Official" : "Edit Official"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
          const SizedBox(height: 10),
          TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Role (e.g. Chairman)")),
          const SizedBox(height: 10),
          TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: "Image URL", prefixIcon: Icon(Icons.image))),
        ],
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: (){
          if(nameCtrl.text.isNotEmpty && roleCtrl.text.isNotEmpty) {
            Map<String, dynamic> data = {'name': nameCtrl.text, 'role': roleCtrl.text, 'img': imgCtrl.text};
            setState(() {
              if(index == null) {
                _leaders.add(data);
              } else {
                _leaders[index] = data;
              }
            });
            Navigator.pop(c);
          }
        }, child: const Text("Save"))
      ],
    ));
  }

  // 5. Gallery Images
  Widget _buildGallerySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Gallery Images", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                IconButton(icon: const Icon(Icons.add_photo_alternate, color: Colors.indigo), onPressed: _addGalleryImage)
              ],
            ),
            const SizedBox(height: 10),
            
            _gallery.isEmpty 
            ? const Padding(padding: EdgeInsets.all(20), child: Text("No images added."))
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _gallery.length,
                separatorBuilder: (c,i) => const Divider(),
                itemBuilder: (c, i) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(width: 50, height: 50, color: Colors.grey.shade200, child: Image.network(_gallery[i], fit: BoxFit.cover, errorBuilder: (c,e,s)=>const Icon(Icons.error))),
                    title: Text(_gallery[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: (){
                       setState(() => _gallery.removeAt(i));
                    }),
                  );
                },
              )
          ],
        ),
      ),
    );
  }

  void _addGalleryImage() {
    final urlCtrl = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Add Gallery Image"),
      content: TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "Image URL")),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: (){
          if(urlCtrl.text.isNotEmpty) {
            setState(() => _gallery.add(urlCtrl.text));
            Navigator.pop(c);
          }
        }, child: const Text("Add"))
      ],
    ));
  }
}
