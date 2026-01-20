import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventRegistrationsView extends StatefulWidget {
  const EventRegistrationsView({super.key});
  @override
  State<EventRegistrationsView> createState() => _EventRegistrationsViewState();
}

class _EventRegistrationsViewState extends State<EventRegistrationsView> {
  final db = FirebaseFirestore.instance;
  String? _selectedEvent;
  String? _selectedStudent;
  
  Future<void> _register() async {
    if(_selectedEvent == null || _selectedStudent == null) return;
    
    // ഫെച്ച് ഡാറ്റ
    var sDoc = await db.collection('students').doc(_selectedStudent).get();
    var eDoc = await db.collection('events').doc(_selectedEvent).get();
    
    await db.collection('registrations').add({
      'eventId': _selectedEvent,
      'eventName': eDoc['name'],
      'studentId': _selectedStudent,
      'studentName': sDoc['name'],
      'teamId': sDoc['teamId'], // ഓട്ടോമാറ്റിക് ആയി ടീം എടുക്കുന്നു
      'category': sDoc['categoryId'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registered Successfully")));
    setState(() => _selectedStudent = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Event Registration Desk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // 1. Select Event
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('events').snapshots(),
              builder: (c, s) {
                if(!s.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField(
                  value: _selectedEvent,
                  hint: const Text("Select Event"),
                  items: s.data!.docs.map((e) => DropdownMenuItem(value: e.id, child: Text(e['name']))).toList(),
                  onChanged: (v) => setState(() => _selectedEvent = v as String?),
                );
              }
            ),
            const SizedBox(height: 10),

            // 2. Select Student (Filter by eligibility if needed)
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('students').orderBy('chestNo').snapshots(),
              builder: (c, s) {
                if(!s.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField(
                  value: _selectedStudent,
                  hint: const Text("Select Student (Chest No - Name)"),
                  isExpanded: true,
                  items: s.data!.docs.map((e) => DropdownMenuItem(value: e.id, child: Text("${e['chestNo']} - ${e['name']}"))).toList(),
                  onChanged: (v) => setState(() => _selectedStudent = v as String?),
                );
              }
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _register, child: const Text("REGISTER PARTICIPANT"))),
            
            const Divider(height: 40),
            
            // List of Registrations
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: db.collection('registrations').orderBy('createdAt', descending: true).snapshots(),
                builder: (c, s) {
                  if(!s.hasData) return const SizedBox();
                  return ListView.builder(
                    itemCount: s.data!.docs.length,
                    itemBuilder: (c, i) {
                      var d = s.data!.docs[i];
                      return ListTile(
                        title: Text(d['eventName']),
                        subtitle: Text("${d['studentName']} (${d['teamId']})"),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: ()=>d.reference.delete()),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
