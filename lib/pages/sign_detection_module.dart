import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:http/http.dart' as http;

class PoseDetectionModule extends StatefulWidget {
  const PoseDetectionModule({super.key});

  @override
  State<PoseDetectionModule> createState() => _PoseDetectionModuleState();
}

class _PoseDetectionModuleState extends State<PoseDetectionModule> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isDetecting = false;
  List<CameraDescription> cameras = [];
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    cameras = await availableCameras();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
      ),
    );
    _startCamera(cameras[_currentCameraIndex]);
  }

  void _startCamera(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();

    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting) {
        _isDetecting = true;
        _processCameraImage(image).whenComplete(() => _isDetecting = false);
      }
    });

    setState(() {});
  }

  void _switchCamera() {
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _startCamera(cameras[_currentCameraIndex]);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        inputImageData: InputImageData(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          imageRotation: _cameraController!.description.sensorOrientation == 90
              ? InputImageRotation.rotation90deg
              : InputImageRotation.rotation0deg,
          inputImageFormat: InputImageFormat.yuv420,
          planeData: image.planes.map((plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            );
          }).toList(),
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final keypoints = poses.first.landmarks.values
            .map((lm) => [lm.x, lm.y, lm.z])
            .expand((e) => e)
            .toList();

        await _sendKeypoints(keypoints);
      }
    } catch (e) {
      print("Error procesando imagen: $e");
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    return Uint8List.fromList(planes.map((p) => p.bytes).expand((x) => x).toList());
  }

  Future<void> _sendKeypoints(List<double> keypoints) async {
    try {
      final response = await http.post(
        Uri.parse("http://178.128.181.235/predict"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"keypoints": keypoints}),
      );

      if (response.statusCode != 200) {
        print("Error al enviar keypoints: ${response.body}");
      } else {
        print("Keypoints enviados correctamente: ${response.body}");
      }
    } catch (e) {
      print("Error de conexión al enviar keypoints: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pose Detection Module")),
      body: Stack(
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            bottom: 30,
            left: 20,
            child: ElevatedButton(
              onPressed: _switchCamera,
              child: const Text("Cambiar Cámara"),
            ),
          ),
        ],
      ),
    );
  }
}
