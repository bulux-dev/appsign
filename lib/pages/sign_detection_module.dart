import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KeypointTestPage extends StatefulWidget {
  @override
  _KeypointTestPageState createState() => _KeypointTestPageState();
}

class _KeypointTestPageState extends State<KeypointTestPage> {
  String _response = "Esperando respuesta...";

  Future<void> sendKeypoints() async {
    final url = Uri.parse("http://178.128.181.235/predict");

    // Ejemplo de keypoints (aquí se sustituirán por los capturados con la cámara)
    final keypoints = [0.1, 0.5, 0.3, 0.9];

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"keypoints": keypoints}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _response = "✅ Respuesta: ${response.body}";
        });
      } else {
        setState(() {
          _response = "❌ Error: ${response.statusCode} -> ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _response = "⚠️ Error conectando al servidor: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Prueba Keypoints -> Servidor")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_response),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendKeypoints,
              child: Text("Enviar keypoints"),
            ),
          ],
        ),
      ),
    );
  }
}
