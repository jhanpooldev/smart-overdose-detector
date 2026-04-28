import 'package:flutter/material.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Map<String, String>> _contacts = [
    {'name': 'Juan Pérez', 'phone': '555-0100', 'relation': 'Hermano'},
  ];

  void _addContact() {
    String name = '';
    String phone = '';
    String relation = 'Familiar';
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: (v) => name = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => phone = v,
              ),
              DropdownButton<String>(
                value: relation,
                isExpanded: true,
                items: ['Familiar', 'Médico', 'Amigo'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (v) => setState(() => relation = v!),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (name.isEmpty || phone.isEmpty) {
                  setState(() => error = 'Complete los campos obligatorios');
                  return;
                }
                if (phone.length < 6) {
                  setState(() => error = 'Número inválido');
                  return;
                }
                if (_contacts.any((c) => c['phone'] == phone)) {
                  setState(() => error = 'Contacto ya existente');
                  return;
                }
                this.setState(() {
                  _contacts.add({'name': name, 'phone': phone, 'relation': relation});
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Contactos de Emergencia'),
        backgroundColor: const Color(0xFF1D4ED8),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final c = _contacts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2563EB),
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${c['relation']} • ${c['phone']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() => _contacts.removeAt(index));
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
