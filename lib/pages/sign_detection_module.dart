import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

// Este widget con estado gestionará la cámara y la detección
class SignDetectionModule extends StatefulWidget {
  const SignDetectionModule({super.key});

  @override
  State<SignDetectionModule> createState() => _SignDetectionModuleState();
}

class _SignDetectionModuleState extends State<SignDetectionModule> {
  // Controlador de la cámara
  CameraController? _cameraController;
  // Intérprete para el modelo TFLite
  Interpreter? _interpreter;
  // Etiquetas del modelo
  List<String> _labels = [];
  // Variable para almacenar el signo detectado
  String _detectedSign = '';
  // Bandera para evitar múltiples ejecuciones de detección
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndModel();
  }

  // Inicializa la cámara y carga el modelo TFLite
  Future<void> _initializeCameraAndModel() async {
    // 1. Solicitar permisos de cámara
    if (await Permission.camera.request().isDenied) {
      // Manejar el caso si el usuario deniega el permiso
      if (mounted) {
        // En un entorno de producción, aquí se mostraría un diálogo al usuario.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado')),
        );
      }
      return;
    }

    // 2. Cargar el modelo TFLite y las etiquetas
    try {
      _interpreter = await Interpreter.fromAsset('assets/sign_model.tflite');
      _labels = await _loadLabels('assets/labels.txt');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el modelo o las etiquetas: $e')),
        );
      }
      return;
    }

    // 3. Inicializar la cámara
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron cámaras disponibles')),
        );
      }
      return;
    }

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await _cameraController!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});

      // 4. Comenzar a procesar el stream de la cámara
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isDetecting) {
          _isDetecting = true;
          _detectSign(image);
        }
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        // Manejar errores de la cámara
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de cámara: ${e.description}')),
          );
        }
      }
    });
  }

  // Carga las etiquetas del archivo assets
  Future<List<String>> _loadLabels(String path) async {
    final file = await rootBundle.loadString(path);
    return file.split('\n').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();
  }

  // Convierte la imagen de la cámara y la procesa con el modelo
  void _detectSign(CameraImage image) {
    if (_interpreter == null || _labels.isEmpty) {
      _isDetecting = false;
      return;
    }

    // Prepara la entrada del modelo
    // NOTA: Esta es una simplificación. La conversión de CameraImage (formato YUV) a
    // un tensor [1, 100, 100, 3] para el modelo es un proceso complejo que
    // a menudo requiere paquetes adicionales o lógica nativa. Aquí se asume
    // una lógica de conversión simple para demostrar el flujo.
    var input = _preprocessImage(image);
    var output = List.filled(1 * _labels.length, 0).reshape([1, _labels.length]);

    // Ejecuta la inferencia
    _interpreter!.run(input, output);

    // Procesa el resultado para encontrar la predicción con mayor probabilidad
    var probabilities = output[0];
    var maxProb = 0.0;
    var predictedIndex = -1;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        predictedIndex = i;
      }
    }

    // Actualiza el estado con el signo detectado
    if (mounted) {
      setState(() {
        _detectedSign = (predictedIndex != -1 && maxProb > 0.5)
            ? _labels[predictedIndex]
            : 'Esperando...';
      });
    }

    _isDetecting = false;
  }

  // Función dummy para el preprocesamiento de la imagen
  // En un caso real, esto convertiría el formato de la cámara (YUV)
  // al formato de entrada del modelo (RGB, tensor, etc.)
  List<Object> _preprocessImage(CameraImage image) {
    // Aquí iría la lógica real de conversión.
    // Se recomienda usar un paquete como 'image' para este proceso.
    return [
      List.filled(100 * 100 * 3, 0.0) // Dummy data
    ];
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección de Señas'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Vista previa de la cámara
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          // Cuadro para mostrar el texto de la detección
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _detectedSign,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
