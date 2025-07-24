import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();

  bool _speechEnabled = false;
  String _wordsSpoken = "";
  double _confidenceLevel = 0;

  @override
  void initState() { 
    super.initState();
    initSpeech();
  }

  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async  {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {
      _confidenceLevel = 0;
    });
  }

void _stopListening()async{
  await _speechToText.stop();
  setState(() {
    
  });
}
  void _onSpeechResult(result){
    setState(() {
      _wordsSpoken = "${result.recognizedWords}";
      _confidenceLevel = result.confidence; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(
      backgroundColor: Colors.deepPurple,
      title: Text(
        'Prueba de grabado',
        style: TextStyle(
          color: Colors.white,
        ),
        )),
        body: Center(child: Column(
          children: [
          Container(
            padding: EdgeInsets.all(16), 
            child: Text(
              _speechToText.isListening 
                ? "Escuchando..." 
                : _speechEnabled 
                  ? "Presiona el boton de microfono para escuchar..." 
                  : "Microfono necesita permiso para escuchar"),
              ), 
              Expanded(child: Container(child: Text(_wordsSpoken),)),
              if(_speechToText.isNotListening && _confidenceLevel > 0) Text(
                "Nivel de confianza: ${(_confidenceLevel * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  color: Colors.green,  
                  fontSize: 30,
                ),
              ),
                 
          ],
        ),
        ),

        floatingActionButton: FloatingActionButton(onPressed: _speechToText.isListening ? _stopListening : _startListening,
        tooltip: 'Escuchar',
        child: Icon(
          _speechToText.isNotListening ? Icons.mic_off : Icons.mic,
          color: Colors.white,  
        )),
     );
  }
}