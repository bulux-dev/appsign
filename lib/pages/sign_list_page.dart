import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:appsign/pages/edit_sign_page.dart';

// Se ha cambiado a StatefulWidget para manejar el estado del campo de búsqueda y la lista.
class SignListPage extends StatefulWidget {
  const SignListPage({super.key});

  @override
  State<SignListPage> createState() => _SignListPageState();
}

class _SignListPageState extends State<SignListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _allSigns = [];
  List<DocumentSnapshot> _filteredSigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSigns();
    _searchController.addListener(_filterSigns);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSigns);
    _searchController.dispose();
    super.dispose();
  }

  // Método para obtener la lista completa de señas de Firestore
  void _fetchSigns() {
    FirebaseFirestore.instance.collection('content').snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _allSigns = snapshot.docs;
          _filterSigns(); // Llama a la función de filtro para mostrar todos al inicio
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Error al obtener señas: $error');
      }
    });
  }

  // Método para filtrar la lista de señas basada en el texto de búsqueda
  void _filterSigns() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredSigns = _allSigns;
      });
    } else {
      setState(() {
        _filteredSigns = _allSigns.where((signDoc) {
          final signData = signDoc.data() as Map<String, dynamic>;
          final title = signData['titulo']?.toLowerCase() ?? '';
          final description = signData['descripcion']?.toLowerCase() ?? '';
          final keywords = (signData['palabras_clave'] as List<dynamic>?)?.map((k) => k.toString().toLowerCase()).toList() ?? [];

          return title.contains(query) ||
                 description.contains(query) ||
                 keywords.any((keyword) => keyword.contains(query));
        }).toList();
      });
    }
  }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por título o palabra clave...',
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
                : _filteredSigns.isEmpty && _searchController.text.isNotEmpty
                    ? const Center(child: Text('No se encontraron señas.'))
                    : _filteredSigns.isEmpty && _searchController.text.isEmpty
                        ? const Center(child: Text('No hay señas para mostrar.'))
                        : ListView.builder(
                            itemCount: _filteredSigns.length,
                            itemBuilder: (context, index) {
                              final signDoc = _filteredSigns[index];
                              final signData = signDoc.data() as Map<String, dynamic>;
                              
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
                          ),
          ),
        ],
      ),
    );
  }
}
