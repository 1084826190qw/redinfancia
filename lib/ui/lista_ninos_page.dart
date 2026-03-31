import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaNinosPage extends StatefulWidget {
  const ListaNinosPage({super.key});

  @override
  State<ListaNinosPage> createState() => _ListaNinosPageState();
}

class _ListaNinosPageState extends State<ListaNinosPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> listaNinos = [];

  @override
  void initState() {
    super.initState();
    cargarNinos();
  }

  Future<void> cargarNinos() async {
    final data = await supabase.from('ninos').select();

    setState(() {
      listaNinos = List<Map<String, dynamic>>.from(data);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos los niños')),
      body: listaNinos.isEmpty
          ? const Center(child: Text('No hay niños registrados'))
          : ListView.builder(
              itemCount: listaNinos.length,
              itemBuilder: (context, index) {
                final nino = listaNinos[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: nino['foto'] != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(nino['foto']),
                          )
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(nino['nombre'] ?? ''),
                    subtitle: Text(nino['biografia'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => eliminarNino(nino['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}