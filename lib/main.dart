import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart'; // Asegúrate de que esta importación sea correcta

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AppSign',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Muestra una pantalla de carga mientras se verifica el estado de autenticación
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si el usuario no está autenticado, muestra la página de inicio de sesión
          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginPage();
          }

          final user = snapshot.data!;

          // Si el usuario está autenticado, verifica su rol en Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              // Muestra una pantalla de carga mientras se obtienen los datos del usuario
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Verifica si el documento del usuario existe y si tiene un rol de administrador
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final bool isAdmin = userData?['isAdmin'] ?? false; // El valor predeterminado es false

                // Si es un administrador, muestra la página de administración.
                // De lo contrario, muestra la página de inicio normal.
                return isAdmin ? const AdminPage() : const HomePage();
              }

              // Si el documento de Firestore no existe, dirige al usuario de vuelta al inicio de sesión por seguridad
              return const LoginPage();
            },
          );
        },
      ),
    );
  }
}
