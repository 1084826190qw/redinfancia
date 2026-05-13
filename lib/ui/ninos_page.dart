import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
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
  final picker = ImagePicker();

  // ✅ Cada archivo tiene su propia categoría
  final List<dynamic> _archivos = [];
  final List<dynamic> documentosEscaneados = [];
  final List<String> categoriasEscaneados = [];
  final List<Uint8List?> _archivosBytes = [];
  final List<String?> _nombresArchivos = [];
  final List<String> _categoriasArchivos = []; // ← categoría por archivo

  final nombreController = TextEditingController();

  bool get _ocrDisponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<String> _extraerTextoOCR(dynamic archivo) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.linux) {
        Uint8List bytes;
        if (archivo is Uint8List) {
          bytes = archivo;
        } else {
          bytes = await archivo.readAsBytes();
        }
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(bytes);
        try {
          final texto = await TesseractOcr.extractText(tempFile.path);
          return texto ?? '';
        } finally {
          if (await tempFile.exists()) await tempFile.delete();
        }
      } else {
        final textRecognizer = TextRecognizer();
        final inputImage = InputImage.fromFile(archivo);
        final recognizedText = await textRecognizer.processImage(inputImage);
        textRecognizer.close();
        return recognizedText.text;
      }
    } catch (e) {
      print('Error OCR: $e');
      return '';
    }
  }

  String? generoSeleccionado;
  DateTime? fechaNacimiento;
  // ✅ Categoría de foto/escaneos (se mantiene global para esos)
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

  // Nombres legibles para mostrar en UI
  String _formatearCategoria(String cat) {
    switch (cat) {
      case 'documentos_personales': return 'Documentos Personales';
      case 'seguimiento': return 'Seguimiento';
      case 'salud_y_nutricion': return 'Salud y Nutrición';
      case 'familia_comunidad_y_redes': return 'Familia, Comunidad y Redes';
      case 'componente_pedagogico': return 'Componente Pedagógico';
      case 'otros': return 'Otros';
      default: return cat;
    }
  }

  String _sanitizarNombreArchivo(String nombre) {
    final extensionIndex = nombre.lastIndexOf('.');
    final extension =
        extensionIndex >= 0 ? nombre.substring(extensionIndex) : '';
    final nombreBase =
        extensionIndex >= 0 ? nombre.substring(0, extensionIndex) : nombre;

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

    if (sanitizado.isEmpty) sanitizado = 'archivo';

    final nombreFinal = sanitizado + extension.toLowerCase();
    if (nombreFinal.length > 100) {
      final ext = extension.toLowerCase();
      return '${nombreFinal.substring(0, 100 - ext.length)}$ext';
    }
    return nombreFinal;
  }

  Future<void> seleccionarImagen() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          if (!kIsWeb && file.path != null) {
            imagen = createFile(file.path!);
          } else if (file.bytes != null) {
            imagen = file.bytes;
          }
        });
      }
      return;
    }
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => imagen = createFile(pickedFile.path));
    }
  }

  Future<void> escanearDocumento() async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escaneo no disponible en Web.')),
    );
    return;
  }

  if (!kIsWeb && Theme.of(context).platform == TargetPlatform.linux) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escaneo no disponible en Linux.')),
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

      // Categoría por defecto
      categoriasEscaneados.add(categorias[0]);
    });
  }
}

  // ✅ Al seleccionar archivos, cada uno empieza con categoría por defecto
  Future<void> seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          _nombresArchivos.add(file.name);
          _archivosBytes.add(file.bytes);
          _categoriasArchivos.add(categorias[0]); // ← categoría por defecto
          if (!kIsWeb && file.path != null) {
            _archivos.add(createFile(file.path!));
          } else {
            _archivos.add(null);
          }
        }
      });
    }
  }

  Future<String> _extraerTextoEscaneados() async {
    if (!_ocrDisponible) return '';
    String textoFinal = '';
    for (var file in documentosEscaneados) {
      try {
        final texto = await _extraerTextoOCR(file);
        if (texto.trim().isNotEmpty) textoFinal += texto + '\n\n';
      } catch (e) {
        print('Error OCR escaneado: $e');
      }
    }
    return textoFinal.trim();
  }

  // ✅ OCR retorna mapa de índice → texto para asociar a cada archivo
  Future<Map<int, String>> _extraerTextoDeArchivos() async {
    if (!_ocrDisponible) return {};
    final Map<int, String> textoPorArchivo = {};

    for (int i = 0; i < _archivos.length; i++) {
      final archivo = _archivos[i];
      if (archivo == null) continue;

      final nombre = _nombresArchivos[i] ?? '';
      final extension = nombre.split('.').last.toLowerCase();
      final esImagen =
          ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
      if (!esImagen) continue;

      try {
        final texto = await _extraerTextoOCR(archivo);
        if (texto.trim().isNotEmpty) {
          textoPorArchivo[i] = texto.trim();
          print('✓ OCR $nombre: ${texto.length} chars');
        }
      } catch (e) {
        print('Error OCR $nombre: $e');
      }
    }
    return textoPorArchivo;
  }

  Future<void> guardarNino() async {
    if (nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresa el nombre')));
      return;
    }
    if (generoSeleccionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona género')));
      return;
    }
    if (fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona fecha de nacimiento')));
      return;
    }
    if (categoriaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona carpeta principal')));
      return;
    }
    if (documentosEscaneados.isEmpty && _archivosBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escanea o sube al menos un documento')));
      return;
    }

    try {
      final idNino = const Uuid().v4();

      await supabase.from('ninos').insert({
        'id': idNino,
        'nombre': nombreController.text,
        'genero': generoSeleccionado,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
        'id_usuario': supabase.auth.currentUser!.id,
      });

      // Foto
      if (imagen != null) {
        try {
          final bytes = imagen is Uint8List
              ? imagen as Uint8List
              : await imagen.readAsBytes();
          final path =
              '$categoriaSeleccionada/$idNino/${_sanitizarNombreArchivo('foto_perfil.jpg')}';
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final fotoUrl =
              supabase.storage.from('documentos').getPublicUrl(path);
          await supabase
              .from('ninos')
              .update({'foto': fotoUrl}).eq('id', idNino);
          print('✓ Foto guardada');
        } catch (e) {
          print('❌ ERROR FOTO: $e');
        }
      }

      // OCR
      final textoEscaneados = await _extraerTextoEscaneados();
      final textoPorArchivo = await _extraerTextoDeArchivos();

      // Guardar texto OCR global (escaneados) si existe
      if (textoEscaneados.isNotEmpty) {
        try {
          final bytes = Uint8List.fromList(textoEscaneados.codeUnits);
          final path =
              '$categoriaSeleccionada/$idNino/${_sanitizarNombreArchivo('documento_oculto.txt')}';
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final urlTexto =
              supabase.storage.from('documentos').getPublicUrl(path);
          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': 'documento_oculto.txt',
            'url': urlTexto,
            'tipo': 'texto',
            'categoria': categoriaSeleccionada,
            'contenido_texto': textoEscaneados,
          });
          print('✓ OCR escaneados guardado');
        } catch (e) {
          print('❌ ERROR OCR BD: $e');
        }
      }

      // ✅ Guardar archivos cada uno con su propia categoría
      for (int i = 0; i < _archivosBytes.length; i++) {
        final bytes = _archivosBytes[i];
        final nombreArchivo = _nombresArchivos[i];
        final categoriaArchivo = _categoriasArchivos[i]; // ← categoría individual
        if (bytes == null || nombreArchivo == null) continue;

        try {
          final extension =
              nombreArchivo.contains('.') ? nombreArchivo.split('.').last : '';
          final esImagen = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']
              .contains(extension.toLowerCase());
          final timestamp = DateTime.now().millisecondsSinceEpoch + i;
          final nombreSanitizado = _sanitizarNombreArchivo(nombreArchivo);
          final nombreConTimestamp = extension.isNotEmpty
              ? '${nombreSanitizado.replaceAll('.$extension', '')}_$timestamp.$extension'
              : '${nombreSanitizado}_$timestamp';

          // ✅ Usar la categoría del archivo para la ruta en Storage
          final path = '$categoriaArchivo/$idNino/$nombreConTimestamp';
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final urlArchivo =
              supabase.storage.from('documentos').getPublicUrl(path);

          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreArchivo,
            'url': urlArchivo,
            'tipo': esImagen ? 'imagen' : 'archivo',
            'categoria': categoriaArchivo, // ← categoría individual
            if (esImagen && textoPorArchivo.containsKey(i))
              'contenido_texto': textoPorArchivo[i],
          });
          print('✓ Archivo guardado: $nombreArchivo → $categoriaArchivo');
        } catch (e) {
          print('❌ ERROR ARCHIVO $i: $e');
        }
      }

      // Escaneados con cámara (usan categoría global)
      for (int i = 0; i < documentosEscaneados.length; i++) {
        final doc = documentosEscaneados[i];
        final nombreOriginal =
            'documento_escaner_${i + 1}.${doc.path.split('.').last}';
        try {
          final bytes = await doc.readAsBytes();
          final categoriaEscaneo = categoriasEscaneados[i];

          final path =
          '$categoriaEscaneo/$idNino/${_sanitizarNombreArchivo(nombreOriginal)}';
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final urlDoc =
              supabase.storage.from('documentos').getPublicUrl(path);
          await supabase.from('documentos').insert({
            'id_nino': idNino,
            'nombre_archivo': nombreOriginal,
            'url': urlDoc,
            'tipo': 'imagen',
            'categoria': categoriaEscaneo,
            if (textoEscaneados.isNotEmpty) 'contenido_texto': textoEscaneados,
          });
          print('✓ Escaneo guardado: $nombreOriginal');
        } catch (e) {
          print('❌ ERROR ESCANEO $i: $e');
        }
      }

      // Limpiar
      setState(() {
        nombreController.clear();
        generoSeleccionado = null;
        fechaNacimiento = null;
        documentosEscaneados.clear();
        _archivos.clear();
        _archivosBytes.clear();
        _nombresArchivos.clear();
        _categoriasArchivos.clear();
        categoriaSeleccionada = null;
        imagen = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado correctamente')));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => DetalleNinoPage(id: idNino)),
        );
      }
    } catch (e) {
      print('ERROR GENERAL: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

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
                // ── Información básica ──
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
                          offset: Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Información básica',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E4A67))),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nombreController,
                        decoration: _inputDecoration(
                            label: 'Nombre completo',
                            icon: Icons.person_outline),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: generoSeleccionado,
                        hint: const Text('Selecciona género'),
                        decoration: _inputDecoration(
                            label: 'Género', icon: Icons.wc_outlined),
                        items: generos
                            .map((g) => DropdownMenuItem(
                                value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => generoSeleccionado = v),
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
                            setState(() => fechaNacimiento = selectedDate);
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputDecoration(
                              label: 'Fecha de nacimiento',
                              icon: Icons.calendar_today_outlined),
                          child: Text(
                            fechaNacimiento == null
                                ? 'Seleccionar fecha'
                                : fechaNacimiento!
                                    .toLocal()
                                    .toString()
                                    .split(' ')[0],
                            style: const TextStyle(
                                fontSize: 16, color: Color(0xFF4E4A67)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Documentos ──
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
                          offset: Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Documentos y archivos',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E4A67))),
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Seleccionar foto de perfil',
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
                              image: imagen is Uint8List
                                  ? MemoryImage(imagen as Uint8List)
                                  : FileImage(imagen as dynamic),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Subir archivos',
                        subtitle: 'Selecciona múltiples documentos',
                        icon: Icons.attach_file_outlined,
                        onTap: seleccionarArchivo,
                      ),
                      // ✅ Lista de archivos con selector de categoría individual
                      if (_nombresArchivos.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Archivos seleccionados:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF4E4A67))),
                        const SizedBox(height: 8),
                        ...List.generate(_nombresArchivos.length, (index) {
                          final nombre = _nombresArchivos[index];
                          if (nombre == null) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5FF),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5DDFB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre del archivo + botón eliminar
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.insert_drive_file_outlined,
                                        color: Color(0xFF8F88D9),
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        nombre,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF4E4A67),
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18,
                                          color: Color(0xFFEF5350)),
                                      onPressed: () => setState(() {
                                        _archivos.removeAt(index);
                                        _archivosBytes.removeAt(index);
                                        _nombresArchivos.removeAt(index);
                                        _categoriasArchivos.removeAt(index);
                                      }),
                                      tooltip: 'Remover archivo',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // ✅ Selector de categoría individual
                                DropdownButtonFormField<String>(
                                  value: _categoriasArchivos[index],
                                  isDense: true,
                                  decoration: InputDecoration(
                                    labelText: 'Carpeta',
                                    labelStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF8F88D9)),
                                    prefixIcon: const Icon(
                                        Icons.folder_outlined,
                                        color: Color(0xFF8F88D9),
                                        size: 18),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFE5DDFB)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFB39DDB)),
                                    ),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4E4A67)),
                                  items: categorias
                                      .map((cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(
                                                _formatearCategoria(cat),
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() =>
                                          _categoriasArchivos[index] = value);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      _ActionButton(
                        title: 'Escanear documento',
                        subtitle: 'Usa la cámara para escanear',
                        icon: Icons.camera_alt_outlined,
                        onTap: escanearDocumento,
                      ),
                      if (documentosEscaneados.isNotEmpty) ...[
  const SizedBox(height: 16),

  const Text(
    'Documentos escaneados:',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
      color: Color(0xFF4E4A67),
    ),
  ),

  const SizedBox(height: 10),

  ...List.generate(documentosEscaneados.length, (index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5DDFB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              documentosEscaneados[index],
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: categoriasEscaneados[index],
            decoration: InputDecoration(
              labelText: 'Carpeta',
              prefixIcon: const Icon(
                Icons.folder_outlined,
                color: Color(0xFF8F88D9),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE5DDFB),
                ),
              ),
            ),
            items: categorias.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(_formatearCategoria(cat)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  categoriasEscaneados[index] = value;
                });
              }
            },
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFEF5350),
              ),
              onPressed: () {
                setState(() {
                  documentosEscaneados.removeAt(index);
                  categoriasEscaneados.removeAt(index);
                });
              },
            ),
          ),
        ],
      ),
    );
  }),
],
                      const SizedBox(height: 16),

                      // Categoría global para foto de perfil
                      DropdownButtonFormField<String>(
                        value: categoriaSeleccionada,
                        hint: const Text(
                          'Carpeta para foto de perfil',
                        ),
                        decoration: _inputDecoration(
                          label: 'Carpeta principal',
                          icon: Icons.folder_outlined,
                        ),
                        items: categorias
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(_formatearCategoria(cat)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => categoriaSeleccionada = value),
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
                      colors: [
                        Color(0xFFB39DDB),
                        Color(0xFF81D4D4),
                      ],
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
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF8F88D9),
      ),
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFE5DDFB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFB39DDB),
          width: 1.4,
        ),
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
            border: Border.all(
              color: const Color(0xFFE9E6F8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB39DDB),
                      Color(0xFF81D4D4),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
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

              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9A97AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
