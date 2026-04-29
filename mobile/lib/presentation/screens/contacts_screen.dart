import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../infrastructure/auth/auth_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Map<String, String>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialContacts();
  }

  void _loadInitialContacts() {
    final user = AuthService().currentUser;
    if (user != null && user.supervisorEmail != null && user.supervisorEmail!.isNotEmpty) {
      _contacts.add({
        'name': 'Supervisor',
        'phone': '999999999', // Dummy number since we don't fetch supervisor's real number
        'relation': 'Supervisor (Asignado)',
        'email': user.supervisorEmail!
      });
    }
    _contacts.add({'name': 'Juan Pérez', 'phone': '987654321', 'relation': 'Hermano'});
  }

  Future<void> _makeCall(String phone) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada')),
        );
      }
    }
  }

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
                decoration: const InputDecoration(
                  labelText: 'Teléfono (9 dígitos)',
                  hintText: '9XXXXXXXX',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 9,
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
                  setState(() => error = 'complete los campos obligatorios');
                  return;
                }
                // Validación para número peruano de 9 dígitos
                final regExp = RegExp(r'^9\d{8}$');
                if (!regExp.hasMatch(phone)) {
                  setState(() => error = 'número inválido');
                  return;
                }
                if (_contacts.any((c) => c['phone'] == phone)) {
                  setState(() => error = 'contacto ya existente');
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
              onTap: () => _makeCall(c['phone']!),
              trailing: c['email'] != null 
                ? null 
                : IconButton(
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
