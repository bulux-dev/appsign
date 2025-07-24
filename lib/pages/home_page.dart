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

  @override
  void initState() {
    
    super.initState();
  }
  void initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {
      
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}