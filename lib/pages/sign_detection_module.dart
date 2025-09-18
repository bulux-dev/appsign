import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

// Este es el único archivo para el módulo de detección de señas.
// El resto de la lógica de la aplicación puede llamar a este widget.

// NOTA: Para que este código funcione, debes agregar la dependencia 'http'
// a tu archivo pubspec.yaml:
// dependencies:
//   flutter:
//     sdk: flutter
//   camera: ^0.10.5+9
//   permission_handler: ^10.4.5
//   http: ^1.1.0

/// Simula la comunicación con un servicio de API externo.
/// En un proyecto real, esta clase estaría en su propio archivo,
/// pero la incluimos aquí para mantener todo en un solo lugar.
class ApiService {
  final String _apiEndpoint = "http://localhost:5000/predict"; // Reemplaza con la URL de tu API
  
  // Envía un frame de la cámara a la API para su procesamiento.
  Future<String> sendFrameToApi(CameraImage image) async {
    try {
      // Convierte los datos de la imagen a un formato que la API pueda entender (por ejemplo, JPEG).
      // Aquí estamos simulando el proceso, en la práctica necesitarías un convertidor
      // de CameraImage a un formato de imagen real.
      final Uint8List fakeImageData = Uint8List(100);

      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: fakeImageData, // Enviar los datos de la imagen aquí
      );

      if (response.statusCode == 200) {
        // La llamada fue exitosa.
        return response.body; // Retorna la predicción de la API
      } else {
        // La llamada falló, maneja el error.
        print('Error en la API: ${response.statusCode}');
        return "Error en la API";
      }
    } catch (e) {
      // Ocurrió un error de red, como no poder conectar al servidor.
      print('Excepción al enviar frame: $e');
      return "Sin conexión con el servidor";
    }
  }
}

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
  final ApiService _apiService = ApiService();

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
        // Envía el frame a la API y actualiza el estado con la predicción
        final prediction = await _apiService.sendFrameToApi(image);
        setState(() {
          _statusMessage = prediction;
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
          // Muestra la vista de la cámara en pantalla completa
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
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
