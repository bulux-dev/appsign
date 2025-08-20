import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';
import 'pages/admin_menu_page.dart'; // <--- Importación de la nueva página

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginPage();
          }

          final user = snapshot.data!;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final bool isAdmin = userData?['isAdmin'] ?? false;

                // Lógica de navegación actualizada
                return isAdmin ? const AdminMenuPage() : const MenuPage();
              }

              return const LoginPage();
            },
          );
        },
      ),
    );
  }
}
