import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class SignDetectionModule extends StatefulWidget {
  const SignDetectionModule({super.key});

  @override
  State<SignDetectionModule> createState() => _SignDetectionModuleState();
}

class _SignDetectionModuleState extends State<SignDetectionModule> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRearCamera = true;
  String _statusMessage = "Iniciando cámara...";
  String _predictionResult = "";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _statusMessage = "Permiso de cámara denegado.";
      });
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() {
        _statusMessage = "No hay cámaras disponibles.";
      });
      return;
    }

    _startCamera(_cameras.first);
  }

  Future<void> _startCamera(CameraDescription camera) async {
    _cameraController?.dispose();
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
    });

    // Aquí puedes iniciar tu stream y extraer keypoints si integras ML
    _cameraController!.startImageStream((image) {
      // Ejemplo: keypoints simulados
      List<double> keypoints = [0.1, 0.5, 0.3, 0.9];
      _sendKeypoints(keypoints);
    });
  }

  Future<void> _sendKeypoints(List<double> keypoints) async {
    final url = Uri.parse('http://178.128.181.235/predict');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"keypoints": keypoints}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _predictionResult = data.toString();
        });
      } else {
        setState(() {
          _predictionResult = "Error del servidor: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _predictionResult = "Error conectando al servidor: $e";
      });
    }
  }

  void _toggleCamera() {
    if (_cameras.length < 2) return;
    _isRearCamera = !_isRearCamera;
    _startCamera(_isRearCamera ? _cameras.first : _cameras.last);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detección de Señales"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _toggleCamera,
          ),
        ],
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    width: double.infinity,
                    child: Text(
                      _predictionResult.isEmpty
                          ? _statusMessage
                          : _predictionResult,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusMessage),
                ],
              ),
            ),
    );
  }
}
