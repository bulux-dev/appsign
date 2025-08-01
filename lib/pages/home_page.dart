import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  List<Map<String, dynamic>> _foundGifs = [];
  bool _isLoadingGifs = false;

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
      _foundGifs = [];
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
        _searchGifs(_wordsSpoken);
      }
    });
  }

  void _onSpeechResult(result) {
    setState(() {
      _wordsSpoken = result.recognizedWords;
      _confidenceLevel = result.confidence;
    });
  }

  // --- FUNCIÓN PARA BUSCAR GIFs EN FIREBASE (MODIFICADA) ---
  void _searchGifs(String query) async {
    if (query.isEmpty) {
      setState(() {
        _foundGifs = [];
      });
      return;
    }

    setState(() {
      _isLoadingGifs = true;
    });

    try {
      // Prepara la consulta para buscar coincidencias exactas con el array
      // En Firestore, el campo 'palabras_clave' debe ser un array de strings,
      // donde uno de los elementos es exactamente el string de la búsqueda
      final String searchQuery = query.toLowerCase().trim();

      final querySnapshot = await _firestore
          .collection('gifs')
          .where('palabras_clave', arrayContains: searchQuery) // <-- CAMBIO CLAVE: Usamos arrayContains
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

  // --- WIDGET PARA MOSTRAR LA LISTA DE GIFs (MODIFICADO) ---
  Widget _buildGifList() {
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
        final gif = _foundGifs[index];
        final String gifPath = gif['url_gif'];
        final String thumbnailPath = gif['url_miniatura'] ?? '';

        return FutureBuilder<String>(
          future: thumbnailPath.isNotEmpty ? FirebaseStorage.instance.refFromURL(thumbnailPath).getDownloadURL() : Future.value(''),
          builder: (BuildContext context, AsyncSnapshot<String> thumbnailSnapshot) {
            final String thumbnailUrl = thumbnailSnapshot.data ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              child: ListTile(
                leading: thumbnailUrl.isNotEmpty
                    ? Image.network(
                        thumbnailUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.gif_box, size: 50),
                      )
                    : const Icon(Icons.gif_box, size: 50),
                title: Text(gif['titulo'] ?? 'Sin título'),
                subtitle: Text(gif['descripcion'] ?? 'Sin descripción'),
                trailing: Text('${gif['vistas'] ?? 0} vistas'),
                onTap: () async {
                  if (gifPath.isNotEmpty) {
                    try {
                      final String fullGifUrl = await FirebaseStorage.instance.refFromURL(gifPath).getDownloadURL();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GifViewerPage(
                            gifUrl: fullGifUrl,
                            title: gif['titulo'] ?? 'GIF',
                          ),
                        ),
                      );
                    } catch (e) {
                      print("Error al obtener URL del GIF principal: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo cargar el GIF.')),
                      );
                    }
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Buscador de GIFs por Voz',
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
          Expanded(child: _buildGifList()),
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

class GifViewerPage extends StatelessWidget {
  final String gifUrl;
  final String title;

  const GifViewerPage({super.key, required this.gifUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Center(
        child: Image.network(
          gifUrl,
          fit: BoxFit.contain,
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