import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'lista_ninos_page.dart';
import 'package:file_picker/file_picker.dart';

List<Map<String, dynamic>> listaNinos = [];

class NinosPage extends StatefulWidget {
  const NinosPage({super.key});

  @override
  State<NinosPage> createState() => _NinosPageState();
}

class _NinosPageState extends State<NinosPage> {
  final supabase = Supabase.instance.client;
  File? imagen;
  File? archivo;
  String? nombreArchivo;
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

  try {
    final path = 'ninos/$idNino/foto.jpg';

    await supabase.storage
        .from('documentos')
        .upload(path, imagen!);

    final url = supabase.storage
        .from('documentos')
        .getPublicUrl(path);

    return url;

  } catch (e) {
    print("ERROR SUBIENDO IMAGEN: $e");
    return null; 
  }
}
//seleccionar archivo
Future<void> seleccionarArchivo() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
  );

  if (result != null) {
    setState(() {
      archivo = File(result.files.single.path!);
      nombreArchivo = result.files.single.name;
    });
  }
}
//subir archivo
Future<String?> subirArchivo(String idNino) async {
  if (archivo == null) return null;

  try {
    final path = 'documentos/$idNino/$nombreArchivo';

    await supabase.storage
        .from('documentos')
        .upload(path, archivo!);

    final url = supabase.storage
        .from('documentos')
        .getPublicUrl(path);

    return url;

  } catch (e) {
    print("ERROR SUBIENDO ARCHIVO: $e");
    return null;
  }
}
  //  GUARDAR NIÑO
  Future<void> guardarNino() async {
    if (nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del niño')),
      );
      return;
    }

    final id = const Uuid().v4();
    String? docUrl;
    if (archivo != null) {
      docUrl = await subirArchivo(id);
    } else {
      docUrl = null;
    }
    
    String? imageUrl;
    if (imagen != null) {
      imageUrl = await subirImagen(id);
    } else {
      imageUrl = null;
    }

    try {
      final response = await supabase.from('ninos').insert({
        'id': id,
        'nombre': nombreController.text,
        'biografia': bioController.text,
        'foto': imageUrl,
        'documento': docUrl,
      }).select();

      print("INSERT OK: $response");

      // Limpiar formulario
      setState(() {
        nombreController.clear();
        bioController.clear();
        imagen = null;
        archivo = null;
        nombreArchivo = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niño guardado')),
      );

      // Recargar la lista
      await cargarNinos();
    } catch (e) {
      print("ERROR INSERT: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }
//funcion para cargar los niños desde la base de datos
Future<void> cargarNinos() async {
  final data = await supabase
      .from('ninos')
      .select()
      .order('id', ascending: false)
      .limit(2); 

  setState(() {
    listaNinos = List<Map<String, dynamic>>.from(data);
  });
}

  //  UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Niños'),
        leading: IconButton(
          icon: const Icon(Icons.list),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ListaNinosPage()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
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
              onPressed: seleccionarArchivo,
              child: const Text('Seleccionar documento'),
            ),

            const SizedBox(height: 10),

            archivo != null
                ? Text('Documento: $nombreArchivo')
                : const Text('No hay documento'),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: guardarNino,
              child: const Text('Guardar'),
            ),

            const SizedBox(height: 20),
            const Text('Niños registrados:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: listaNinos.length,
                itemBuilder: (context, index) {
                  final nino = listaNinos[index];
                  return ListTile(
                    title: Text(nino['nombre'] ?? ''),
                    subtitle: Text(nino['biografia'] ?? ''),
                    leading: nino['foto'] != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(nino['foto']),
                          )
                        : const CircleAvatar(child: Icon(Icons.person)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}