import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import '../file_io_stub.dart' if (dart.library.io) '../file_io_io.dart';
import 'lista_ninos_page.dart';
import 'document_viewer.dart';

class DetalleNinoPage extends StatefulWidget {
  final String id;

  const DetalleNinoPage({super.key, required this.id});

  @override
  State<DetalleNinoPage> createState() => _DetalleNinoPageState();
}

class _DetalleNinoPageState extends State<DetalleNinoPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> documentos = [];
  List<Map<String, dynamic>> documentosFiltrados = [];
  String nombre = '';
  String genero = '';
  String fechaNacimiento = '';
  String categoria = 'Sin categoría';
  String fotoUrl = '';
  String? categoriaDocumentoSeleccionada;
  final TextEditingController _searchController = TextEditingController();

  // ✅ Nuevo filtro: modo de búsqueda
  bool _buscarSoloEnOcr = false;
  bool _showOcrOption = false;
  bool _tappedFilter = false;
  final FocusNode _searchFocusNode = FocusNode();

  final List<dynamic> _archivosNuevos = [];
  final List<Uint8List?> _archivosNuevosBytes = [];
  final List<String?> _nombresArchivosNuevos = [];
  String? _categoriaArchivosNuevos;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

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

  final List<String> categoriasDocumentos = [
    'Todas las categorías',
    'documentos_personales',
    'seguimiento',
    'salud_y_nutricion',
    'familia_comunidad_y_redes',
    'componente_pedagogico',
    'otros',
  ];

  @override
  void initState() {
    super.initState();
    categoriaDocumentoSeleccionada = categoriasDocumentos[0];
    _cargarDatos();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && !_tappedFilter) {
        setState(() => _showOcrOption = false);
      }
      _tappedFilter = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
  setState(() => isLoading = true);
  try {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión para ver este niño')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ListaNinosPage()));
      }
      return;
    }

    final ninoData = await supabase
        .from('ninos')
        .select()
        .eq('id', widget.id)
        .eq('id_usuario', currentUser.id)
        .single();

    final docData = await supabase
        .from('documentos')
        .select()
        .eq('id_nino', widget.id);

    print("✓ Niño cargado: ${ninoData['nombre']}");
    print("✓ Documentos encontrados: ${(docData as List).length}");

    List<Map<String, dynamic>> todosLosDocs =
        List<Map<String, dynamic>>.from(docData as List<dynamic>? ?? []);

    // ✅ Buscar documento_oculto.txt por categoría y cruzar su texto
    // con las imágenes escaneadas que no tengan contenido_texto
    final docsOcultos = todosLosDocs
        .where((d) => d['nombre_archivo'] == 'documento_oculto.txt')
        .toList();

    // Para cada imagen escaneada sin texto, buscar el doc oculto
    // de su misma categoría y asignarle el texto
    todosLosDocs = todosLosDocs.map((doc) {
      final tipo = doc['tipo'] as String? ?? '';
      final nombre = doc['nombre_archivo'] as String? ?? '';
      final contenido = doc['contenido_texto'] as String? ?? '';
      final cat = doc['categoria'] as String? ?? '';

      // Si es imagen escaneada sin texto OCR
      if (tipo == 'imagen' &&
          nombre.startsWith('documento_escaner_') &&
          contenido.isEmpty) {
        // Buscar el doc oculto de la misma categoría
        final docOculto = docsOcultos.firstWhere(
          (d) => d['categoria'] == cat,
          orElse: () => {},
        );

        if (docOculto.isNotEmpty) {
          final textoOculto = docOculto['contenido_texto'] as String? ?? '';
          if (textoOculto.isNotEmpty) {
            // Retornar el documento con el texto cruzado
            return {
              ...doc,
              'contenido_texto': textoOculto,
            };
          }
        }
      }

      return doc;
    }).toList();

    setState(() {
      nombre = (ninoData['nombre'] ?? '') as String;
      genero = (ninoData['genero'] ?? '') as String;
      fechaNacimiento = (ninoData['fecha_nacimiento'] ?? '') as String;
      categoria = (ninoData['categoria'] ?? 'Sin categoría') as String;
      fotoUrl = (ninoData['foto'] ?? '') as String;
      documentos = todosLosDocs;
      documentosFiltrados = todosLosDocs;
      _filtrarDocumentos(_searchController.text);
      isLoading = false;
    });
  } catch (e) {
    print("❌ ERROR al cargar datos: $e");
    setState(() => isLoading = false);
  }
}

  Future<void> _seleccionarArchivoNuevo(StateSetter setDialogState) async {
    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setDialogState(() {
        for (final file in result.files) {
          _nombresArchivosNuevos.add(file.name);
          _archivosNuevosBytes.add(file.bytes);
          if (!kIsWeb && file.path != null) {
            _archivosNuevos.add(createFile(file.path!));
          } else {
            _archivosNuevos.add(null);
          }
        }
      });
    }
  }

  Future<void> _escanearDocumentoNuevo(StateSetter setDialogState) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escaneo no disponible en Web.')),
      );
      return;
    }

    Future<void> procesarImagen(ImageSource source) async {
      try {
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (pickedFile != null) {
          setDialogState(() {
            final nombreArchivo =
                'documento_escaner_${DateTime.now().millisecondsSinceEpoch}.jpg';
            _nombresArchivosNuevos.add(nombreArchivo);
            if (!kIsWeb && pickedFile.path != null) {
              _archivosNuevos.add(createFile(pickedFile.path));
              _archivosNuevosBytes.add(null);
            }
          });
        }
      } catch (e) {
        print('Error al escanear: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }

    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.linux) {
      await procesarImagen(ImageSource.gallery);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Agregar documento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E4A67),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF8F88D9)),
                title: const Text('Tomar foto'),
                subtitle: const Text('Usa la cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF8F88D9)),
                title: const Text('Elegir de galería'),
                subtitle: const Text('Selecciona una imagen existente'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await procesarImagen(source);
    }
  }

  Future<Map<int, String>> _extraerTextoDeArchivos() async {
    if (!_ocrDisponible) return {};
    final Map<int, String> textoPorArchivo = {};
    bool primerError = true;

    for (int i = 0; i < _archivosNuevos.length; i++) {
      final archivo = _archivosNuevos[i];
      if (archivo == null) continue;
      final nombre = _nombresArchivosNuevos[i] ?? '';
      final extension = nombre.split('.').last.toLowerCase();
      final esImagen =
          ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
      if (!esImagen) continue;

      try {
        final texto = await _extraerTextoOCR(archivo);
        if (texto.trim().isNotEmpty) {
          textoPorArchivo[i] = texto.trim();
          print('✓ OCR extraído de $nombre: ${texto.length} chars');
        }
      } catch (e) {
        print('Error OCR en $nombre: $e');
        if (primerError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Error al procesar OCR. Las imágenes se guardarán sin extraer texto.'),
              duration: Duration(seconds: 3),
            ),
          );
          primerError = false;
        }
      }
    }
    return textoPorArchivo;
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

  String _determinarTipoPorExtension(String nombre) {
    final extension = nombre.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'imagen';
    }
    if (extension == 'txt') return 'texto';
    return 'archivo';
  }

  String? _extraerPathDeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final index = segments.indexOf('documentos');
      if (index >= 0 && index + 1 < segments.length) {
        return segments.sublist(index + 1).join('/');
      }
    } catch (_) {}
    return null;
  }

  Future<void> _guardarDocumentoNuevo(BuildContext dialogContext) async {
    if (_isSaving) return;
    if (_archivosNuevosBytes.isEmpty && _archivosNuevos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona al menos un archivo para subir')),
      );
      return;
    }
    if (_categoriaArchivosNuevos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una categoría para los documentos')),
      );
      return;
    }

    _isSaving = true;
    if (mounted) setState(() {});

    final categoria = _categoriaArchivosNuevos!;
    int archivosSubidos = 0;

    try {
      final textoPorArchivo = await _extraerTextoDeArchivos();
      print('OCR extraído para ${textoPorArchivo.length} archivo(s)');

      for (int i = 0; i < _nombresArchivosNuevos.length; i++) {
        final nombreArchivo = _nombresArchivosNuevos[i];
        if (nombreArchivo == null) continue;

        final tipo = _determinarTipoPorExtension(nombreArchivo);
        final nombreSanitizado = _sanitizarNombreArchivo(nombreArchivo);
        final timestamp = DateTime.now().millisecondsSinceEpoch + i;
        final extension =
            nombreArchivo.contains('.') ? nombreArchivo.split('.').last : '';
        final nombreConTimestamp = extension.isNotEmpty
            ? '${nombreSanitizado.replaceAll('.$extension', '')}_$timestamp.$extension'
            : '${nombreSanitizado}_$timestamp';

        final path = '$categoria/${widget.id}/$nombreConTimestamp';
        final bytes =
            _archivosNuevosBytes[i] ?? await _archivosNuevos[i]?.readAsBytes();

        if (bytes != null) {
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final url = supabase.storage.from('documentos').getPublicUrl(path);

          final textoOcrArchivo = textoPorArchivo[i];
          await supabase.from('documentos').insert({
            'id_nino': widget.id,
            'nombre_archivo': nombreArchivo,
            'url': url,
            'tipo': tipo,
            'categoria': categoria,
            if (textoOcrArchivo != null && textoOcrArchivo.isNotEmpty)
              'contenido_texto': textoOcrArchivo,
          });

          print('✓ Archivo guardado: $nombreArchivo (tipo: $tipo)');
          archivosSubidos++;
        }
      }

      setState(() {
        _archivosNuevos.clear();
        _archivosNuevosBytes.clear();
        _nombresArchivosNuevos.clear();
        _categoriaArchivosNuevos = null;
      });

      await _cargarDatos();
      if (mounted) Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$archivosSubidos documento(s) agregado(s) correctamente')),
      );
    } catch (e) {
      print('❌ ERROR al guardar documentos nuevos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir documentos: $e')),
      );
    } finally {
      _isSaving = false;
      if (mounted) setState(() {});
    }
  }

  void _removerArchivo(int index, StateSetter setDialogState) {
    setDialogState(() {
      _archivosNuevos.removeAt(index);
      _archivosNuevosBytes.removeAt(index);
      _nombresArchivosNuevos.removeAt(index);
    });
  }

  Future<void> _eliminarDocumento(String documentoId, String? url) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: const Text(
            '¿Estás seguro de que quieres borrar este documento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => isLoading = true);

    try {
      if (url != null && url.isNotEmpty) {
        final path = _extraerPathDeUrl(url);
        if (path != null) {
          await supabase.storage.from('documentos').remove([path]);
        }
      }
      await supabase.from('documentos').delete().eq('id', documentoId);
      await _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento eliminado')),
      );
    } catch (e) {
      print('❌ ERROR al eliminar documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar documento: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  void _mostrarAgregarDocumentoDialog() {
    _archivosNuevos.clear();
    _archivosNuevosBytes.clear();
    _nombresArchivosNuevos.clear();
    _categoriaArchivosNuevos = categoriasDocumentos[1];

    showDialog(
      context: context,
      builder: (context) {
        bool dialogSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar documentos'),
              constraints: const BoxConstraints(maxWidth: 520),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _categoriaArchivosNuevos,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Carpeta',
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8F88D9),
                        ),
                        prefixIcon: const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFF8F88D9),
                          size: 18,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
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
                      items: categoriasDocumentos
                          .where((c) => c != 'Todas las categorías')
                          .map((c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  _formatearNombreCategoria(c),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(
                            () => _categoriaArchivosNuevos = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: dialogSaving
                          ? null
                          : () async {
                              await _seleccionarArchivoNuevo(setDialogState);
                            },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleccionar archivos'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: dialogSaving
                          ? null
                          : () async {
                              await _escanearDocumentoNuevo(setDialogState);
                            },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Escanear documento'),
                    ),
                    if (_nombresArchivosNuevos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Archivos seleccionados:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...List.generate(_nombresArchivosNuevos.length,
                          (index) {
                        final nombre = _nombresArchivosNuevos[index];
                        if (nombre == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(nombre,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: dialogSaving
                                    ? null
                                    : () =>
                                        _removerArchivo(index, setDialogState),
                                tooltip: 'Remover archivo',
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _nombresArchivosNuevos.isNotEmpty && !dialogSaving
                      ? () async {
                          setDialogState(() => dialogSaving = true);
                          await _guardarDocumentoNuevo(context);
                        }
                      : null,
                  child: dialogSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ Lógica de filtrado actualizada con los dos nuevos filtros
  void _filtrarDocumentos(String query) {
    setState(() {
      List<Map<String, dynamic>> resultado = documentos;

      // Filtro 1: por categoría
      if (categoriaDocumentoSeleccionada != null &&
          categoriaDocumentoSeleccionada != categoriasDocumentos[0]) {
        resultado = resultado.where((doc) {
          final cat = doc['categoria'] as String? ?? '';
          return cat == categoriaDocumentoSeleccionada;
        }).toList();
      }

      // Filtro 2: modo de búsqueda
      if (query.isNotEmpty) {
        final queryLower = query.toLowerCase();

        if (_buscarSoloEnOcr) {
          // ✅ Buscar SOLO en contenido_texto de documentos OCR
          // (documentos que tengan contenido_texto no vacío)
          resultado = resultado.where((doc) {
            final contenidoTexto = doc['contenido_texto'] as String? ?? '';
            // Solo documentos con texto OCR
            if (contenidoTexto.isEmpty) return false;
            return contenidoTexto.toLowerCase().contains(queryLower);
          }).toList();
        } else {
          // Búsqueda general en nombre, tipo y categoría.
          // No se incluyen los textos OCR cuando el modo está desactivado.
          resultado = resultado.where((doc) {
            final nombreArchivo = doc['nombre_archivo'] as String? ?? '';
            final tipo = doc['tipo'] as String? ?? '';
            final cat = doc['categoria'] as String? ?? '';

            return nombreArchivo.toLowerCase().contains(queryLower) ||
                tipo.toLowerCase().contains(queryLower) ||
                cat.toLowerCase().contains(queryLower);
          }).toList();
        }
      }

      documentosFiltrados = resultado;
    });
  }

  void _cambiarCategoriaDocumento(String? nuevaCategoria) {
    setState(() => categoriaDocumentoSeleccionada = nuevaCategoria);
    _filtrarDocumentos(_searchController.text);
  }

  String _formatearNombreCategoria(String categoria) {
    switch (categoria) {
      case 'documentos_personales': return 'Documentos Personales';
      case 'seguimiento': return 'Seguimiento';
      case 'salud_y_nutricion': return 'Salud y Nutrición';
      case 'familia_comunidad_y_redes': return 'Familia, Comunidad y Redes';
      case 'componente_pedagogico': return 'Componente Pedagógico';
      case 'otros': return 'Otros';
      case 'Todas las categorías': return 'Todas las categorías';
      default: return categoria;
    }
  }

  List<String> _extraerPalabrasClave(String texto) {
    if (texto.isEmpty) return [];
    String textoLimpio = texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final stopWords = {
      'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es',
      'un', 'una', 'por', 'con', 'se', 'para', 'como', 'su', 'al', 'lo',
      'le', 'me', 'mi', 'tu', 'te', 'si', 'no', 'pero', 'o', 'este', 'esta',
      'estos', 'estas', 'son', 'fue', 'era'
    };

    List<String> palabras = textoLimpio
        .split(' ')
        .where((p) => p.length > 2)
        .where((p) => !stopWords.contains(p))
        .where((p) => !RegExp(r'^\d+$').hasMatch(p))
        .toList();

    Map<String, int> frecuencia = {};
    for (var p in palabras) {
      frecuencia[p] = (frecuencia[p] ?? 0) + 1;
    }

    List<String> terminosCompuestos = _extraerTerminosCompuestos(textoLimpio);
    List<String> todas = [...frecuencia.keys, ...terminosCompuestos];
    List<MapEntry<String, double>> puntuadas = todas.map((p) {
      double puntuacion = (frecuencia[p] ?? 1).toDouble();
      puntuacion *= (p.length / 10.0).clamp(0.5, 2.0);
      if (p.contains(' ')) puntuacion *= 1.5;
      return MapEntry(p, puntuacion);
    }).toList();

    puntuadas.sort((a, b) => b.value.compareTo(a.value));
    return puntuadas.take(8).map((e) => e.key).toList();
  }

  List<String> _extraerTerminosCompuestos(String texto) {
    List<String> terminos = [];
    List<String> palabras = texto
        .split(' ')
        .where((p) => p.length > 2)
        .where((p) => !RegExp(r'^\d+$').hasMatch(p))
        .toList();

    for (int i = 0; i < palabras.length - 1; i++) {
      String bigrama = '${palabras[i]} ${palabras[i + 1]}';
      if (bigrama.length > 6 && bigrama.length < 30) terminos.add(bigrama);
    }
    return terminos;
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text.length > 100 ? '${text.substring(0, 100)}...' : text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7A7890), height: 1.5),
      );
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);
    if (index == -1) {
      return Text(
        text.length > 100 ? '${text.substring(0, 100)}...' : text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7A7890), height: 1.5),
      );
    }

    final start = (index - 24).clamp(0, text.length);
    final end = (index + query.length + 60).clamp(0, text.length);
    final preview = text.substring(start, end);
    final matchStart = preview.toLowerCase().indexOf(queryLower);

    return RichText(
      text: TextSpan(
        children: [
          if (start > 0)
            const TextSpan(
              text: '...',
              style: TextStyle(fontSize: 12, color: Color(0xFF9A97AE)),
            ),
          TextSpan(
            text: preview.substring(0, matchStart),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A7890), height: 1.5),
          ),
          TextSpan(
            text: preview.substring(matchStart, matchStart + query.length),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E63B6),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          TextSpan(
            text: preview.substring(matchStart + query.length),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7A7890), height: 1.5),
          ),
          if (end < text.length)
            const TextSpan(
              text: '...',
              style: TextStyle(fontSize: 12, color: Color(0xFF9A97AE)),
            ),
        ],
      ),
    );
  }

  // ✅ Texto descriptivo del estado actual de los filtros
  String _textoResultados() {
    final total = documentos.length;
    final filtrados = documentosFiltrados.length;
    final tieneQuery = _searchController.text.isNotEmpty;
    final tieneCategoria = categoriaDocumentoSeleccionada != null &&
        categoriaDocumentoSeleccionada != categoriasDocumentos[0];

    if (!tieneQuery && !tieneCategoria) {
      return 'Mostrando $total documento(s)';
    }

    String descripcion = 'Mostrando $filtrados de $total documento(s)';

    if (tieneCategoria) {
      descripcion +=
          ' en ${_formatearNombreCategoria(categoriaDocumentoSeleccionada!)}';
    }
    if (tieneQuery && _buscarSoloEnOcr) {
      descripcion += ' · búsqueda OCR: "${_searchController.text}"';
    } else if (tieneQuery) {
      descripcion += ' · "${_searchController.text}"';
    }

    return descripcion;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Detalle del Niño'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4A67)),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ListaNinosPage()),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _mostrarAgregarDocumentoDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Documento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81D4D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF1F2),
              Color(0xFFEAF7FF),
              Color(0xFFF4EEFF)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFB39DDB)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // ── Tarjeta info del niño ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.7)),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x1F8C93B5),
                                blurRadius: 26,
                                offset: Offset(0, 14))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFE5DDFB),
                                      width: 3),
                                  image: fotoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(fotoUrl),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: fotoUrl.isEmpty
                                    ? const Icon(Icons.person_outline,
                                        color: Color(0xFFB39DDB), size: 50)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(children: const [
                              Icon(Icons.person_outline,
                                  color: Color(0xFFB39DDB), size: 28),
                              SizedBox(width: 12),
                              Text('Información del niño',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4E4A67))),
                            ]),
                            const SizedBox(height: 20),
                            _InfoRow(
                                label: 'Nombre',
                                value: nombre.isEmpty ? 'Sin nombre' : nombre,
                                icon: Icons.badge_outlined),
                            const SizedBox(height: 16),
                            _InfoRow(
                                label: 'Género',
                                value: genero.isEmpty ? 'Sin género' : genero,
                                icon: Icons.wc_outlined),
                            const SizedBox(height: 16),
                            _InfoRow(
                                label: 'Fecha de nacimiento',
                                value: fechaNacimiento.isEmpty
                                    ? 'Sin fecha'
                                    : fechaNacimiento,
                                icon: Icons.calendar_today_outlined),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Tarjeta documentos ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.7)),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x1F8C93B5),
                                blurRadius: 26,
                                offset: Offset(0, 14))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: const [
                              Icon(Icons.description_outlined,
                                  color: Color(0xFFB39DDB), size: 28),
                              SizedBox(width: 12),
                              Text('Documentos registrados',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4E4A67))),
                            ]),
                            const SizedBox(height: 20),

                            // ── Filtro 1: Categoría ──
                            DropdownButtonFormField<String>(
                              value: categoriaDocumentoSeleccionada,
                              isExpanded: true,
                              isDense: true,
                              decoration: InputDecoration(
                                labelText: 'Carpeta',
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8F88D9),
                                ),
                                prefixIcon: const Icon(
                                  Icons.folder_outlined,
                                  color: Color(0xFF8F88D9),
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
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
                              dropdownColor: const Color(0xFFF8F5FF),
                              items: categoriasDocumentos
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c,
                                        child: Text(
                                          _formatearNombreCategoria(c),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4E4A67)),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: _cambiarCategoriaDocumento,
                            ),
                            const SizedBox(height: 12),
                            // ── Campo de búsqueda ──
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F5FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE5DDFB)),
                              ),
                              child: TextField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: _buscarSoloEnOcr
                                      ? 'Buscar palabras en texto escaneado...'
                                      : 'Buscar en documentos...',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFF7A7890),
                                      fontSize: 14),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Color(0xFFB39DDB), size: 20),
                                  suffixIcon:
                                      _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  color: Color(0xFFB39DDB),
                                                  size: 20),
                                              onPressed: () {
                                                _searchController.clear();
                                                _filtrarDocumentos('');
                                                FocusScope.of(context).unfocus();
                                                setState(() => _showOcrOption = false);
                                              },
                                            )
                                          : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4E4A67)),
                                onTap: () => setState(() => _showOcrOption = true),
                                onChanged: _filtrarDocumentos,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ── Filtro OCR ──
                            if (_showOcrOption)
                              Listener(
                                onPointerDown: (_) => _tappedFilter = true,
                                child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                setState(() {
                                  _buscarSoloEnOcr = !_buscarSoloEnOcr;
                                });
                                _filtrarDocumentos(_searchController.text);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _buscarSoloEnOcr
                                      ? const Color(0xFF7C4DFF).withOpacity(0.14)
                                      : const Color(0xFFF4F1FF),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _buscarSoloEnOcr
                                        ? const Color(0xFF7C4DFF)
                                        : const Color(0xFFE5DDFB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.document_scanner_outlined,
                                      color: _buscarSoloEnOcr
                                          ? const Color(0xFF7C4DFF)
                                          : const Color(0xFF9A97AE),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Buscar solo en textos escaneados (OCR)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _buscarSoloEnOcr
                                              ? const Color(0xFF43327A)
                                              : const Color(0xFF4E4A67),
                                        ),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 40,
                                      height: 22,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: _buscarSoloEnOcr
                                            ? const Color(0xFF7C4DFF)
                                            : const Color(0xFFD8CFFB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Align(
                                        alignment: _buscarSoloEnOcr
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Indicador de resultados ──
                            if (documentos.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _textoResultados(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7A7890),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // ── Lista de documentos ──
                            if (documentos.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F5FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE5DDFB)),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No hay documentos registrados para este niño.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF7A7890)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else if (documentosFiltrados.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFFFD54F)),
                                ),
                                child: Center(
                                  child: Text(
                                    _buscarSoloEnOcr &&
                                            _searchController.text.isNotEmpty
                                        ? 'No se encontraron documentos OCR con "${_searchController.text}".'
                                        : 'No se encontraron documentos.',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF7A7890)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                             ...documentosFiltrados.map((documento) {
  final tipo = documento['tipo'] as String? ?? '';
  final url = documento['url'] as String?;
  final nombreArchivo =
      documento['nombre_archivo'] as String? ?? 'Documento';
  final contenidoTexto =
      documento['contenido_texto'] as String? ?? '';
  final cat =
      documento['categoria'] as String? ?? 'Sin categoría';
  final tieneOcr = contenidoTexto.isNotEmpty;

  // ✅ Ocultar documento_oculto.txt
  if (nombreArchivo == 'documento_oculto.txt') {
    return const SizedBox.shrink();
  }

                                return Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                      color: tieneOcr &&
                                              _buscarSoloEnOcr
                                          ? const Color(0xFFB39DDB)
                                          : const Color(0xFFE9E6F8),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x0F8C93B5),
                                          blurRadius: 8,
                                          offset: Offset(0, 4))
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12),
                                              gradient:
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFFB39DDB),
                                                  Color(0xFF81D4D4)
                                                ],
                                                begin: Alignment.topLeft,
                                                end:
                                                    Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Icon(
                                              tipo == 'imagen'
                                                  ? Icons.image_outlined
                                                  : tipo == 'archivo'
                                                      ? Icons
                                                          .insert_drive_file_outlined
                                                      : Icons
                                                          .text_fields_outlined,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        nombreArchivo,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF3F3D56),
                                                        ),
                                                      ),
                                                    ),
                                                    // ✅ Badge OCR
                                                    if (tieneOcr)
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFEDE7F6),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      6),
                                                          border: Border.all(
                                                              color: const Color(
                                                                  0xFFB39DDB)),
                                                        ),
                                                        child: const Text(
                                                          'OCR',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                                0xFF6E63B6),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tipo: $tipo • Categoría: ${_formatearNombreCategoria(cat)}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(
                                                          0xFF7A7890)),
                                                ),
                                                // Preview del texto con resaltado
                                                if (_searchController
                                                        .text.isNotEmpty &&
                                                    contenidoTexto
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  _buildHighlightedText(
                                                      contenidoTexto,
                                                      _searchController
                                                          .text),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () =>
                                                _eliminarDocumento(
                                              documento['id'].toString(),
                                              url,
                                            ),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFEF5350)),
                                            label: const Text('Eliminar',
                                                style: TextStyle(
                                                    color: Color(
                                                        0xFFEF5350))),
                                          ),
                                        ],
                                      ),
                                     if (url != null && url.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 12),
                                            if (contenidoTexto.isNotEmpty &&
                                                (_buscarSoloEnOcr ||
                                                    (_searchController.text.isNotEmpty &&
                                                        contenidoTexto
                                                            .toLowerCase()
                                                            .contains(_searchController.text.toLowerCase()))))
                                              _TextoOcrViewer(
                                                texto: contenidoTexto,
                                                query: _searchController.text,
                                              )
                                            else if (tipo != 'texto')
                                              DocumentViewer(
                                                url: url,
                                                tipo: tipo,
                                                nino: nombre,
                                                categoria: cat,
                                                fileName: nombreArchivo,
                                                bucket: 'documentos',
                                                contenidoTexto: contenidoTexto.isNotEmpty ? contenidoTexto : null,
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              }),
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
                              Color(0xFF81D4D4)
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x3381D4D4),
                                blurRadius: 18,
                                offset: Offset(0, 8))
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ListaNinosPage()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text('Ver lista de niños',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
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
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFB39DDB).withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6E63B6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A7890))),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF4E4A67))),
            ],
          ),
        ),
      ],
    );
  }
}
class _TextoOcrViewer extends StatefulWidget {
  final String texto;
  final String query;

