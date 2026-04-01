import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'lista_ninos_page.dart';
import 'detalle_nino_page.dart';

class NinosPage extends StatefulWidget {
  const NinosPage({super.key});

  @override
  State<NinosPage> createState() => _NinosPageState();
}

class _NinosPageState extends State<NinosPage> {
  final supabase = Supabase.instance.client;

  File? imagen;
  File? archivo;
  List<File> documentosEscaneados = [];

  String? nombreArchivo;
  final picker = ImagePicker();

  final nombreController = TextEditingController();
  final bioController = TextEditingController();

  String? categoriaSeleccionada;

  final List<String> categorias = [
    'documentos_personales',
    'seguimiento',
    'salud_y_nutricion',
    'familia_comunidad_y_redes',
    'componente_pedagogico',
    'otros',
  ];

  // FOTO
  Future<void> seleccionarImagen() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imagen = File(pickedFile.path);
      });
    }
  }

  // ESCANER
  Future<void> escanearDocumento() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        documentosEscaneados.add(File(pickedFile.path));
      });
    }
  }

  // ARCHIVO
  Future<void> seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        archivo = File(result.files.single.path!);
        nombreArchivo = result.files.single.name;
      });
    }
  }

  // OCR
  Future<String> extraerTextoCompleto() async {
    final textRecognizer = TextRecognizer();
    String textoFinal = "";

    for (var file in documentosEscaneados) {
      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);
      textoFinal += recognizedText.text + "\n\n";
    }

    if (archivo != null) {
      try {
        final inputImage = InputImage.fromFile(archivo!);
        final recognizedText = await textRecognizer.processImage(inputImage);
        textoFinal += recognizedText.text + "\n\n";
      } catch (_) {
        print("Archivo no compatible con OCR");
      }
    }

    textRecognizer.close();
    return textoFinal;
  }

  // 💾 GUARDAR
  Future<void> guardarNino() async {
    if (nombreController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa el nombre')));
      return;
    }

    if (categoriaSeleccionada == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona carpeta')));
      return;
    }

    if (documentosEscaneados.isEmpty && archivo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escanea o sube algo')));
      return;
    }

    try {
      final idNino = const Uuid().v4();

      // guardar niño
      await supabase.from('ninos').insert({
        'id': idNino,
        'nombre': nombreController.text,
        'biografia': bioController.text,
      });

      // OCR
      final texto = await extraerTextoCompleto();
      print("TEXTO OCR:\n$texto");

      // guardar archivo OCR (texto) si tiene contenido
      String urlTexto = 'SIN_URL';
      if (texto.trim().isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(texto.codeUnits);
          final path = '$categoriaSeleccionada/$idNino/documento_oculto.txt';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          urlTexto = supabase.storage.from('documentos').getPublicUrl(path);

          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': 'documento_oculto.txt',
            'url': urlTexto,
            'tipo': 'texto',
            'categoria': categoriaSeleccionada,
          });
          print("✓ Documento OCR guardado en tabla");
        } catch (e) {
          print("❌ ERROR STORAGE (OCR TEXTO): $e");
        }
      }

      // almacenar archivo subido por el usuario (si existe)
      String urlArchivo = 'SIN_URL';
      if (archivo != null && nombreArchivo != null) {
        try {
          final bytes = await archivo!.readAsBytes();
          final path = '$categoriaSeleccionada/$idNino/$nombreArchivo';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          urlArchivo = supabase.storage.from('documentos').getPublicUrl(path);

          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreArchivo,
            'url': urlArchivo,
            'tipo': 'archivo',
            'categoria': categoriaSeleccionada,
          });
          print("✓ Archivo guardado en tabla: $nombreArchivo");
        } catch (e) {
          print("❌ ERROR STORAGE (ARCHIVO): $e");
        }
      }

      // almacenar documentos escaneados
      for (var i = 0; i < documentosEscaneados.length; i++) {
        final doc = documentosEscaneados[i];
        try {
          final bytes = await doc.readAsBytes();
          final nombreDoc =
              'documento_escaner_${i + 1}.${doc.path.split('.').last}';
          final path = '$categoriaSeleccionada/$idNino/$nombreDoc';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final urlDoc = supabase.storage.from('documentos').getPublicUrl(path);

          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreDoc,
            'url': urlDoc,
            'tipo': 'imagen',
            'categoria': categoriaSeleccionada,
          });
          print("✓ Escaneo $i guardado en tabla: $nombreDoc");
        } catch (e) {
          print("❌ ERROR STORAGE (ESCANEO $i): $e");
        }
      }

      // limpiar
      setState(() {
        nombreController.clear();
        bioController.clear();
        documentosEscaneados.clear();
        archivo = null;
        nombreArchivo = null;
        categoriaSeleccionada = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado correctamente')));

      // ir a detalle con lo guardado
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DetalleNinoPage(id: idNino)),
        );
      }
    } catch (e) {
      print("ERROR GENERAL: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // UI
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

            imagen != null
                ? Image.file(imagen!, height: 100)
                : const Text('No hay imagen'),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: seleccionarArchivo,
              child: const Text('Subir archivo'),
            ),

            archivo != null
                ? Text('Archivo: $nombreArchivo')
                : const Text('No hay archivo'),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: escanearDocumento,
              child: const Text('Escanear documento'),
            ),

            documentosEscaneados.isNotEmpty
                ? SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: documentosEscaneados.length,
                      itemBuilder: (context, index) {
                        return Image.file(documentosEscaneados[index]);
                      },
                    ),
                  )
                : const Text('No hay escaneos'),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: categoriaSeleccionada,
              hint: const Text('Selecciona carpeta'),
              items: categorias.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  categoriaSeleccionada = value;
                });
              },
            ),

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
