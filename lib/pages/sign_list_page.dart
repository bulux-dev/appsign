import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:appsign/pages/edit_sign_page.dart';

class SignListPage extends StatelessWidget {
  const SignListPage({super.key});

  Future<void> _deleteSign(String docId, String mediaUrl, String thumbnailUrl) async {
    try {
      await FirebaseFirestore.instance.collection('content').doc(docId).delete();
      await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
      await FirebaseStorage.instance.refFromURL(thumbnailUrl).delete();
    } catch (e) {
      print('Error al eliminar la seña: $e');
    }
  }
  
  void _showDeleteConfirmationDialog(BuildContext context, String docId, String mediaUrl, String thumbnailUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que deseas eliminar esta seña? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _deleteSign(docId, mediaUrl, thumbnailUrl);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seña eliminada con éxito.')),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Señas', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('content').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay señas para mostrar.'));
          }

          final signs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: signs.length,
            itemBuilder: (context, index) {
              final signDoc = signs[index];
              final signData = signDoc.data() as Map<String, dynamic>;
              
              // Se obtienen los datos de forma segura para evitar errores de tipo nulo
              final String docId = signDoc.id;
              final String title = signData['titulo'] ?? 'Sin título';
              final String thumbnailUrl = signData['url_miniatura'] ?? '';
              final String mediaUrl = signData['url_media'] ?? '';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: SizedBox(
                    width: 80,
                    height: 80,
                    child: thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                        )
                      : const Icon(Icons.image, size: 80, color: Colors.grey),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID del documento: $docId'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EditSignPage(
                                docId: docId,
                                initialData: signData,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmationDialog(context, docId, mediaUrl, thumbnailUrl),
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
