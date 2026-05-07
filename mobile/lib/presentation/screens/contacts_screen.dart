import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../infrastructure/auth/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Map<String, String>> _contacts = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      final response = await http.get(
        Uri.parse('${auth.baseUrl.replaceAll('/auth', '')}/contacts/'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _contacts.clear();
          for (var item in data) {
            _contacts.add({
              'id': item['contact_id'],
              'name': item['nombre'],
              'phone': item['telefono'],
              'relation': item['relacion'],
            });
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
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
                onChanged: (v) => setStateModal(() => relation = v!),
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
              onPressed: isSaving ? null : () async {
                if (name.isEmpty || phone.isEmpty) {
                  setStateModal(() => error = 'complete los campos obligatorios');
                  return;
                }
                final regExp = RegExp(r'^9\d{8}$');
                if (!regExp.hasMatch(phone)) {
                  setStateModal(() => error = 'número inválido');
                  return;
                }
                
                setStateModal(() { error = null; isSaving = true; });
                
                try {
                  final auth = AuthService();
                  final response = await http.post(
                    Uri.parse('${auth.baseUrl.replaceAll('/auth', '')}/contacts/'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${auth.token}'
                    },
                    body: jsonEncode({
                      'nombre': name,
                      'telefono': phone,
                      'relacion': relation,
                      'es_principal': false
                    })
                  );
                  if (response.statusCode == 200) {
                    Navigator.pop(context);
                    _fetchContacts();
                  } else {
                    final data = jsonDecode(response.body);
                    setStateModal(() { error = data['detail'] ?? 'Error al guardar'; isSaving = false; });
                  }
                } catch (e) {
                  setStateModal(() { error = 'Error de conexión'; isSaving = false; });
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        title: const Text('Contactos de Emergencia', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E40AF), 
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Banner informativo superior
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E40AF),
            child: const Text(
              'Toca un contacto para llamar rápidamente en caso de emergencia.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final c = _contacts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: const Icon(Icons.person, color: Color(0xFF2563EB)),
                        ),
                        title: Text(c['name']!, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${c['relation']} • ${c['phone']}',
                            style: TextStyle(color: Colors.grey[600])),
                        ),
                        onTap: () => _makeCall(c['phone']!),

                        trailing: c['email'] != null 
                          ? null 
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                setState(() => _contacts.removeAt(index));
                              },
                            ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        backgroundColor: const Color(0xFF2563EB),
        label: const Text('Nuevo', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}