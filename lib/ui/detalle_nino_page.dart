import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? categoriaDocumentoSeleccionada; // Nueva variable para filtro de categoría
  final TextEditingController _searchController = TextEditingController();

  // Variables para múltiples archivos
  final List<dynamic> _archivosNuevos = [];
  final List<Uint8List?> _archivosNuevosBytes = [];
  final List<String?> _nombresArchivosNuevos = [];
  String? _categoriaArchivosNuevos; // Categoría común para todos los archivos
  final ImagePicker _picker = ImagePicker();

  // Categorías disponibles para documentos
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
    categoriaDocumentoSeleccionada = categoriasDocumentos[0]; // "Todas las categorías"
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      isLoading = true;
    });

    try {
      final ninoData = await supabase
          .from('ninos')
          .select()
          .eq('id', widget.id)
          .single();

      final docData = await supabase
          .from('documentos')
          .select()
          .eq('id_nino', widget.id);

      print("✓ Niño cargado: ${ninoData['nombre']}");
      print("✓ Documentos encontrados: ${(docData as List).length}");

      setState(() {
        nombre = (ninoData['nombre'] ?? '') as String;
        genero = (ninoData['genero'] ?? '') as String;
        fechaNacimiento = (ninoData['fecha_nacimiento'] ?? '') as String;
        categoria = (ninoData['categoria'] ?? 'Sin categoría') as String;
        fotoUrl = (ninoData['foto'] ?? '') as String;

        documentos = List<Map<String, dynamic>>.from(
          docData as List<dynamic>? ?? [],
        );
        documentosFiltrados = documentos;
        // Aplicar filtros iniciales
        _filtrarDocumentos(_searchController.text);
        isLoading = false;
      });
    } catch (e) {
      print("❌ ERROR al cargar datos: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _seleccionarArchivoNuevo(StateSetter setDialogState) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true, // Permitir selección múltiple
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
        const SnackBar(content: Text('Escaneo no disponible en Web. Usa la app móvil.')),
      );
      return;
    }

    // Verificar si estamos en Linux (donde no hay soporte nativo para cámara)
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.linux) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escaneo no disponible en Linux. Usa la app móvil (Android/iOS).')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setDialogState(() {
          final nombreArchivo = 'documento_escaner_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _nombresArchivosNuevos.add(nombreArchivo);
          if (!kIsWeb && pickedFile.path != null) {
            _archivosNuevos.add(createFile(pickedFile.path));
            _archivosNuevosBytes.add(null);
          }
        });
      }
    } catch (e) {
      print('Error al escanear documento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al acceder a la cámara. Verifica los permisos.')),
      );
    }
  }

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

  String _determinarTipoPorExtension(String nombre) {
    final extension = nombre.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'imagen';
    }
    if (extension == 'txt') {
      return 'texto';
    }
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
    if (_archivosNuevosBytes.isEmpty && _archivosNuevos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un archivo para subir')),
      );
      return;
    }

    if (_categoriaArchivosNuevos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoría para los documentos')),
      );
      return;
    }

    final categoria = _categoriaArchivosNuevos!;
    int archivosSubidos = 0;

    try {
      for (int i = 0; i < _nombresArchivosNuevos.length; i++) {
        final nombreArchivo = _nombresArchivosNuevos[i];
        if (nombreArchivo == null) continue;

        final tipo = _determinarTipoPorExtension(nombreArchivo);
        final nombreSanitizado = _sanitizarNombreArchivo(nombreArchivo);

        // Agregar timestamp único para evitar duplicados
        final timestamp = DateTime.now().millisecondsSinceEpoch + i; // Agregar i para diferenciar archivos
        final extension = nombreArchivo.contains('.') ? nombreArchivo.split('.').last : '';
        final nombreConTimestamp = extension.isNotEmpty
            ? '${nombreSanitizado.replaceAll('.$extension', '')}_$timestamp.$extension'
            : '${nombreSanitizado}_$timestamp';

        final path = '$categoria/${widget.id}/$nombreConTimestamp';

        final bytes = _archivosNuevosBytes[i] ?? await _archivosNuevos[i]?.readAsBytes();
        if (bytes != null) {
          await supabase.storage.from('documentos').uploadBinary(path, bytes);
          final url = supabase.storage.from('documentos').getPublicUrl(path);

          await supabase.from('documentos').insert({
            'id_nino': widget.id,
            'nombre_archivo': nombreArchivo,
            'url': url,
            'tipo': tipo,
            'categoria': categoria,
          });

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
      if (mounted) {
        Navigator.pop(dialogContext);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$archivosSubidos documento(s) agregado(s) correctamente')),
      );
    } catch (e) {
      print('❌ ERROR al guardar documentos nuevos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir documentos: $e')),
      );
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
        content: const Text('¿Estás seguro de que quieres borrar este documento?'),
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

    setState(() {
      isLoading = true;
    });

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
      setState(() {
        isLoading = false;
      });
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar documentos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _categoriaArchivosNuevos,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (para todos los documentos)',
                      ),
                      items: categoriasDocumentos
                          .where((categoria) => categoria != 'Todas las categorías')
                          .map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria,
                          child: Text(_formatearNombreCategoria(categoria)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _categoriaArchivosNuevos = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _seleccionarArchivoNuevo(setDialogState);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleccionar archivos'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _escanearDocumentoNuevo(setDialogState);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Escanear documento'),
                    ),
                    if (_nombresArchivosNuevos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Archivos seleccionados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_nombresArchivosNuevos.length, (index) {
                        final nombre = _nombresArchivosNuevos[index];
                        if (nombre == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _removerArchivo(index, setDialogState),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _nombresArchivosNuevos.isNotEmpty ? () => _guardarDocumentoNuevo(context) : null,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _filtrarDocumentos(String query) {
    setState(() {
      if (query.isEmpty && (categoriaDocumentoSeleccionada == null || categoriaDocumentoSeleccionada == categoriasDocumentos[0])) {
        documentosFiltrados = documentos;
      } else {
        final queryLower = query.toLowerCase();
        documentosFiltrados = documentos.where((documento) {
          final contenidoTexto = documento['contenido_texto'] as String? ?? '';
          final nombreArchivo = documento['nombre_archivo'] as String? ?? '';
          final tipo = documento['tipo'] as String? ?? '';
          final categoria = documento['categoria'] as String? ?? '';

          // Filtro por categoría
          if (categoriaDocumentoSeleccionada != null && categoriaDocumentoSeleccionada != categoriasDocumentos[0]) {
            if (categoria != categoriaDocumentoSeleccionada) {
              return false;
            }
          }

          // Si no hay búsqueda de texto, solo aplicar filtro de categoría
          if (query.isEmpty) {
            return true;
          }

          // Buscar en contenido directo
          if (contenidoTexto.toLowerCase().contains(queryLower) ||
              nombreArchivo.toLowerCase().contains(queryLower) ||
              tipo.toLowerCase().contains(queryLower) ||
              categoria.toLowerCase().contains(queryLower)) {
            return true;
          }

          // Buscar en palabras clave extraídas
          final palabrasClave = _extraerPalabrasClave(contenidoTexto);
          return palabrasClave.any((palabra) =>
              palabra.toLowerCase().contains(queryLower) ||
              queryLower.contains(palabra.toLowerCase()));
        }).toList();
      }
    });
  }

  // Función para cambiar la categoría seleccionada
  void _cambiarCategoriaDocumento(String? nuevaCategoria) {
    setState(() {
      categoriaDocumentoSeleccionada = nuevaCategoria;
    });
    _filtrarDocumentos(_searchController.text);
  }

  // Función para formatear nombres de categorías
  String _formatearNombreCategoria(String categoria) {
    switch (categoria) {
      case 'documentos_personales':
        return 'Documentos Personales';
      case 'seguimiento':
        return 'Seguimiento';
      case 'salud_y_nutricion':
        return 'Salud y Nutrición';
      case 'familia_comunidad_y_redes':
        return 'Familia, Comunidad y Redes';
      case 'componente_pedagogico':
        return 'Componente Pedagógico';
      case 'otros':
        return 'Otros';
      case 'Todas las categorías':
        return 'Todas las categorías';
      default:
        return categoria;
    }
  }

  // Función para extraer palabras clave del texto OCR
  List<String> _extraerPalabrasClave(String texto) {
    if (texto.isEmpty) return [];

    // Convertir a minúsculas y limpiar
    String textoLimpio = texto.toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Palabras comunes a excluir
    final stopWords = {
      'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es', 'un', 'una',
      'por', 'con', 'se', 'para', 'como', 'su', 'al', 'lo', 'le', 'me', 'mi', 'tu', 'te',
      'si', 'no', 'pero', 'o', 'este', 'esta', 'estos', 'estas', 'son', 'fue', 'era'
    };

    // Dividir en palabras y filtrar
    List<String> palabras = textoLimpio.split(' ')
        .where((palabra) => palabra.length > 2)
        .where((palabra) => !stopWords.contains(palabra))
        .where((palabra) => !RegExp(r'^\d+$').hasMatch(palabra))
        .toList();

    // Contar frecuencia
    Map<String, int> frecuencia = {};
    for (var palabra in palabras) {
      frecuencia[palabra] = (frecuencia[palabra] ?? 0) + 1;
    }

    // Extraer términos compuestos
    List<String> terminosCompuestos = _extraerTerminosCompuestos(textoLimpio);

    // Combinar y puntuar
    List<String> todasPalabras = [...frecuencia.keys, ...terminosCompuestos];
    List<MapEntry<String, double>> puntuadas = todasPalabras.map((palabra) {
      double puntuacion = (frecuencia[palabra] ?? 1).toDouble();
      puntuacion *= (palabra.length / 10.0).clamp(0.5, 2.0);
      if (palabra.contains(' ')) puntuacion *= 1.5;
      return MapEntry(palabra, puntuacion);
    }).toList();

    puntuadas.sort((a, b) => b.value.compareTo(a.value));
    return puntuadas.take(8).map((e) => e.key).toList();
  }

  // Función para extraer términos compuestos
  List<String> _extraerTerminosCompuestos(String texto) {
    List<String> terminos = [];
    List<String> palabras = texto.split(' ')
        .where((p) => p.length > 2)
        .where((p) => !RegExp(r'^\d+$').hasMatch(p))
        .toList();

    // Bigramas
    for (int i = 0; i < palabras.length - 1; i++) {
      String bigrama = '${palabras[i]} ${palabras[i + 1]}';
      if (bigrama.length > 6 && bigrama.length < 30) {
        terminos.add(bigrama);
      }
    }

    return terminos;
  }

  // Función para resaltar texto en resultados de búsqueda
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text.length > 100 ? '${text.substring(0, 100)}...' : text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF7A7890),
        ),
      );
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final index = textLower.indexOf(queryLower);

    if (index == -1) {
      return Text(
        text.length > 100 ? '${text.substring(0, 100)}...' : text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF7A7890),
        ),
      );
    }

    // Mostrar contexto alrededor de la coincidencia
    final startContext = (index - 30).clamp(0, text.length);
    final endContext = (index + query.length + 70).clamp(0, text.length);
    final contextText = text.substring(startContext, endContext);
    final matchStart = contextText.toLowerCase().indexOf(queryLower);

    return RichText(
      text: TextSpan(
        children: [
          if (startContext > 0) const TextSpan(text: '...'),
          TextSpan(
            text: contextText.substring(0, matchStart),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A7890),
            ),
          ),
          TextSpan(
            text: contextText.substring(matchStart, matchStart + query.length),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB39DDB),
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0x1FB39DDB),
            ),
          ),
          TextSpan(
            text: contextText.substring(matchStart + query.length),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A7890),
            ),
          ),
          if (endContext < text.length) const TextSpan(text: '...'),
        ],
      ),
    );
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
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
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFB39DDB),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                          ),
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
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE5DDFB),
                                    width: 3,
                                  ),
                                  image: fotoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(fotoUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: fotoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person_outline,
                                        color: Color(0xFFB39DDB),
                                        size: 50,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: const [
                                Icon(
                                  Icons.person_outline,
                                  color: Color(0xFFB39DDB),
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Información del niño',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4E4A67),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _InfoRow(
                              label: 'Nombre',
                              value: nombre.isEmpty ? 'Sin nombre' : nombre,
                              icon: Icons.badge_outlined,
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              label: 'Género',
                              value: genero.isEmpty ? 'Sin género' : genero,
                              icon: Icons.wc_outlined,
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              label: 'Fecha de nacimiento',
                              value: fechaNacimiento.isEmpty
                                  ? 'Sin fecha'
                                  : fechaNacimiento,
                              icon: Icons.calendar_today_outlined,
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                          ),
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
                            Row(
                              children: const [
                                Icon(
                                  Icons.description_outlined,
                                  color: Color(0xFFB39DDB),
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Documentos registrados',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4E4A67),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Campo de búsqueda en documentos
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F5FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5DDFB),
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar en documentos...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF7A7890),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFFB39DDB),
                                    size: 20,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: Color(0xFFB39DDB),
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _filtrarDocumentos('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4E4A67),
                                ),
                                onChanged: _filtrarDocumentos,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Selector de categoría de documentos
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F5FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5DDFB),
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: categoriaDocumentoSeleccionada,
                                decoration: const InputDecoration(
                                  hintText: 'Seleccionar categoría',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF7A7890),
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.folder_outlined,
                                    color: Color(0xFFB39DDB),
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4E4A67),
                                ),
                                dropdownColor: const Color(0xFFF8F5FF),
                                items: categoriasDocumentos.map((categoria) {
                                  return DropdownMenuItem<String>(
                                    value: categoria,
                                    child: Text(
                                      _formatearNombreCategoria(categoria),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF4E4A67),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: _cambiarCategoriaDocumento,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Indicador de resultados
                            if (documentos.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  documentosFiltrados.length == documentos.length &&
                                          (categoriaDocumentoSeleccionada == null || categoriaDocumentoSeleccionada == categoriasDocumentos[0]) &&
                                          _searchController.text.isEmpty
                                      ? 'Mostrando ${documentos.length} documento(s)'
                                      : documentosFiltrados.length == documentos.length &&
                                              (categoriaDocumentoSeleccionada != null && categoriaDocumentoSeleccionada != categoriasDocumentos[0])
                                          ? 'Mostrando ${documentosFiltrados.length} documento(s) en ${_formatearNombreCategoria(categoriaDocumentoSeleccionada!)}'
                                          : 'Mostrando ${documentosFiltrados.length} de ${documentos.length} documento(s)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF7A7890),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (documentos.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F5FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5DDFB),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No hay documentos registrados para este niño.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF7A7890),
                                    ),
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
                                    color: const Color(0xFFFFD54F),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _searchController.text.isNotEmpty && (categoriaDocumentoSeleccionada == null || categoriaDocumentoSeleccionada == categoriasDocumentos[0])
                                        ? 'No se encontraron documentos que coincidan con "${_searchController.text}".'
                                        : categoriaDocumentoSeleccionada != null && categoriaDocumentoSeleccionada != categoriasDocumentos[0] && _searchController.text.isNotEmpty
                                            ? 'No se encontraron documentos en ${_formatearNombreCategoria(categoriaDocumentoSeleccionada!)} que coincidan con "${_searchController.text}".'
                                            : categoriaDocumentoSeleccionada != null && categoriaDocumentoSeleccionada != categoriasDocumentos[0]
                                                ? 'No se encontraron documentos en la categoría ${_formatearNombreCategoria(categoriaDocumentoSeleccionada!)}.'
                                                : 'No se encontraron documentos que coincidan con la búsqueda.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF7A7890),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ...documentosFiltrados.map((documento) {
                                final tipo = documento['tipo'] as String? ?? '';
                                final url = documento['url'] as String?;
                                final nombreArchivo =
                                    documento['nombre_archivo'] as String? ??
                                    'Documento';
                                final contenidoTexto = documento['contenido_texto'] as String? ?? '';
                                final categoria = documento['categoria'] as String? ?? 'Sin categoría';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE9E6F8),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0F8C93B5),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
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
                                                  BorderRadius.circular(12),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFB39DDB),
                                                  Color(0xFF81D4D4),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Icon(
                                              tipo == 'imagen'
                                                  ? Icons.image_outlined
                                                  : tipo == 'archivo'
                                                  ? Icons
                                                        .insert_drive_file_outlined
                                                  : Icons.text_fields_outlined,
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
                                                Text(
                                                  nombreArchivo,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF3F3D56),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Tipo: ${tipo.isEmpty ? 'Desconocido' : tipo} • Categoría: ${categoria}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF7A7890),
                                                  ),
                                                ),
                                                // Mostrar preview del contenido si hay búsqueda activa
                                                if (_searchController.text.isNotEmpty && contenidoTexto.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  _buildHighlightedText(contenidoTexto, _searchController.text),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _eliminarDocumento(
                                              documento['id'].toString(),
                                              url,
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Color(0xFFEF5350),
                                            ),
                                            label: const Text(
                                              'Eliminar',
                                              style: TextStyle(
                                                color: Color(0xFFEF5350),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (tipo == 'imagen' && url != null) ...[
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            url,
                                            height: 120,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 120,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8F5FF),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE5DDFB,
                                                  ),
                                                ),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'No se pudo mostrar la imagen',
                                                  style: TextStyle(
                                                    color: Color(0xFF7A7890),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else if (url != null && url.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        DocumentViewer(
                                          url: url,
                                          tipo: tipo,
                                        ),
                                      ],
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
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ListaNinosPage(),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Ver lista de niños',
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A7890),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4E4A67)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
