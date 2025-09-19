import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;


class SignDetectionModule extends StatefulWidget {
  const SignDetectionModule({super.key});

  @override
  State<SignDetectionModule> createState() => _SignDetectionModuleState();
}

class _SignDetectionModuleState extends State<SignDetectionModule> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  String _statusMessage = "Iniciando la cámara...";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Inicializa la cámara seleccionada
  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _statusMessage = "Permiso de cámara denegado.";
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _statusMessage = "No hay cámaras disponibles.";
        });
        return;
      }

      // Selecciona la cámara actual según el índice
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.low, // Resolución baja para mejor rendimiento
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = "Cámara lista. Esperando seña...";
      });

      // Inicia el "stream" de imágenes para el módulo de detección
      _cameraController!.startImageStream((CameraImage image) async {
        setState(() {
        });
      });
    } on CameraException catch (e) {
      print("Error al inicializar la cámara: $e");
      setState(() {
        _statusMessage = "Error al inicializar la cámara.";
      });
    }
  }

  // Cambia a la siguiente cámara disponible
  void _toggleCamera() async {
    if (_cameras.isEmpty) return;

    // Detiene la cámara actual para poder cambiarla
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    // Vuelve a inicializar con la nueva cámara seleccionada
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
@override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
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

    return Scaffold(
      body: Stack(
        children: [
          // Muestra la vista de la cámara en pantalla completa, ajustada para no estirarse.
          // Aquí está la corrección:
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          
          // Muestra el mensaje de estado en la parte inferior
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              width: double.infinity,
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Botón para cambiar de cámara
          if (_cameras.length > 1)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _toggleCamera,
                backgroundColor: Colors.white54,
                child: const Icon(Icons.flip_camera_ios, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
  
}