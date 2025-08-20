import 'package:flutter/material.dart';
import 'package:appsign/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Nueva importación para sign out

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  // Nuevo método para cerrar la sesión
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut, // <--- Llama a la función para cerrar sesión
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                // Navegar a la futura página de "Señas"
                // Navigator.of(context).push(
                //   MaterialPageRoute(builder: (context) => const SignLanguagePage()),
                // );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La página de señas aún no está disponible.')),
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
          ],
        ),
      ),
    );
  }
}
