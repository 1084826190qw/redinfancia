import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../file_io_stub.dart' if (dart.library.io) '../file_io_io.dart';
import 'detalle_nino_page.dart';
import 'home_page.dart';

class NinosPage extends StatefulWidget {
  const NinosPage({super.key});

  @override
  State<NinosPage> createState() => _NinosPageState();
}

class _NinosPageState extends State<NinosPage> {
  final supabase = Supabase.instance.client;

  dynamic imagen;
  dynamic archivo;
  List<dynamic> documentosEscaneados = [];
  Uint8List? _archivoBytes;

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

  // Función para sanitizar nombres de archivos para Supabase Storage
  // Función para sanitizar nombres de archivos para Supabase Storage
  String _sanitizarNombreArchivo(String nombre) {
    final extensionIndex = nombre.lastIndexOf('.');
    final extension = extensionIndex >= 0 ? nombre.substring(extensionIndex) : '';
    final nombreBase = extensionIndex >= 0 ? nombre.substring(0, extensionIndex) : nombre;

    String sanitizado = nombreBase.toLowerCase();

    const reemplazos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'ª': 'a',
      'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
      'ñ': 'n', 'Ñ': 'n',
    };

    reemplazos.forEach((key, value) {
      sanitizado = sanitizado.replaceAll(key, value);
    });

    sanitizado = sanitizado
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (sanitizado.isEmpty) {
      sanitizado = 'archivo';
    }

    final nombreFinal = (sanitizado + extension.toLowerCase());

    if (nombreFinal.length > 100) {
      final ext = extension.toLowerCase();
      final base = nombreFinal.substring(0, 100 - ext.length);
      return '$base$ext';
    }

    return nombreFinal;
  }

  // FOTO
  Future<void> seleccionarImagen() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imagen = createFile(pickedFile.path);
      });
    }
  }

  // ESCANER
  Future<void> escanearDocumento() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escaneo no disponible en Web. Usa la app móvil.')),
      );
      return;
    }

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        documentosEscaneados.add(createFile(pickedFile.path));
      });
    }
  }

  // ARCHIVO
  Future<void> seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null) {
      setState(() {
        nombreArchivo = result.files.single.name;
        _archivoBytes = result.files.single.bytes;

        if (!kIsWeb && result.files.single.path != null) {
          archivo = createFile(result.files.single.path!);
        }
      });
    }
  }

  // OCR
  Future<String> extraerTextoCompleto() async {
    if (kIsWeb) {
      print("OCR no disponible en Web");
      return '';
    }

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

    if (documentosEscaneados.isEmpty && _archivoBytes == null) {
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
        'id_usuario': supabase.auth.currentUser!.id,
      });

      // guardar foto del niño (si existe)
      String fotoUrl = 'SIN_URL';
      if (imagen != null) {
        try {
          final bytes = await imagen!.readAsBytes();
          final nombreSanitizado = _sanitizarNombreArchivo('foto_perfil.jpg');
          final path = '$categoriaSeleccionada/$idNino/$nombreSanitizado';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          fotoUrl = supabase.storage.from('documentos').getPublicUrl(path);

          // actualizar el niño con la URL de la foto
         await supabase
    .from('ninos')
    .update({'foto': fotoUrl})
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
          final nombreSanitizado = _sanitizarNombreArchivo('documento_oculto.txt');
          final path = '$categoriaSeleccionada/$idNino/$nombreSanitizado';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          urlTexto = supabase.storage.from('documentos').getPublicUrl(path);

          print('DEBUG Intentando insertar OCR en BD...');
          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': 'documento_oculto.txt', // Mantener el nombre original en BD
            'url': urlTexto,
            'tipo': 'texto',
            'categoria': categoriaSeleccionada,
            'contenido_texto': texto.trim(),
          });
          print("✓ Documento OCR guardado en tabla");
        } catch (e) {
          print("❌ ERROR OCR en BD: $e");
        }
      }

      // almacenar archivo subido por el usuario (si existe)
      String urlArchivo = 'SIN_URL';
      if (_archivoBytes != null && nombreArchivo != null) {
        try {
          final bytes = _archivoBytes!;
          final nombreSanitizado = _sanitizarNombreArchivo(nombreArchivo!);
          final path = '$categoriaSeleccionada/$idNino/$nombreSanitizado';
          print('DEBUG Storage upload path: $path');
          print('DEBUG nombreArchivo original: $nombreArchivo');
          print('DEBUG nombreSanitizado: $nombreSanitizado');

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          urlArchivo = supabase.storage.from('documentos').getPublicUrl(path);

          print('DEBUG Intentando insertar archivo en BD...');
          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreArchivo, // Mantener el nombre original en BD
            'url': urlArchivo,
            'tipo': 'archivo',
            'categoria': categoriaSeleccionada,
          });
          print("✓ Archivo guardado en tabla: $nombreArchivo");
        } catch (e) {
          print("❌ ERROR ARCHIVO en BD: $e");
          print("DEBUG id_nino: $idNino, nombreArchivo: $nombreArchivo, categoria: $categoriaSeleccionada");
        }
      }

      // almacenar documentos escaneados
      for (var i = 0; i < documentosEscaneados.length; i++) {
        final doc = documentosEscaneados[i];
        String nombreOriginal = 'documento_escaner_${i + 1}.${doc.path.split('.').last}';
        try {
          final bytes = await doc.readAsBytes();
          final nombreSanitizado = _sanitizarNombreArchivo(nombreOriginal);
          final path = '$categoriaSeleccionada/$idNino/$nombreSanitizado';

          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final urlDoc = supabase.storage.from('documentos').getPublicUrl(path);

          print('DEBUG Intentando insertar escaneo $i en BD...');
          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreOriginal, // Mantener el nombre original en BD
            'url': urlDoc,
            'tipo': 'imagen',
            'categoria': categoriaSeleccionada,
          });
          print("✓ Escaneo $i guardado en tabla: $nombreOriginal");
        } catch (e) {
          print("❌ ERROR ESCANEO $i en BD: $e");
          print("DEBUG id_nino: $idNino, nombreOriginal: $nombreOriginal, categoria: $categoriaSeleccionada");
        }
      }

      // limpiar
      setState(() {
        nombreController.clear();
        generoSeleccionado = null;
        fechaNacimiento = null;
        documentosEscaneados.clear();
        archivo = null;
        _archivoBytes = null;
        nombreArchivo = null;
        categoriaSeleccionada = null;
      });

      // Verificar que se guardaron documentos
      final docsVerify = await supabase
          .from('documentos')
          .select('id')
          .eq('id_nino', idNino);
      
      print('DEBUG: Documentos verificados en BD: ${(docsVerify as List).length}');

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
