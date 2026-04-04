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
      appBar: AppBar(
        title: const Text('Todos los niños'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar niño...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterNinos,
            ),
          ),
          Expanded(
            child: filteredNinos.isEmpty && _searchController.text.isNotEmpty
                ? const Center(child: Text('No se encontraron niños'))
                : filteredNinos.isEmpty
                ? const Center(child: Text('No hay niños registrados'))
                : ListView.builder(
                    itemCount: filteredNinos.length,
                    itemBuilder: (context, index) {
                      final nino = filteredNinos[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: nino['foto'] != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(nino['foto']),
                                )
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(nino['nombre'] ?? ''),
                          subtitle: Text(nino['genero'] ?? ''),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetalleNinoPage(id: nino['id']),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => eliminarNino(nino['id']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
