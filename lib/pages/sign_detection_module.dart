import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class SignDetectionModule extends StatefulWidget {
  const SignDetectionModule({super.key});

  @override
  State<SignDetectionModule> createState() => _SignDetectionModuleState();
}

class _SignDetectionModuleState extends State<SignDetectionModule> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  String _statusMessage = "Iniciando la cámara...";

  @override
  void initState() {
    super.initState();
    // Inicia el proceso de configuración de la cámara al iniciar el widget.
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 1. Solicita permiso de acceso a la cámara.
    final status = await Permission.camera.request();

    if (status.isGranted) {
      // 2. Si el permiso es concedido, busca las cámaras disponibles en el dispositivo.
      try {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          // 3. Selecciona la primera cámara de la lista y la inicializa.
          _cameraController = CameraController(
            _cameras.first,
            ResolutionPreset.high,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );

          await _cameraController!.initialize();

          // 4. Muestra la vista previa de la cámara y empieza a procesar los cuadros de video.
          if (!mounted) {
            return;
          }
          setState(() {
            _isCameraInitialized = true;
          });

          // Inicia el "stream" de imágenes. Aquí pasarás cada cuadro a tu modelo de ML.
          _cameraController!.startImageStream((CameraImage image) {
            // AQUI ES DONDE VA LA LÓGICA DE DETECCIÓN DE SEÑAS CON UN MODELO DE ML
            // Por ejemplo:
            // final recognizedSign = YourMLModel.detectSign(image);
            // setState(() {
            //   _statusMessage = recognizedSign;
            // });
          });
        }
      } on CameraException catch (e) {
        // Maneja errores de la cámara.
        print("Error al inicializar la cámara: $e");
        setState(() {
          _statusMessage = "Error al inicializar la cámara.";
        });
      }
    } else {
      // Si el permiso es denegado, muestra un mensaje.
      setState(() {
        _statusMessage = "Permiso de cámara denegado.";
      });
    }
  }

  @override
  void dispose() {
    // Asegúrate de detener el controlador de la cámara cuando el widget se destruya.
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      // Muestra un indicador de carga mientras la cámara se inicializa.
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

    // Muestra la vista de la cámara.
    return Scaffold(
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController!),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              width: double.infinity,
              child: Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
