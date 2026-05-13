import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:redinfancia/services/document_storage_service.dart';

class DocumentViewer extends StatefulWidget {
  final String url;
  final String tipo;
  final String? nino;
  final String? categoria;
  final String? fileName;
  final String? bucket;
  final String? contenidoTexto;

  const DocumentViewer({
    super.key,
    required this.url,
    required this.tipo,
    this.nino,
    this.categoria,
    this.fileName,
    this.bucket,
    this.contenidoTexto,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  String? _localFilePath;
  bool _isDownloading = false;
  final DocumentStorageService _storageService = DocumentStorageService();

  String get tipo {
    final t = widget.tipo.toLowerCase();
    final url = widget.url.toLowerCase();
    if (t == 'archivo') {
      if (url.contains('.pdf')) return 'pdf';
      if (url.contains('.doc')) return 'word';
      if (url.contains('.xls')) return 'excel';
      if (url.contains('.txt')) return 'texto';
      if (url.contains('.jpg') || url.contains('.png')) return 'imagen';
    }
    return t;
  }

  @override
  void initState() {
    super.initState();
    if (tipo == 'pdf') {
      final tieneParametros = widget.nino != null &&
          widget.categoria != null &&
          widget.fileName != null &&
          widget.bucket != null;

      if (tieneParametros) {
        _cargarPdfConServicio();
      } else {
        _downloadPdf();
      }
    }
  }

  Future<void> _cargarPdfConServicio() async {
    setState(() => _isDownloading = true);
    try {
      final parsed = _parseSupabaseUrl(widget.url);
      final actualFileName = parsed.filePathSegments.isNotEmpty
          ? parsed.filePathSegments.last
          : widget.fileName!;

      final localPath = await _storageService.getAndSaveFile(
        parsed.bucket,
        parsed.filePath,
        widget.nino!,
        widget.categoria!,
        actualFileName,
      );

      if (mounted) {
        setState(() {
          _localFilePath = localPath;
          _isDownloading = false;
        });
      }
    } catch (e) {
      print('Error cargando PDF con servicio, usando fallback: $e');
      if (mounted) _downloadPdf();
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      final res = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));

      await file.writeAsBytes(res.bodyBytes);

      if (mounted) {
        setState(() {
          _localFilePath = file.path;
          _isDownloading = false;
        });
      }
    } catch (e) {
      print('Error descargando PDF: $e');
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  SupabasePath _parseSupabaseUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    final publicIndex = segments.indexOf('public');
    if (publicIndex != -1 && segments.length > publicIndex + 2) {
      final bucket = segments[publicIndex + 1];
      final filePathSegments = segments.sublist(publicIndex + 2);
      return SupabasePath(bucket, filePathSegments);
    }

    final objectIndex = segments.indexOf('object');
    if (objectIndex != -1 && segments.length > objectIndex + 2) {
      final bucket = segments[objectIndex + 1];
      final filePathSegments = segments.sublist(objectIndex + 2);
      return SupabasePath(bucket, filePathSegments);
    }

    throw Exception('No se pudo parsear la URL de Supabase: $url');
  }

  Future<void> abrirEnNavegador() async {
    final uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir")),
        );
      }
    }
  }

  Widget imagen() {
    // Si hay texto OCR disponible, mostrar el texto en lugar de la imagen
    if (widget.contenidoTexto != null && widget.contenidoTexto!.trim().isNotEmpty) {
      return textoOcr();
    }

    // Si no hay texto OCR, mostrar el botón para abrir la imagen
    return Column(
      children: [
        const Icon(
          Icons.image,
          size: 48,
          color: Color(0xFFB39DDB),
        ),
        const SizedBox(height: 12),
        const Text(
          "Imagen disponible",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4E4A67),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: abrirEnNavegador,
          icon: const Icon(Icons.open_in_browser),
          label: const Text("Abrir imagen"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB39DDB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget texto() {
    return FutureBuilder(
      future: http.get(Uri.parse(widget.url)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data as http.Response;
        return SizedBox(
          height: 400,
          child: SingleChildScrollView(child: Text(data.body)),
        );
      },
    );
  }

  Widget textoOcr() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DDFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.text_fields,
                color: Color(0xFFB39DDB),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                "Texto extraído de la imagen",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4E4A67),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: SingleChildScrollView(
              child: Text(
                widget.contenidoTexto!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4E4A67),
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: abrirEnNavegador,
                icon: const Icon(Icons.open_in_browser, size: 16),
                label: const Text("Ver imagen original"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB39DDB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget pdf() {
    if (_isDownloading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text("Cargando documento..."),
          ],
        ),
      );
    }

    if (_localFilePath != null) {
      return Column(
        children: [
          const Icon(
            Icons.picture_as_pdf,
            size: 48,
            color: Color(0xFFB39DDB),
          ),
          const SizedBox(height: 12),
          const Text(
            "PDF listo para abrir",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4E4A67),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.file(_localFilePath!);
              if (!await launchUrl(uri)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "No se pudo abrir el PDF. Verifica que tengas un visor instalado.",
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text("Abrir PDF"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB39DDB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: abrirEnNavegador,
            icon: const Icon(Icons.open_in_browser),
            label: const Text("Abrir en navegador"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81D4D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      );
    }

    // No se pudo cargar
    return Column(
      children: [
        const Text("No se pudo cargar el PDF."),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _downloadPdf,
          icon: const Icon(Icons.refresh),
          label: const Text("Reintentar"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB39DDB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: abrirEnNavegador,
          icon: const Icon(Icons.open_in_browser),
          label: const Text("Abrir en navegador"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF81D4D4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget externo() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _openWithStorageService,
          icon: const Icon(Icons.open_in_new),
          label: const Text("Abrir documento"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB39DDB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Se abrirá el archivo local o se descargará si no existe.",
          style: TextStyle(fontSize: 13, color: Color(0xFF7A7890)),
        ),
        if (_isDownloading) ...[
          const SizedBox(height: 10),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  Future<void> _openWithStorageService() async {
    setState(() => _isDownloading = true);
    try {
      final parsed = _parseSupabaseUrl(widget.url);
      final actualFileName = parsed.filePathSegments.isNotEmpty
          ? parsed.filePathSegments.last
          : widget.fileName!;

      await _storageService.getAndOpenFile(
        parsed.bucket,
        parsed.filePath,
        widget.nino!,
        widget.categoria!,
        actualFileName,
      );

      if (mounted) setState(() => _isDownloading = false);
    } catch (e) {
      print('Error abriendo con servicio: $e');
      if (mounted) setState(() => _isDownloading = false);
      abrirEnNavegador();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tipo == 'imagen') return imagen();
    if (tipo == 'pdf') return pdf();
    if (tipo == 'texto') return texto();
    if (tipo == 'word' || tipo == 'excel') return externo();

    return Column(
      children: [
        const Text("Tipo no soportado"),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: abrirEnNavegador,
          child: const Text("Abrir en navegador"),
        ),
      ],
    );
  }
}

class SupabasePath {
  final String bucket;
  final String filePath;
  final List<String> filePathSegments;

  SupabasePath(this.bucket, this.filePathSegments)
      : filePath = filePathSegments.join('/');
}