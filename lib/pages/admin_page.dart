import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();

  File? _gifFile;
  File? _thumbnailFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  Future<void> _pickImage(bool isGif) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isGif) {
          _gifFile = File(pickedFile.path);
        } else {
          _thumbnailFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<String> _uploadFile(File file, String path) async {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final uploadTask = storageRef.putFile(file);
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  void _uploadGif() async {
    if (_titleController.text.isEmpty ||
        _gifFile == null ||
        _thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos y selecciona las imágenes.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String gifPath = 'gifs/${DateTime.now().millisecondsSinceEpoch}_${_gifFile!.path.split('/').last}';
      final String thumbnailPath = 'thumbnails/${DateTime.now().millisecondsSinceEpoch}_${_thumbnailFile!.path.split('/').last}';

      // Subir las imágenes a Firebase Storage
      final String gifUrl = await _uploadFile(_gifFile!, gifPath);
      final String thumbnailUrl = await _uploadFile(_thumbnailFile!, thumbnailPath);

      // Limpiar y preparar las palabras clave para Firestore
      final List<String> keywords = _keywordsController.text
          .toLowerCase()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Guardar el documento en Firestore
      await FirebaseFirestore.instance.collection('gifs').add({
        'titulo': _titleController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'palabras_clave': keywords,
        'url_gif': gifUrl, // URL para el GIF original
        'url_miniatura': thumbnailUrl, // URL para la miniatura
        'vistas': 0, // Un contador de vistas
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Limpiar los campos después de la subida
      _titleController.clear();
      _descriptionController.clear();
      _keywordsController.clear();
      setState(() {
        _gifFile = null;
        _thumbnailFile = null;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GIF subido exitosamente.')),
      );
    } catch (e) {
      print('Error al subir el GIF: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al subir el GIF. Intenta de nuevo.')),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título del GIF'),
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
                    onPressed: () => _pickImage(true),
                    child: const Text('Seleccionar GIF'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickImage(false),
                    child: const Text('Seleccionar Miniatura'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_gifFile != null)
              Image.file(_gifFile!, height: 150),
            if (_thumbnailFile != null)
              Image.file(_thumbnailFile!, height: 100),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadGif,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Subir GIF', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}