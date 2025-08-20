import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();

  File? _mediaFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String _mediaType = ''; // 'mp4', 'gif', 'jpg', etc.

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // Se actualizó este método para aceptar cualquier archivo
  Future<void> _pickFile(bool isMedia) async {
    final XFile? pickedFile = await _picker.pickMedia();
    if (pickedFile != null) {
      final String fileExtension = pickedFile.path.split('.').last.toLowerCase();
      
      if (isMedia) {
        // Validar tipos de archivos multimedia
        if (['mp4', 'gif', 'mov', 'webp', 'png', 'jpg', 'jpeg'].contains(fileExtension)) {
          setState(() {
            _mediaFile = File(pickedFile.path);
            _mediaType = fileExtension;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona un archivo de video o imagen (mp4, gif, mov, webp, png, jpg, jpeg).')),
          );
          _mediaFile = null;
          _mediaType = '';
        }
      } else {
        // Validar tipos de archivos para la miniatura
        if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          setState(() {
            _thumbnailFile = File(pickedFile.path);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona una imagen para la miniatura (JPG, PNG o GIF).')),
          );
          _thumbnailFile = null;
        }
      }
    }
  }

  Future<String> _uploadFile(File file, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  void _uploadContent() async {
    if (_titleController.text.isEmpty ||
        _mediaFile == null ||
        _thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos y selecciona los archivos.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String mediaPath = 'content/${DateTime.now().millisecondsSinceEpoch}_${_mediaFile!.path.split('/').last}';
      final String thumbnailPath = 'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${_thumbnailFile!.path.split('/').last}';

      final String mediaUrl = await _uploadFile(_mediaFile!, mediaPath);
      final String thumbnailUrl = await _uploadFile(_thumbnailFile!, thumbnailPath);

      final List<String> keywords = _keywordsController.text
          .toLowerCase()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('content').add({
        'titulo': _titleController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'palabras_clave': keywords,
        'url_media': mediaUrl,
        'url_miniatura': thumbnailUrl,
        'tipo': _mediaType,
        'vistas': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _descriptionController.clear();
      _keywordsController.clear();
      setState(() {
        _mediaFile = null;
        _thumbnailFile = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido subido exitosamente.')),
      );
    } catch (e) {
      print('Error al subir el contenido: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al subir el contenido. Intenta de nuevo.')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywordsController,
              decoration: const InputDecoration(labelText: 'Palabras clave (separadas por comas)'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickFile(true),
                    child: const Text('Seleccionar Archivo Multimedia'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickFile(false),
                    child: const Text('Seleccionar Miniatura'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_mediaFile != null)
              Image.file(
                _mediaFile!,
                height: 150,
                // Si el archivo es un video, no se muestra una vista previa aquí.
                // Si es una imagen o GIF, se muestra la vista previa.
                errorBuilder: (context, error, stackTrace) => const Text('Vista previa no disponible para este tipo de archivo.'),
              ),
            if (_thumbnailFile != null)
              Image.file(_thumbnailFile!, height: 100),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadContent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Subir Contenido', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
