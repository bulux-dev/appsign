import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Se ha cambiado a StatefulWidget para manejar el estado de la lista y el campo de búsqueda.
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allUsers = [];
  List<DocumentSnapshot> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  // Método para obtener la lista completa de usuarios de Firestore
  void _fetchUsers() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _allUsers = snapshot.docs;
          _filterUsers(); // Llama a la función de filtro para mostrar todos al inicio
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Error al obtener usuarios: $error');
      }
    });
  }

  // Método para filtrar la lista de usuarios basada en el texto de búsqueda
  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
    } else {
      setState(() {
        _filteredUsers = _allUsers.where((userDoc) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final email = userData['email']?.toLowerCase() ?? '';
          return email.contains(query);
        }).toList();
      });
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // Método para actualizar el rol de administrador en Firestore
  void _updateAdminStatus(String userId, bool newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': newStatus,
      });
    } catch (e) {
      print('Error al actualizar el estado de administrador: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el estado de administrador.')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Usuarios', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por correo electrónico...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(child: Text('No se encontraron usuarios.'))
                    : _filteredUsers.isEmpty && _searchController.text.isEmpty
                        ? const Center(child: Text('No hay usuarios registrados.'))
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final userDoc = _filteredUsers[index];
                              final userData = userDoc.data() as Map<String, dynamic>;
                              final bool isAdmin = userData['isAdmin'] ?? false;
                              final String email = userData['email'] ?? 'N/A';
                              final String userId = userDoc.id;

                              return Card(
                                elevation: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: ListTile(
                                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('ID de Usuario: $userId'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Admin'),
                                      Switch(
                                        value: isAdmin,
                                        onChanged: (newValue) {
                                          _updateAdminStatus(userId, newValue);
                                        },
                                        activeColor: Colors.deepPurple,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
