import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NinosPage extends StatefulWidget {
  const NinosPage({super.key});

  @override
  State<NinosPage> createState() => _NinosPageState();
}

class _NinosPageState extends State<NinosPage> {

  final supabase = Supabase.instance.client;
  File? imagen;
  final picker = ImagePicker();

  final nombreController = TextEditingController();
  final bioController = TextEditingController();

  //  SELECCIONAR IMAGEN
  Future<void> seleccionarImagen() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imagen = File(pickedFile.path);
      });
    }
  }

  //  SUBIR IMAGEN
  Future<String?> subirImagen(String idNino) async {
    if (imagen == null) return null;

    final path = 'ninos/$idNino/foto.jpg';

    await supabase.storage
        .from('documentos')
        .upload(path, imagen!);

    final url = supabase.storage
        .from('documentos')
        .getPublicUrl(path);

    return url;
  }

  //  GUARDAR NIÑO
  Future<void> guardarNino() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final imageUrl = await subirImagen(id);

    await supabase.from('ninos').insert({
      'id': id,
      'nombre': nombreController.text,
      'biografia': bioController.text,
      'foto': imageUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Niño guardado')),
    );

    setState(() {
      imagen = null;
    });
  }

  //  UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Niños')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),

            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Biografía'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: seleccionarImagen,
              child: const Text('Seleccionar foto'),
            ),

            const SizedBox(height: 10),

            imagen != null
                ? Image.file(imagen!, height: 100)
                : const Text('No hay imagen'),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: guardarNino,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}