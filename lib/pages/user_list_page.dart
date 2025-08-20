import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserListPage extends StatelessWidget {
  const UserListPage({super.key});

  void _signOut(BuildContext context) async {
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
    }
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
            onPressed: () => _signOut(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escucha los cambios en tiempo real en la colección 'users'
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          // Construye la lista de usuarios a partir de los documentos de Firestore
          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
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
          );
        },
      ),
    );
  }
}
