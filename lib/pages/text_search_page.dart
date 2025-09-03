import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TextSearchPage extends StatefulWidget {
  const TextSearchPage({super.key});

  @override
  State<TextSearchPage> createState() => _TextSearchPageState();
}

class _TextSearchPageState extends State<TextSearchPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _foundContent = [];
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    // Iniciar la búsqueda con una cadena vacía para mostrar todo el contenido
    //_searchContent(''); // <-- Comentamos esta línea para no buscar nada al inicio
  }

  // --- FUNCIÓN PARA BUSCAR CONTENIDO EN FIRESTORE ---
  void _searchContent(String query) async {
    setState(() {
      _isLoadingContent = true;
    });

    try {
      final String searchQuery = query.toLowerCase().trim();
      
      // Si la consulta está vacía, no se muestran resultados.
      if (searchQuery.isEmpty) {
        setState(() {
          _foundContent = [];
          _isLoadingContent = false;
        });
        return; // Salir de la función para no continuar con la búsqueda
      }

      final querySnapshot = await _firestore.collection('content').get();
      List<Map<String, dynamic>> allContent = querySnapshot.docs.map((doc) => doc.data()).toList();

      List<Map<String, dynamic>> results = [];

      // Dividir la frase en palabras y buscar por cada una
      final List<String> searchTerms = searchQuery.split(' ');

      for (String term in searchTerms) {
        final trimmedTerm = term.trim();
        if (trimmedTerm.isEmpty) continue;

        final filteredContent = allContent.where((content) {
          final title = content['titulo']?.toLowerCase() ?? '';
          final description = content['descripcion']?.toLowerCase() ?? '';
          final keywords = (content['palabras_clave'] as List<dynamic>?)?.map((k) => k.toString().toLowerCase()).toList() ?? [];

          return title.contains(trimmedTerm) ||
                 description.contains(trimmedTerm) ||
                 keywords.any((keyword) => keyword.contains(trimmedTerm));
        }).toList();

        for (var item in filteredContent) {
          // Evitar duplicados
          if (!results.any((result) => result['titulo'] == item['titulo'])) {
            results.add(item);
          }
        }
      }
      
      setState(() {
        _foundContent = results;
        _isLoadingContent = false;
      });

    } catch (e) {
      print("Error buscando contenido: $e");
      setState(() {
        _isLoadingContent = false;
        _foundContent = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar contenido. Intenta de nuevo.')),
      );
    }
  }

  // --- WIDGET PARA MOSTRAR LA LISTA DE CONTENIDO ---
  Widget _buildContentList() {
    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_foundContent.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text("No se encontró contenido para tu búsqueda."));
    }
    
    if (_foundContent.isEmpty && _searchController.text.isEmpty) {
      return const Center(child: Text("Escribe una frase para buscar señas."));
    }

    return ListView.builder(
      itemCount: _foundContent.length,
      itemBuilder: (context, index) {
        final content = _foundContent[index];
        ///ignore: unused_local_variable
        final String mediaUrl = content['url_media'] ?? '';
        final String thumbnailUrl = content['url_miniatura'] ?? '';
        final String mediaType = content['tipo'] ?? '';
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          child: ListTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                if (mediaType == 'mp4')
                  const Icon(Icons.play_circle_fill, size: 40, color: Colors.white70),
              ],
            ),
            title: Text(content['titulo'] ?? 'Sin título'),
            subtitle: Text(content['descripcion'] ?? 'Sin descripción'),
            trailing: Text('${content['vistas'] ?? 0} vistas'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tocado: ${content['titulo']}')),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Buscador de Señas',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Cerrar Sesion',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'escribe una frase...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _searchContent(_searchController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContentList()),
        ],
      ),
    );
  }
}
