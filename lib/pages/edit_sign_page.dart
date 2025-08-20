import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditSignPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const EditSignPage({
    super.key,
    required this.docId,
    required this.initialData,
  });

  @override
  State<EditSignPage> createState() => _EditSignPageState();
}

class _EditSignPageState extends State<EditSignPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _keywordsController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData['titulo'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['descripcion'] ?? '');
    _keywordsController = TextEditingController(text: (widget.initialData['palabras_clave'] as List).join(', '));
  }

  void _updateSign() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final List<String> keywords = _keywordsController.text
          .toLowerCase()
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('content').doc(widget.docId).update({
        'titulo': _titleController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'palabras_clave': keywords,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Muestra un mensaje de éxito y regresa a la página anterior
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seña actualizada con éxito.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      print('Error al actualizar la seña: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al actualizar la seña.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        title: const Text('Editar Seña', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _keywordsController,
              decoration: const InputDecoration(
                labelText: 'Palabras clave (separadas por comas)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateSign,
              icon: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.save),
              label: const Text('Guardar Cambios', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
