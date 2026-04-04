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
  String genero = '';
  String fechaNacimiento = '';
  String categoria = 'Sin categoría';
  String fotoUrl = '';

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
        genero = (ninoData['genero'] ?? '') as String;
        fechaNacimiento = (ninoData['fecha_nacimiento'] ?? '') as String;
        categoria = (ninoData['categoria'] ?? 'Sin categoría') as String;
        fotoUrl = (ninoData['foto_url'] ?? '') as String;

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
                              label: 'ID',
                              value: widget.id,
                              icon: Icons.tag_outlined,
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            _InfoRow(
                              label: 'Categoría',
                              value: categoria,
                              icon: Icons.folder_outlined,
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
                            else
                              ...documentos.map((documento) {
                                final tipo = documento['tipo'] as String? ?? '';
                                final url = documento['url'] as String?;
                                final nombreArchivo =
                                    documento['nombre_archivo'] as String? ??
                                    'Documento';

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
                                                  'Tipo: ${tipo.isEmpty ? 'Desconocido' : tipo} • Categoría: ${documento['categoria'] ?? 'Sin categoría'}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF7A7890),
                                                  ),
                                                ),
                                              ],
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
