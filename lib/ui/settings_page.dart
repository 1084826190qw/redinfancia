import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _editando = false;
  String? _userEmail;
  String? _fotoUrl;

  final _nombreController = TextEditingController();
  final _hogarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _hogarController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      _userEmail = user.email;

      final data = await supabase
          .from('usuarios')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _nombreController.text = data['nombre'] as String? ?? '';
        _hogarController.text = data['nombre_hogar'] as String? ?? '';
        _fotoUrl = data['foto_url'] as String?;
      }
    } catch (e) {
      print('Error cargando datos de usuario: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subirFoto() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (pickedFile == null) return;

      setState(() => _isSaving = true);

      final user = supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await pickedFile.readAsBytes();
      final tiempo = DateTime.now().millisecondsSinceEpoch;
      final ruta = 'perfiles/${user.id}/avatar_$tiempo.jpg';

      try {
        await supabase.storage.from('documentos').uploadBinary(ruta, bytes);
      } catch (e) {
        print('Error Storage: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir la foto al servidor: $e')),
          );
        }
        return;
      }

      final url = supabase.storage.from('documentos').getPublicUrl(ruta);

      try {
        await supabase
            .from('usuarios')
            .update({'foto_url': url}).eq('id', user.id);
      } catch (e) {
        print('Error DB: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('La foto se subió pero no se pudo guardar la referencia: $e')),
          );
        }
        return;
      }

      setState(() => _fotoUrl = url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      print('Error al seleccionar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _guardarCambios() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await supabase.from('usuarios').update({
        'nombre': _nombreController.text.trim(),
        'nombre_hogar': _hogarController.text.trim(),
      }).eq('id', user.id);

      setState(() => _editando = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos actualizados correctamente')),
        );
      }
    } catch (e) {
      print('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
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
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E4A67)),
          onPressed: () => Navigator.pop(context),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFB39DDB)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // ── Foto de perfil ──
                      Center(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _subirFoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFE5DDFB),
                                      width: 3),
                                  image: _fotoUrl != null &&
                                          _fotoUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(_fotoUrl!),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: _fotoUrl == null ||
                                        _fotoUrl!.isEmpty
                                    ? const Icon(Icons.person,
                                        color: Color(0xFFB39DDB), size: 60)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFB39DDB),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Información del usuario ──
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
                              Icon(Icons.person_outline,
                                  color: Color(0xFFB39DDB), size: 28),
                              SizedBox(width: 12),
                              Text('Mis datos',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4E4A67))),
                            ]),
                            const SizedBox(height: 20),

                            _DataField(
                              icon: Icons.email_outlined,
                              label: 'Correo',
                              value: _userEmail ?? '',
                            ),
                            const SizedBox(height: 12),
                            _DataField(
                              icon: Icons.badge_outlined,
                              label: 'Nombre',
                              value: _nombreController.text.isEmpty
                                  ? 'Sin nombre'
                                  : _nombreController.text,
                            ),
                            const SizedBox(height: 12),
                            _DataField(
                              icon: Icons.home_rounded,
                              label: 'Hogar comunitario',
                              value: _hogarController.text.isEmpty
                                  ? 'Sin hogar'
                                  : _hogarController.text,
                            ),
                            const SizedBox(height: 20),

                            if (_editando) ...[
                              const Divider(color: Color(0xFFE5DDFB)),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _nombreController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  labelText: 'Nombre',
                                  prefixIcon:
                                      const Icon(Icons.badge_outlined,
                                          color: Color(0xFF8F88D9)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F5FF),
                                  contentPadding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 18, vertical: 18),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5DDFB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFB39DDB),
                                        width: 1.4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _hogarController,
                                enabled: !_isSaving,
                                decoration: InputDecoration(
                                  labelText: 'Hogar comunitario',
                                  prefixIcon: const Icon(Icons.home_rounded,
                                      color: Color(0xFF8F88D9)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F5FF),
                                  contentPadding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 18, vertical: 18),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE5DDFB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFB39DDB),
                                        width: 1.4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _editando = false;
                                            _cargarDatos();
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF7A7890),
                                          side: const BorderSide(
                                              color: Color(0xFFE5DDFB)),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: const Text('Cancelar',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _isSaving
                                            ? null
                                            : _guardarCambios,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFB39DDB),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                ),
                                              )
                                            : const Text('Guardar',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      setState(() => _editando = true),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20),
                                  label: const Text('Editar',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFB39DDB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Cerrar sesión ──
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _confirmarCerrarSesion,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      color:
                                          Colors.red.withOpacity(0.15),
                                    ),
                                    child: const Icon(Icons.logout,
                                        color: Colors.red, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Cerrar sesión',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: Colors.red)),
                                        SizedBox(height: 4),
                                        Text(
                                            'Desconectarte de la aplicación',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    Color(0xFF7A7890))),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.red, size: 24),
                                ],
                              ),
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

class _DataField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DDFB)),
      ),
      child: Row(
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
                        fontSize: 13,
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
      ),
    );
  }
}
