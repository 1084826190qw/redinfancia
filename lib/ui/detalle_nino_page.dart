import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lista_ninos_page.dart';

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
  String nombre = '';
  String biografia = '';
  String categoria = 'Sin categoría';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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
        biografia = (ninoData['biografia'] ?? '') as String;
        categoria = (ninoData['categoria'] ?? 'Sin categoría') as String;

        documentos = List<Map<String, dynamic>>.from(
          docData as List<dynamic>? ?? [],
        );
        isLoading = false;
      });
    } catch (e) {
      print("❌ ERROR al cargar datos: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del niño')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  Text(
                    'ID: ${widget.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Nombre: $nombre'),
                  const SizedBox(height: 8),
                  Text('Biografía: $biografia'),
                  const SizedBox(height: 8),
                  Text('Categoría: $categoria'),
                  const SizedBox(height: 16),
                  const Text(
                    'Documentos registrados:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (documentos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No hay documentos registrados para este niño.',
                      ),
                    )
                  else
                    ...documentos.map((documento) {
                      final tipo = documento['tipo'] as String? ?? '';
                      final url = documento['url'] as String?;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                documento['nombre_archivo'] ?? 'Documento',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Tipo: ${tipo.isEmpty ? '-' : tipo}'),
                              Text(
                                'Categoría: ${documento['categoria'] ?? '-'}',
                              ),
                              Text('Url: ${url ?? '-'}'),
                              if (tipo == 'imagen' && url != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Image.network(
                                    url,
                                    height: 115,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Text(
                                      'No se pudo mostrar la imagen',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ListaNinosPage()),
                    ),
                    child: const Text('Ir a lista de niños'),
                  ),
                ],
              ),
      ),
    );
  }
}
