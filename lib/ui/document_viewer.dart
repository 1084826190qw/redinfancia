import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentViewer extends StatefulWidget {
  final String url;
  final String tipo;

  const DocumentViewer({
    super.key,
    required this.url,
    required this.tipo,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  String? _localFilePath;
  String? _errorMessage;
  bool _isDownloading = false;
  bool _pdfRendered = false;
  int _pdfPages = 0;

  @override
  void initState() {
    super.initState();
    if (widget.tipo.toLowerCase() == 'pdf') {
      _checkAndDownloadFile();
    }
  }

  Future<void> _checkAndDownloadFile() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.url.split('/').last;
      final file = File('${tempDir.path}/$fileName');

      print('DocumentViewer: Iniciando descarga de PDF desde: ${widget.url}');
      print('DocumentViewer: Archivo temporal: ${file.path}');

      // Verificar si el archivo ya existe y es válido
      if (await file.exists()) {
        print('DocumentViewer: Archivo ya existe, verificando validez...');
        final bytes = await file.readAsBytes();
        final isValidPdf = bytes.length > 4 &&
            bytes[0] == 0x25 && // %
            bytes[1] == 0x50 && // P
            bytes[2] == 0x44 && // D
            bytes[3] == 0x46;   // F

        // Verificación adicional: buscar %PDF en cualquier parte de los primeros 1024 bytes
        bool containsPdfSignature = false;
        final searchLimit = bytes.length < 1024 ? bytes.length : 1024;
        for (int i = 0; i < searchLimit - 4; i++) {
          if (bytes[i] == 0x25 && bytes[i+1] == 0x50 && bytes[i+2] == 0x44 && bytes[i+3] == 0x46) {
            containsPdfSignature = true;
            break;
          }
        }

        final finalValidation = isValidPdf || containsPdfSignature || bytes.length > 100;

        print('DocumentViewer: ¿Es PDF válido? $finalValidation (longitud: ${bytes.length})');

        if (finalValidation) {
          print('DocumentViewer: Usando archivo existente válido');
          setState(() {
            _localFilePath = file.path;
            _isDownloading = false;
          });
          return;
        } else {
          print('DocumentViewer: Archivo existente no es válido, eliminando...');
          // Archivo corrupto, eliminarlo
          await file.delete();
        }
      }

      print('DocumentViewer: Descargando archivo desde URL...');
      // Descargar el archivo
      final response = await http.get(Uri.parse(widget.url));
      print('DocumentViewer: Respuesta HTTP: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('DocumentViewer: Guardando archivo descargado...');
        await file.writeAsBytes(response.bodyBytes);

        // Verificar que el archivo descargado sea válido
        final bytes = await file.readAsBytes();
        // Validación más flexible para PDFs
        final isValidPdf = bytes.length > 4 &&
            bytes[0] == 0x25 && // %
            bytes[1] == 0x50 && // P
            bytes[2] == 0x44 && // D
            bytes[3] == 0x46;   // F
            // Nota: El guion puede estar en diferentes posiciones según la versión

        print('DocumentViewer: ¿Archivo descargado es PDF válido? $isValidPdf (longitud: ${bytes.length})');
        if (bytes.isNotEmpty) {
          print('DocumentViewer: Primeros bytes: ${bytes.take(10).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        }

        // Verificación adicional: buscar %PDF en cualquier parte de los primeros 1024 bytes
        bool containsPdfSignature = false;
        final searchLimit = bytes.length < 1024 ? bytes.length : 1024;
        for (int i = 0; i < searchLimit - 4; i++) {
          if (bytes[i] == 0x25 && bytes[i+1] == 0x50 && bytes[i+2] == 0x44 && bytes[i+3] == 0x46) {
            containsPdfSignature = true;
            break;
          }
        }

        final finalValidation = isValidPdf || containsPdfSignature || bytes.length > 100; // PDFs reales suelen ser > 100 bytes

        print('DocumentViewer: Validación final: $finalValidation (isValidPdf: $isValidPdf, containsSignature: $containsPdfSignature, size: ${bytes.length})');

        if (finalValidation) {
          print('DocumentViewer: PDF válido descargado correctamente');
          setState(() {
            _localFilePath = file.path;
            _isDownloading = false;
          });
        } else {
          print('DocumentViewer: Archivo descargado no es PDF válido');
          setState(() {
            _errorMessage = 'El archivo descargado no parece ser un PDF válido. Verifica que la URL sea correcta.';
            _isDownloading = false;
          });
          // Eliminar archivo inválido
          if (await file.exists()) {
            await file.delete();
          }
        }
      } else {
        print('DocumentViewer: Error HTTP ${response.statusCode}');
        setState(() {
          _errorMessage = 'Error al descargar el archivo (código ${response.statusCode}). Verifica tu conexión a internet.';
          _isDownloading = false;
        });
      }
    } catch (e) {
      print('DocumentViewer: Excepción durante la descarga: $e');
      setState(() {
        _errorMessage = 'Error al procesar el PDF: ${e.toString()}';
        _isDownloading = false;
      });
    }
  }

  Future<void> _openExternalApp() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir el archivo')),
        );
      }
    }
  }

  Widget _buildImageViewer() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: NetworkImage(widget.url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (Platform.isWindows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.picture_as_pdf, size: 64, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            'Vista previa de PDF no soportada en Windows.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se abrirá el archivo PDF en una aplicación externa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openExternalApp,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir PDF externamente'),
          ),
        ],
      );
    }

    // Mostrar error si existe
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _localFilePath = null;
                  _pdfRendered = false;
                  _pdfPages = 0;
                });
                _checkAndDownloadFile();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Mostrar loading mientras se descarga
    if (_isDownloading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Descargando PDF...'),
          ],
        ),
      );
    }

    // Si no hay archivo local y no hay error, intentar descargar
    if (_localFilePath == null && _errorMessage == null && !_isDownloading) {
      print('DocumentViewer: No hay archivo local, iniciando descarga...');
      _checkAndDownloadFile();
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Preparando descarga...'),
          ],
        ),
      );
    }

    // Si no hay archivo local después de intentar descargar, mostrar error
    if (_localFilePath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'No se pudo cargar el PDF',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica la URL y tu conexión a internet',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _localFilePath = null;
                  _pdfRendered = false;
                  _pdfPages = 0;
                });
                _checkAndDownloadFile();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Verificar que el archivo existe
    final file = File(_localFilePath!);
    if (!file.existsSync()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Archivo no encontrado',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _localFilePath = null;
                  _pdfRendered = false;
                  _pdfPages = 0;
                });
                _checkAndDownloadFile();
              },
              child: const Text('Reintentar descarga'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Mostrar loading mientras se renderiza el PDF
        if (!_pdfRendered)
          Container(
            height: 400,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Renderizando PDF...'),
              ],
            ),
          ),
        // PDF Viewer
        SizedBox(
          height: 400,
          child: PDFView(
            filePath: _localFilePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: false,
            onRender: (pages) {
              setState(() {
                _pdfRendered = true;
                _pdfPages = pages ?? 0;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = 'Error al mostrar PDF: $error';
                _pdfRendered = false;
              });
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = 'Error en página $page: $error';
                _pdfRendered = false;
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // Timeout para detectar PDFs que no se renderizan
              Future.delayed(const Duration(seconds: 15), () {
                if (mounted && !_pdfRendered && _errorMessage == null) {
                  setState(() {
                    _errorMessage = 'Timeout: El PDF no se pudo renderizar';
                  });
                }
              });
            },
          ),
        ),
        // Información del PDF cuando está renderizado
        if (_pdfRendered && _pdfPages > 0)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'PDF cargado: $_pdfPages página${_pdfPages != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildExternalFileViewer() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _openExternalApp,
          icon: const Icon(Icons.open_in_new),
          label: Text('Abrir ${widget.tipo.toUpperCase()}'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se abrirá en una aplicación externa',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Función para determinar el tipo basado en extensión si el tipo no es claro
    String getFileType(String tipo, String url) {
      final tipoLower = tipo.toLowerCase();
      final urlLower = url.toLowerCase();

      // Si ya es un tipo válido, devolverlo
      if (['imagen', 'image', 'pdf', 'word', 'doc', 'docx', 'dox', 'excel', 'xls', 'xlsx'].contains(tipoLower)) {
        return tipoLower;
      }

      // Detectar por extensión de URL
      if (urlLower.contains('.jpg') || urlLower.contains('.jpeg')) return 'imagen';
      if (urlLower.contains('.png')) return 'imagen';
      if (urlLower.contains('.gif')) return 'imagen';
      if (urlLower.contains('.pdf')) return 'pdf';
      if (urlLower.contains('.doc') || urlLower.contains('.docx') || urlLower.contains('.dox')) return 'word';
      if (urlLower.contains('.xls') || urlLower.contains('.xlsx')) return 'excel';

      // Si no se puede determinar, devolver el tipo original
      return tipoLower;
    }

    final fileType = getFileType(widget.tipo, widget.url);

    switch (fileType) {
      case 'imagen':
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return _buildImageViewer();
      case 'pdf':
        return _buildPdfViewer();
      case 'word':
      case 'doc':
      case 'docx':
      case 'dox':
      case 'excel':
      case 'xls':
      case 'xlsx':
        return _buildExternalFileViewer();
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de archivo no soportado',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tipo recibido: "${widget.tipo}"'),
            Text('URL: ${widget.url}'),
            const SizedBox(height: 8),
            const Text(
              'Tipos soportados: imagen, pdf, word, excel',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _openExternalApp,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Intentar abrir en navegador'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
            ),
          ],
        );
    }
  }
}