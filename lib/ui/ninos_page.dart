import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'detalle_nino_page.dart';
import 'home_page.dart';

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

  String? generoSeleccionado;
  DateTime? fechaNacimiento;
  String? categoriaSeleccionada;

  final List<String> generos = ['Masculino', 'Femenino'];

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

    if (generoSeleccionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona género')));
      return;
    }

    if (fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha de nacimiento')),
      );
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
        'genero': generoSeleccionado,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
      });

      // guardar foto del niño (si existe)
      String fotoUrl = 'SIN_URL';
      if (imagen != null) {
        try {
          final bytes = await imagen!.readAsBytes();
          final path = '$categoriaSeleccionada/$idNino/foto_perfil.jpg';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          fotoUrl = supabase.storage.from('documentos').getPublicUrl(path);

          // actualizar el niño con la URL de la foto
          await supabase
              .from('ninos')
              .update({'foto_url': fotoUrl})
              .eq('id', idNino);
          print("✓ Foto del niño guardada: $fotoUrl");
        } catch (e) {
          print("❌ ERROR STORAGE (FOTO): $e");
        }
      }

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
        generoSeleccionado = null;
        fechaNacimiento = null;
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Registro de Niños'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4A67)),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFEAF7FF), Color(0xFFF4EEFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F8C93B5),
                        blurRadius: 26,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información básica',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4E4A67),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nombreController,
                        decoration: _inputDecoration(
                          label: 'Nombre completo',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: generoSeleccionado,
                        hint: const Text('Selecciona género'),
                        decoration: _inputDecoration(
                          label: 'Género',
                          icon: Icons.wc_outlined,
                        ),
                        items: generos.map((String genero) {
                          return DropdownMenuItem<String>(
                            value: genero,
                            child: Text(genero),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            generoSeleccionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime.now(),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              fechaNacimiento = selectedDate;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            label: 'Fecha de nacimiento',
                            icon: Icons.calendar_today_outlined,
                          ),
                          child: Text(
                            fechaNacimiento == null
                                ? 'Seleccionar fecha'
                                : fechaNacimiento!.toLocal().toString().split(
                                    ' ',
                                  )[0],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF4E4A67),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F8C93B5),
                        blurRadius: 26,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documentos y archivos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4E4A67),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Seleccionar foto',
                        subtitle: 'Elige una imagen de la galería',
                        icon: Icons.photo_library_outlined,
                        onTap: seleccionarImagen,
                      ),
                      if (imagen != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: FileImage(imagen!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Subir archivo',
                        subtitle: 'Selecciona un documento',
                        icon: Icons.attach_file_outlined,
                        onTap: seleccionarArchivo,
                      ),
                      if (archivo != null && nombreArchivo != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5DDFB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                color: Color(0xFF8F88D9),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nombreArchivo!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4E4A67),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Escanear documento',
                        subtitle: 'Usa la cámara para escanear',
                        icon: Icons.camera_alt_outlined,
                        onTap: escanearDocumento,
                      ),
                      if (documentosEscaneados.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: documentosEscaneados.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(
                                      documentosEscaneados[index],
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: categoriaSeleccionada,
                        hint: const Text('Selecciona carpeta'),
                        decoration: _inputDecoration(
                          label: 'Categoría',
                          icon: Icons.folder_outlined,
                        ),
                        items: categorias.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            categoriaSeleccionada = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB39DDB), Color(0xFF81D4D4)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3381D4D4),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: guardarNino,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Guardar niño',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF8F88D9)),
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5DDFB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB39DDB), width: 1.4),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9E6F8)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB39DDB), Color(0xFF81D4D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F3D56),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A7890),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9A97AE)),
            ],
          ),
        ),
      ),
    );
  }
}
