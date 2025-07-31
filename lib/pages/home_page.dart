import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore
//import 'package:firebase_storage/firebase_storage.dart'







class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instancia de Firestore

  bool _speechEnabled = false;
  String _wordsSpoken = "";
  double _confidenceLevel = 0;
  String _currentLocaleId = '';

  List<Map<String, dynamic>> _foundGifs = []; // Lista para almacenar GIFs encontrados (cambio de nombre)
  bool _isLoadingGifs = false; // Estado de carga para los GIFs

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
        orElse: () => locales.firstWhere( // Fallback a inglés si no hay español
          (locale) => locale.localeId.startsWith('en'),
          orElse: () => locales.first, // Si no hay ni español ni inglés, usa el primero
        ),
      );
      _currentLocaleId = spanishLocale.localeId;
    }
    setState(() {});
  }

  void _startListening() async {
    // Limpiar resultados anteriores antes de empezar a escuchar
    setState(() {
      _wordsSpoken = "";
      _confidenceLevel = 0;
      _foundGifs = []; // Limpiar GIFs encontrados
    });
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _currentLocaleId,
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      // Opcional: Iniciar la búsqueda automáticamente al dejar de escuchar
      if (_wordsSpoken.isNotEmpty) {
        _searchGifs(_wordsSpoken); // Llama a la nueva función de búsqueda de GIFs
      }
    });
  }

  void _onSpeechResult(result) {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;
    });
  }

  // --- FUNCIÓN PARA BUSCAR GIFs EN FIREBASE ---
  void _searchGifs(String query) async { // Renombrada de _searchVideos a _searchGifs
    if (query.isEmpty) {
      setState(() {
        _foundGifs = [];
      });
      return;
    }

    setState(() {
      _isLoadingGifs = true; // Actualiza el estado de carga para GIFs
    });

    try {
      List<String> keywords = query.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

      final querySnapshot = await _firestore
          .collection('gifs') // ¡CAMBIO IMPORTANTE! Asegúrate de que este sea el nombre de tu colección de GIFs
          .where('palabras_clave', arrayContainsAny: keywords)
          .orderBy('vistas', descending: true)
          .limit(20)
          .get();

      setState(() {
        _foundGifs = querySnapshot.docs.map((doc) => doc.data()).toList();
        _isLoadingGifs = false;
      });
    } catch (e) {
      print("Error buscando GIFs: $e");
      setState(() {
        _isLoadingGifs = false;
        _foundGifs = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar GIFs. Intenta de nuevo.')),
      );
    }
  }

  // --- WIDGET PARA MOSTRAR LA LISTA DE GIFs ---
  Widget _buildGifList() { // Renombrada de _buildVideoList a _buildGifList
    if (_isLoadingGifs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_foundGifs.isEmpty && _wordsSpoken.isNotEmpty && !_speechToText.isListening) {
      return const Center(child: Text("No se encontraron GIFs para tu búsqueda."));
    }
    if (_foundGifs.isEmpty && _wordsSpoken.isEmpty && !_speechToText.isListening && _speechEnabled) {
      return const Center(child: Text("Presiona el micrófono y di algo para buscar GIFs."));
    }
    if (!_speechEnabled) {
      return const Center(child: Text("El micrófono no está habilitado."));
    }

    return ListView.builder(
      itemCount: _foundGifs.length,
      itemBuilder: (context, index) {
        final gif = _foundGifs[index]; // Renombrada de 'video' a 'gif'
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          child: ListTile(
            leading: gif['url_miniatura'] != null && gif['url_miniatura'].isNotEmpty
                ? Image.network(
                    gif['url_miniatura'],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.gif_box, size: 50), // Icono de GIF
                  )
                : const Icon(Icons.gif_box, size: 50), // Icono de GIF
            title: Text(gif['titulo'] ?? 'Sin título'),
            subtitle: Text(gif['descripcion'] ?? 'Sin descripción'),
            trailing: Text('${gif['vistas'] ?? 0} vistas'),
            onTap: () {
              // Navegar a una página de visualización de GIF
              if (gif['url_gif'] != null && gif['url_gif'].isNotEmpty) { // ¡CAMBIO IMPORTANTE! Usar 'url_gif'
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GifViewerPage( // ¡CAMBIO IMPORTANTE! Navegar a GifViewerPage
                      gifUrl: gif['url_gif'],
                      title: gif['titulo'] ?? 'GIF', // Pasar el título a la página del GIF
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL del GIF no disponible.')),
                );
              }
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
          'Buscador de GIFs por Voz', // Título actualizado
          style: TextStyle(
            color: Colors.white,
          ),
        ),
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
          Expanded(child: _buildGifList()), // Mostrar la lista de GIFs aquí
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

// --- NUEVA PÁGINA PARA VISUALIZAR EL GIF ---
class GifViewerPage extends StatelessWidget { // Cambiada de StatefulWidget a StatelessWidget (más simple para solo mostrar)
  final String gifUrl;
  final String title; // Campo para mostrar el título del GIF en el AppBar

  const GifViewerPage({super.key, required this.gifUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title), // Muestra el título del GIF
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Center(
        child: Image.network(
          gifUrl,
          fit: BoxFit.contain, // Ajusta cómo el GIF se muestra dentro de su espacio
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Text('No se pudo cargar el GIF');
          },
        ),
      ),
    );
  }
}