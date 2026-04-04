import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalle_nino_page.dart';
import 'home_page.dart';

class ListaNinosPage extends StatefulWidget {
  const ListaNinosPage({super.key});

  @override
  State<ListaNinosPage> createState() => _ListaNinosPageState();
}

class _ListaNinosPageState extends State<ListaNinosPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> listaNinos = [];
  List<Map<String, dynamic>> filteredNinos = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarNinos();
  }

  Future<void> cargarNinos() async {
    final data = await supabase.from('ninos').select();

    setState(() {
      listaNinos = List<Map<String, dynamic>>.from(data);
      _filterNinos(_searchController.text);
    });
  }

  void _filterNinos(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredNinos = listaNinos;
      } else {
        filteredNinos = listaNinos
            .where(
              (nino) => (nino['nombre'] ?? '').toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  // ELIMINAR NIÑO
  Future<void> eliminarNino(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar niño?'),
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

    if (confirmar == true) {
      await supabase.from('ninos').delete().eq('id', id);
      await cargarNinos();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Todos los niños'),
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5DDFB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F8C93B5),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar niño...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF8F88D9)),
                      border: InputBorder.none,
                    ),
                    onChanged: _filterNinos,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      filteredNinos.isEmpty && _searchController.text.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron niños',
                            style: TextStyle(
                              color: Color(0xFF7A7890),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : filteredNinos.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay niños registrados',
                            style: TextStyle(
                              color: Color(0xFF7A7890),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredNinos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final nino = filteredNinos[index];

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFE9E6F8),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F8C93B5),
                                    blurRadius: 14,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: const Color(0xFFEAF7FF),
                                  backgroundImage: nino['foto'] != null
                                      ? NetworkImage(nino['foto'])
                                            as ImageProvider
                                      : null,
                                  child: nino['foto'] == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Color(0xFF8F88D9),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  nino['nombre'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3F3D56),
                                  ),
                                ),
                                subtitle: Text(
                                  nino['genero'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF7A7890),
                                  ),
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DetalleNinoPage(id: nino['id']),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color(0xFFEA5560),
                                  ),
                                  onPressed: () => eliminarNino(nino['id']),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