  const _TextoOcrViewer({required this.texto, required this.query});

  @override
  State<_TextoOcrViewer> createState() => _TextoOcrViewerState();
}

class _TextoOcrViewerState extends State<_TextoOcrViewer> {
  final ScrollController _scrollController = ScrollController();
  bool _expandido = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TextoOcrViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cuando cambia la búsqueda, hacer scroll a la coincidencia
    if (oldWidget.query != widget.query && widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMatch());
    }
  }

  void _scrollToMatch() {
    if (!_scrollController.hasClients) return;
    final index = widget.texto.toLowerCase().indexOf(widget.query.toLowerCase());
    if (index == -1) return;

    // Estimar posición: ~0.016 px por caracter a 14px de fuente con line-height 1.5
    final estimatedOffset = (index / widget.texto.length) *
        _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      estimatedOffset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  List<TextSpan> _buildSpans() {
    if (widget.query.isEmpty) {
      return [
        TextSpan(
          text: widget.texto,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4E4A67),
          ),
        )
      ];
    }

    final spans = <TextSpan>[];
    final queryLower = widget.query.toLowerCase();
    final textoLower = widget.texto.toLowerCase();
    int start = 0;

    while (true) {
      final index = textoLower.indexOf(queryLower, start);
      if (index == -1) {
        if (start < widget.texto.length) {
          spans.add(TextSpan(
            text: widget.texto.substring(start),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4E4A67),
            ),
          ));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: widget.texto.substring(start, index),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4E4A67),
          ),
        ));
      }

      spans.add(TextSpan(
        text: widget.texto.substring(index, index + widget.query.length),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6E63B6),
          backgroundColor: Color(0x40B39DDB),
        ),
      ));

      start = index + widget.query.length;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final tieneCoincidencia = widget.query.isNotEmpty &&
        widget.texto.toLowerCase().contains(widget.query.toLowerCase());

    // Contar coincidencias
    int totalCoincidencias = 0;
    if (widget.query.isNotEmpty) {
      final queryLower = widget.query.toLowerCase();
      final textoLower = widget.texto.toLowerCase();
      int idx = 0;
      while (true) {
        final found = textoLower.indexOf(queryLower, idx);
        if (found == -1) break;
        totalCoincidencias++;
        idx = found + queryLower.length;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE7E1F5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          // Header
Padding(
  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
  child: Row(
    children: [
      const Icon(Icons.document_scanner_outlined,
          color: Color(0xFFB39DDB), size: 18),
      const SizedBox(width: 8),
      // ✅ Expanded para que el título no desborde
      Expanded(
        child: Text(
          'Texto de la imagen',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6E63B6),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 4),
      // Badge con número de coincidencias
      if (tieneCoincidencia)
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFB39DDB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$totalCoincidencias',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      // Botón expandir/colapsar
      IconButton(
        icon: Icon(
          _expandido
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          color: const Color(0xFFB39DDB),
          size: 20,
        ),
        onPressed: () {
          setState(() => _expandido = !_expandido);
          if (_expandido && widget.query.isNotEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToMatch());
          }
        },
        tooltip: _expandido ? 'Colapsar' : 'Expandir',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
            minWidth: 32, minHeight: 32),
      ),
    ],
  ),
),

          // Si hay coincidencia y está colapsado, mostrar preview
          if (!_expandido && tieneCoincidencia) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: _buildPreviewCoincidencia(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _expandido = true);
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToMatch());
                },
                child: const Text(
                  'Ver todo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7C4DFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          // Si está colapsado y sin búsqueda, mostrar solo primeras líneas
          if (!_expandido && !tieneCoincidencia) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                widget.texto.length > 120
                    ? '${widget.texto.substring(0, 120)}...'
                    : widget.texto,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A7890),
                ),
              ),
            ),
            if (widget.texto.length > 120)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: GestureDetector(
                  onTap: () => setState(() => _expandido = true),
                  child: const Text(
                    'Ver texto completo →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB39DDB),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],

          // Texto completo expandido con scroll
          if (_expandido) ...[
            Container(
              height: 280,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5DDFB)),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  child: RichText(
                    text: TextSpan(children: _buildSpans()),
                  ),
                ),
              ),
            ),
            // Botón scroll a coincidencia si hay búsqueda
            if (tieneCoincidencia)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    const Icon(Icons.my_location,
                        color: Color(0xFFB39DDB), size: 14),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _scrollToMatch,
                      child: const Text(
                        'Ir a la coincidencia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB39DDB),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCoincidencia() {
    final index = widget.texto
        .toLowerCase()
        .indexOf(widget.query.toLowerCase());
    if (index == -1) return const SizedBox.shrink();

    final start = (index - 40).clamp(0, widget.texto.length);
    final end =
        (index + widget.query.length + 80).clamp(0, widget.texto.length);
    final preview = widget.texto.substring(start, end);
    final matchInPreview =
        preview.toLowerCase().indexOf(widget.query.toLowerCase());

    if (matchInPreview == -1) return const SizedBox.shrink();

    return RichText(
      text: TextSpan(
        children: [
          if (start > 0)
            const TextSpan(
              text: '...',
              style: TextStyle(fontSize: 13, color: Color(0xFF9A97AE)),
            ),
          TextSpan(
            text: preview.substring(0, matchInPreview),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF7A7890)),
          ),
          TextSpan(
            text: preview.substring(
                matchInPreview, matchInPreview + widget.query.length),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7C4DFF),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: preview.substring(matchInPreview + widget.query.length),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF7A7890)),
          ),
          if (end < widget.texto.length)
            const TextSpan(
              text: '...',
              style: TextStyle(fontSize: 13, color: Color(0xFF9A97AE)),
            ),
        ],
      ),
    );
  }
}

