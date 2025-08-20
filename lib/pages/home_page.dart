import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Asegúrate de tener este paquete

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _speechEnabled = false;
  String _wordsSpoken = "";
  double _confidenceLevel = 0;
  String _currentLocaleId = '';

  List<Map<String, dynamic>> _foundContent = [];
  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      var locales = await _speechToText.locales();
      var spanishLocale = locales.firstWhere(
        (locale) => locale.localeId.startsWith('es'),
        orElse: () => locales.firstWhere(
          (locale) => locale.localeId.startsWith('en'),
          orElse: () => locales.first,
        ),
      );
      _currentLocaleId = spanishLocale.localeId;
    }
    setState(() {});
  }

  void _startListening() async {
    setState(() {
      _wordsSpoken = "";
      _confidenceLevel = 0;
      _foundContent = [];
    });
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _currentLocaleId,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      if (_wordsSpoken.isNotEmpty) {
        _searchContent(_wordsSpoken);
      }
    });
  }

  void _onSpeechResult(result) {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;
    });
  }

  // --- FUNCIÓN PARA BUSCAR CONTENIDO EN FIREBASE ---
  void _searchContent(String query) async {
    if (query.isEmpty) {
      setState(() {
        _foundContent = [];
      });
      return;
    }

    setState(() {
      _isLoadingContent = true;
    });

    try {
      final List<String> searchTerms = query.toLowerCase().trim().split(' ');

      // Ahora buscamos en la colección 'content'
      final querySnapshot = await _firestore
          .collection('content')
          .where('palabras_clave', arrayContainsAny: searchTerms)
          .get();

      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
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
    
    if (_foundContent.isEmpty && _wordsSpoken.isNotEmpty && !_speechToText.isListening) {
      return const Center(child: Text("No se encontró contenido para tu búsqueda."));
    }
    
    if (_foundContent.isEmpty && _wordsSpoken.isEmpty && !_speechToText.isListening && _speechEnabled) {
      return const Center(child: Text("Presiona el micrófono y di algo para buscar señas."));
    }
    
    if (!_speechEnabled) {
      return const Center(child: Text("El micrófono no está habilitado."));
    }

    return ListView.builder(
      itemCount: _foundContent.length,
      itemBuilder: (context, index) {
        final content = _foundContent[index];
        final String mediaUrl = content['url_media'] ?? '';
        final String thumbnailUrl = content['url_miniatura'] ?? '';
        final String mediaType = content['tipo'] ?? 'gif'; // Valor por defecto 'gif'
        
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
              // Aquí podrías implementar la navegación a una página de visualización
              // de video o GIF, pero por ahora solo es un mensaje.
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Buscador de Señas por Voz',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout,color: Colors.white),
            onPressed:() async{
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Cerrar Sesion',
          ),
        ]
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              _speechToText.isListening
                  ? "Escuchando..."
                  : _speechEnabled
                      ? "Presiona el botón del micrófono para buscar."
                      : "El micrófono necesita permisos para escuchar.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (_wordsSpoken.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text(
                    "Dijiste: \"$_wordsSpoken\"",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_confidenceLevel > 0)
                    Text(
                      "Confianza: ${(_confidenceLevel * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          Expanded(child: _buildContentList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speechToText.isListening ? _stopListening : _startListening,
        tooltip: 'Escuchar',
        backgroundColor: Colors.deepPurple,
        child: Icon(
          _speechToText.isNotListening ? Icons.mic_none : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }
}
