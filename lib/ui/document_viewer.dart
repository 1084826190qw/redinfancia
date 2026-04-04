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
  bool _isDownloading = false;

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
      _downloadPdf();
    }
  }

  // 📥 DESCARGAR PDF
  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp.pdf');

      final res = await http.get(Uri.parse(widget.url));

      await file.writeAsBytes(res.bodyBytes);

      setState(() {
        _localFilePath = file.path;
        _isDownloading = false;
      });
    } catch (e) {
      setState(() => _isDownloading = false);
    }
  }

  // 🌐 ABRIR EN NAVEGADOR
  Future<void> abrirEnNavegador() async {
    final uri = Uri.parse(widget.url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir")),
      );
    }
  }

  // 🖼 IMAGEN
  Widget imagen() {
    return Image.network(widget.url);
  }

  // 📄 PDF
  Widget pdf() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: abrirEnNavegador,
          icon: const Icon(Icons.open_in_browser),
          label: const Text("Abrir PDF en navegador"),
        ),
        const SizedBox(height: 10),
        if (_isDownloading)
          const CircularProgressIndicator(),
        if (_localFilePath != null)
          SizedBox(
            height: 400,
            child: PDFView(filePath: _localFilePath),
          )
      ],
    );
  }

  // 📄 WORD / EXCEL
  Widget externo() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: abrirEnNavegador,
          icon: const Icon(Icons.open_in_browser),
          label: const Text("Abrir archivo"),
        ),
        const SizedBox(height: 10),
        const Text("Se abrirá en el navegador del celular"),
      ],
    );
  }

  // 📄 TEXTO
  Widget texto() {
    return FutureBuilder(
      future: http.get(Uri.parse(widget.url)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final data = snapshot.data as http.Response;

        return SizedBox(
          height: 400,
          child: SingleChildScrollView(
            child: Text(data.body),
          ),
        );
      },
    );
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
        ElevatedButton(
          onPressed: abrirEnNavegador,
          child: const Text("Abrir en navegador"),
        )
      ],
    );
  }
}