import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

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
  
  // Variables para TensorFlow Lite
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  
  // Variables para detección
  String _detectedSign = "";
  double _confidence = 0.0;
  List<Map<String, dynamic>> _handKeypoints = [];
  List<Map<String, dynamic>> _faceKeypoints = [];
  
  // Variables para el historial de detecciones
  List<String> _detectionHistory = [];
  String _translatedText = "";

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
    _initializeCamera();
  }

  // Carga el modelo TensorFlow Lite
  Future<void> _loadModel() async {
    try {
      print("Intentando cargar modelo TensorFlow Lite...");
      
      // Verifica si el archivo existe
      try {
        await rootBundle.load('assets/actions.tflite');
        print("✓ Archivo actions.tflite encontrado");
      } catch (e) {
        print("✗ Error: No se encontró assets/actions.tflite");
        print("Modo demo activado - simulando detecciones");
        setState(() {
          _isModelLoaded = true; // Activamos modo demo
          _statusMessage = "Modo DEMO - Sin modelo real";
        });
        return;
      }
      
      _interpreter = await Interpreter.fromAsset('assets/actions.tflite');
      
      print("✓ Modelo cargado exitosamente");
      print("Input shape: ${_interpreter!.getInputTensor(0).shape}");
      print("Output shape: ${_interpreter!.getOutputTensor(0).shape}");
      print("Número de tensores de entrada: ${_interpreter!.getInputTensors().length}");
      print("Número de tensores de salida: ${_interpreter!.getOutputTensors().length}");
      
      setState(() {
        _isModelLoaded = true;
        _statusMessage = "Modelo cargado correctamente";
      });
      
    } catch (e) {
      print("✗ Error detallado cargando el modelo: $e");
      print("Tipo de error: ${e.runtimeType}");
      print("Activando modo demo para pruebas...");
      
      // En lugar de fallar, activamos modo demo
      setState(() {
        _isModelLoaded = true; // Modo demo
        _statusMessage = "Modo DEMO - Error en modelo: ${e.toString().split('.').first}";
      });
    }
  }

  // Carga las etiquetas desde el archivo
  Future<void> _loadLabels() async {
    try {
      print("Cargando etiquetas...");
      
      // Verifica si el archivo existe
      try {
        await rootBundle.load('assets/labels.txt');
        print("✓ Archivo labels.txt encontrado");
      } catch (e) {
        print("✗ Advertencia: No se encontró assets/labels.txt");
        print("Creando etiquetas por defecto...");
        _labels = ['Seña_1', 'Seña_2', 'Seña_3'];
        return;
      }
      
      String labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
      
      print("✓ Etiquetas cargadas: ${_labels.length}");
      print("Etiquetas: $_labels");
      
    } catch (e) {
      print("✗ Error cargando etiquetas: $e");
      _labels = ['Seña_Desconocida'];
    }
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

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = _isModelLoaded ? 
          "Sistema listo. Muestra una seña..." : 
          "Cargando modelo de IA...";
      });

      // Inicia el stream de imágenes
      _cameraController!.startImageStream(_processImage);
      
    } on CameraException catch (e) {
      print("Error al inicializar la cámara: $e");
      setState(() {
        _statusMessage = "Error al inicializar la cámara.";
      });
    }
  }

  // Procesa cada frame de la cámara
  Future<void> _processImage(CameraImage image) async {
    if (!_isModelLoaded || _isProcessing || _interpreter == null) {
      return;
    }

    _isProcessing = true;

    try {
      // Convierte la imagen de la cámara
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        // Extrae keypoints y clasifica
        await _detectAndClassify(inputImage);
      }
    } catch (e) {
      print("Error procesando imagen: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // Convierte CameraImage a formato procesable
  Uint8List? _convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToRGB(image);
      }
      return null;
    } catch (e) {
      print("Error convirtiendo imagen: $e");
      return null;
    }
  }

  // Convierte YUV420 a RGB
  Uint8List _convertYUV420ToRGB(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    
    final Uint8List rgbBytes = Uint8List(width * height * 3);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        
        final int yValue = image.planes[0].bytes[yIndex];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];
        
        // Conversión YUV a RGB
        int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
        int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        final int rgbIndex = yIndex * 3;
        rgbBytes[rgbIndex] = r;
        rgbBytes[rgbIndex + 1] = g;
        rgbBytes[rgbIndex + 2] = b;
      }
    }
    
    return rgbBytes;
  }

  // Redimensiona la imagen al tamaño requerido por el modelo
  Uint8List _resizeImage(Uint8List imageBytes, int originalWidth, int originalHeight, int targetWidth, int targetHeight) {
    // Crear imagen desde bytes RGB
    img.Image? originalImage = img.Image.fromBytes(
      width: originalWidth,
      height: originalHeight,
      bytes: imageBytes.buffer,
      format: img.Format.uint8,
      numChannels: 3,
    );
    
    if (originalImage == null) {
      throw Exception("No se pudo crear la imagen");
    }
    
    // Redimensionar
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: targetWidth,
      height: targetHeight,
    );
    
    // Convertir a Float32List normalizado
    final Float32List normalizedBytes = Float32List(targetWidth * targetHeight * 3);
    int index = 0;
    
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        img.Pixel pixel = resizedImage.getPixel(x, y);
        normalizedBytes[index++] = pixel.r / 255.0;
        normalizedBytes[index++] = pixel.g / 255.0;
        normalizedBytes[index++] = pixel.b / 255.0;
      }
    }
    
    return normalizedBytes.buffer.asUint8List();
  }

  // Detecta keypoints y clasifica la seña
  Future<void> _detectAndClassify(Uint8List imageBytes) async {
    try {
      // Modo demo si no hay interpreter
      if (_interpreter == null) {
        await _simulateDetection();
        return;
      }
      
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      
      // Asume que la imagen original es del tamaño de la cámara
      final cameraSize = _cameraController?.value.previewSize;
      if (cameraSize == null) return;
      
      // Redimensiona la imagen
      final resizedImage = _resizeImage(
        imageBytes,
        cameraSize.width.toInt(),
        cameraSize.height.toInt(),
        inputWidth,
        inputHeight
      );
      
      // Prepara la entrada para el modelo
      final input = resizedImage.buffer.asFloat32List().reshape([1, inputHeight, inputWidth, 3]);
      
      // Prepara la salida
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.generate(outputShape[0], (_) => List.filled(outputShape[1], 0.0));
      
      // Ejecuta la inferencia
      _interpreter!.run(input, output);
      
      // Procesa los resultados
      _processResults(output[0]);
      
    } catch (e) {
      print("Error en detección y clasificación: $e");
      // Si hay error, usa modo demo
      await _simulateDetection();
    }
  }

  // Simula detecciones para modo demo
  Future<void> _simulateDetection() async {
    // Simula detección cada 3 segundos
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (DateTime.now().millisecond % 30 == 0) { // Simula detección ocasional
      final random = DateTime.now().millisecond % _labels.length;
      final randomConfidence = 0.75 + (DateTime.now().millisecond % 20) / 100;
      
      String detectedLabel = _labels[random];
      
      setState(() {
        _detectedSign = detectedLabel;
        _confidence = randomConfidence;
        _statusMessage = "DEMO - Detectado: $detectedLabel (${(randomConfidence * 100).toStringAsFixed(1)}%)";
      });
      
      // Añade a la historia si es diferente al último
      if (_detectionHistory.isEmpty || _detectionHistory.last != detectedLabel) {
        _detectionHistory.add(detectedLabel);
        _updateTranslatedText();
      }
    } else if (DateTime.now().millisecond % 15 == 0) {
      setState(() {
        _detectedSign = "";
        _confidence = 0.0;
        _statusMessage = "DEMO - Muestra una seña...";
      });
    }
  }

  // Procesa los resultados de la inferencia
  void _processResults(List<double> output) {
    // Encuentra la clase con mayor probabilidad
    double maxConfidence = 0.0;
    int maxIndex = 0;
    
    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }
    
    // Solo actualiza si la confianza es suficientemente alta
    if (maxConfidence > 0.7) {
      String detectedLabel = maxIndex < _labels.length ? 
        _labels[maxIndex] : 'Desconocido';
      
      setState(() {
        _detectedSign = detectedLabel;
        _confidence = maxConfidence;
        _statusMessage = "Detectado: $detectedLabel (${(maxConfidence * 100).toStringAsFixed(1)}%)";
      });
      
      // Añade a la historia si es diferente al último
      if (_detectionHistory.isEmpty || _detectionHistory.last != detectedLabel) {
        _detectionHistory.add(detectedLabel);
        _updateTranslatedText();
      }
    } else {
      setState(() {
        _detectedSign = "";
        _confidence = 0.0;
        _statusMessage = "Muestra una seña más clara...";
      });
    }
  }

  // Actualiza el texto traducido
  void _updateTranslatedText() {
    if (_detectionHistory.isNotEmpty) {
      setState(() {
        _translatedText = _detectionHistory.join(' ');
      });
    }
  }

  // Limpia el historial
  void _clearHistory() {
    setState(() {
      _detectionHistory.clear();
      _translatedText = "";
      _detectedSign = "";
      _confidence = 0.0;
      _statusMessage = "Historial limpiado. Muestra una seña...";
    });
  }

  // Cambia a la siguiente cámara disponible
  void _toggleCamera() async {
    if (_cameras.isEmpty) return;

    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    
    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
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
              Text(_statusMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Vista de la cámara
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

          // Panel de información superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del sistema
                  Row(
                    children: [
                      Icon(
                        _isModelLoaded ? 
                          (_interpreter != null ? Icons.check_circle : Icons.info) : 
                          Icons.error,
                        color: _isModelLoaded ? 
                          (_interpreter != null ? Colors.green : Colors.orange) : 
                          Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _interpreter != null ? "Modelo: Real" : 
                        (_isModelLoaded ? "Modelo: Demo" : "Modelo: Error"),
                        style: TextStyle(
                          color: _isModelLoaded ? 
                            (_interpreter != null ? Colors.green : Colors.orange) : 
                            Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        _labels.isNotEmpty ? Icons.check_circle : Icons.error,
                        color: _labels.isNotEmpty ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Etiquetas: ${_labels.length}",
                        style: TextStyle(
                          color: _labels.isNotEmpty ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  if (_detectedSign.isNotEmpty) ...[
                    Text(
                      "Seña detectada: $_detectedSign",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Confianza: ${(_confidence * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_translatedText.isNotEmpty) ...[
                    const Text(
                      "Texto traducido:",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _translatedText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Panel de estado inferior
          Positioned(
            bottom: 100,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Botones de control
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón limpiar historial
                FloatingActionButton(
                  heroTag: "clear",
                  onPressed: _clearHistory,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  child: const Icon(Icons.clear, color: Colors.white),
                ),
                
                // Botón cambiar cámara
                if (_cameras.length > 1)
                  FloatingActionButton(
                    heroTag: "camera",
                    onPressed: _toggleCamera,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: const Icon(Icons.flip_camera_ios, color: Colors.black),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}