// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:permission_handler/permission_handler.dart';

// // Este es solo un esqueleto. La lógica para el modelo de ML va aquí.
// // Necesitarías importar paquetes como tflite_flutter para cargar y ejecutar el modelo.
// // import 'package:tflite_flutter/tflite_flutter.dart';

// class SignDetectionModule extends StatefulWidget {
//   const SignDetectionModule({super.key});

//   @override
//   State<SignDetectionModule> createState() => _SignDetectionModuleState();
// }

// class _SignDetectionModuleState extends State<SignDetectionModule> {
//   CameraController? _cameraController;
//   late List<CameraDescription> _cameras;
//   bool _isCameraInitialized = false;
//   String _recognizedText = "Iniciando reconocimiento...";

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissionsAndInitializeCamera();
//   }

//   // Solicita permisos y configura la cámara
//   Future<void> _requestPermissionsAndInitializeCamera() async {
//     final status = await Permission.camera.request();
//     if (status.isGranted) {
//       _cameras = await availableCameras();
//       if (_cameras.isNotEmpty) {
//         _cameraController = CameraController(
//           _cameras.first,
//           ResolutionPreset.high,
//           imageFormatGroup: ImageFormatGroup.yuv420,
//         );

//         _cameraController!.initialize().then((_) {
//           if (!mounted) {
//             return;
//           }
//           setState(() {
//             _isCameraInitialized = true;
//           });

//           // Inicia el procesamiento de cuadros de video aquí
//           _cameraController!.startImageStream((CameraImage image) {
//             // AQUI ES DONDE PASAS CADA IMAGEN AL MODELO DE MACHINE LEARNING
//             // Por ejemplo:
//             // final result = _processImageWithMLModel(image);
//             // setState(() {
//             //   _recognizedText = result;
//             // });
//             //
//             // Esta lógica no está implementada en este código
//           });
//         });
//       }
//     } else {
//       setState(() {
//         _recognizedText = "Permiso de cámara denegado.";
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (!_isCameraInitialized) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     return Scaffold(
//       body: Stack(
//         children: [
//           // Muestra el flujo de video de la cámara
//           Center(
//             child: CameraPreview(_cameraController!),
//           ),
//           // Muestra el texto reconocido en la parte inferior
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               color: Colors.black54,
//               child: Text(
//                 _recognizedText,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

// Este es solo un esqueleto. La lógica para el modelo de ML va aquí.
// Necesitarías importar paquetes como tflite_flutter para cargar y ejecutar el modelo.
// import 'package:tflite_flutter/tflite_flutter.dart';

class SignDetectionModule extends StatefulWidget {
  const SignDetectionModule({super.key});

  @override
  State<SignDetectionModule> createState() => _SignDetectionModuleState();
}

class _SignDetectionModuleState extends State<SignDetectionModule> {

  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "¡Aquí va la magia!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}