import 'package:appsign/pages/sign_detection_module.dart';
import 'package:appsign/pages/text_search_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appsign/pages/home_page.dart';
import 'package:appsign/pages/admin_page.dart';
import 'package:appsign/pages/user_list_page.dart';
import 'package:appsign/pages/sign_list_page.dart'; // <--- Importación de la nueva página

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de Administración', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón para la sección de Audio
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
                icon: const Icon(Icons.mic, size: 50),
                label: const Text('Audio', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                // Navegar a la página de "Señas"
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignDetectionModule()),
                );
              },
              icon: const Icon(Icons.sign_language, size: 50),
              label: const Text('Señas', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: (){
                Navigator.of(context).push(
                  MaterialPageRoute(builder:(context)=> const TextSearchPage()),
                );

                //Nae
              },
              icon: const Icon(Icons.text_fields, size: 50),
              label: const Text('Texto', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              ),
              const SizedBox(height: 30),

              // --- Opciones de Administración ---
              const Divider(color: Colors.deepPurple),
              const SizedBox(height: 20),
              
              const Text('Opciones de Administrador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignListPage()),
                  );
                },
                icon: const Icon(Icons.format_list_bulleted, size: 50),
                label: const Text('Lista de Señas', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AdminPage()),
                  );
                },
                icon: const Icon(Icons.add_photo_alternate, size: 50),
                label: const Text('Agregar Seña', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const UserListPage()),
                  );
                },
                icon: const Icon(Icons.group, size: 50),
                label: const Text('Lista de Usuarios', style: TextStyle(fontSize: 24)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),


               
            ],
          ),
        ),
      ),
    );
  }
}