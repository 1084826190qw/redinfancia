import 'dart:convert';

/// Script de prueba para validar la funcionalidad de filtro por categorías
/// Ejecutar con: dart test_filtro_categorias.dart

void main() {
  print('🧪 Iniciando pruebas de filtro por categorías...\n');

  // Simular documentos de ejemplo con diferentes categorías
  final documentos = [
    {
      'id': '1',
      'nombre_archivo': 'certificado_nacimiento.pdf',
      'tipo': 'archivo',
      'categoria': 'documentos_personales',
      'contenido_texto': 'Certificado de nacimiento de Juan Carlos'
    },
    {
      'id': '2',
      'nombre_archivo': 'cartilla_vacunacion.pdf',
      'tipo': 'archivo',
      'categoria': 'salud_y_nutricion',
      'contenido_texto': 'Registro de vacunas aplicadas'
    },
    {
      'id': '3',
      'nombre_archivo': 'reporte_progreso.pdf',
      'tipo': 'archivo',
      'categoria': 'seguimiento',
      'contenido_texto': 'Evaluación del desarrollo del niño'
    },
    {
      'id': '4',
      'nombre_archivo': 'informacion_familiar.pdf',
      'tipo': 'archivo',
      'categoria': 'familia_comunidad_y_redes',
      'contenido_texto': 'Datos de contacto de la familia'
    },
    {
      'id': '5',
      'nombre_archivo': 'material_educativo.pdf',
      'tipo': 'archivo',
      'categoria': 'componente_pedagogico',
      'contenido_texto': 'Actividades de aprendizaje'
    },
    {
      'id': '6',
      'nombre_archivo': 'documento_varios.pdf',
      'tipo': 'archivo',
      'categoria': 'otros',
      'contenido_texto': 'Información complementaria'
    },
  ];

  print('📄 Documentos de ejemplo (${documentos.length}):');
  for (var doc in documentos) {
    print('  • ${doc['nombre_archivo']} → ${doc['categoria']}');
  }
  print('');

  // Categorías disponibles
  final categorias = [
    'Todas las categorías',
    'documentos_personales',
    'seguimiento',
    'salud_y_nutricion',
    'familia_comunidad_y_redes',
    'componente_pedagogico',
    'otros',
  ];

  print('📁 Pruebas de filtrado por categorías:');

  // Prueba 1: Sin filtro (todas las categorías)
  final todas = filtrarPorCategoria(documentos, categorias[0]);
  print('  ✅ Todas las categorías: ${todas.length} documentos');

  // Prueba 2: Filtrar por cada categoría
  for (var i = 1; i < categorias.length; i++) {
    final categoria = categorias[i];
    final filtrados = filtrarPorCategoria(documentos, categoria);
    final nombreFormateado = formatearNombreCategoria(categoria);
    print('  ✅ $nombreFormateado: ${filtrados.length} documento(s)');

    // Verificar que los documentos filtrados tienen la categoría correcta
    for (var doc in filtrados) {
      if (doc['categoria'] != categoria) {
        print('    ❌ ERROR: Documento ${doc['nombre_archivo']} no pertenece a $categoria');
      }
    }
  }
  print('');

  // Prueba 3: Filtrado combinado (categoría + búsqueda)
  print('🔍 Pruebas de búsqueda combinada:');

  final pruebasBusqueda = [
    {'categoria': 'salud_y_nutricion', 'busqueda': 'vacuna', 'esperado': 1},
    {'categoria': 'documentos_personales', 'busqueda': 'nacimiento', 'esperado': 1},
    {'categoria': 'seguimiento', 'busqueda': 'desarrollo', 'esperado': 1},
    {'categoria': 'Todas las categorías', 'busqueda': 'niño', 'esperado': 3},
  ];

  for (var prueba in pruebasBusqueda) {
    final categoria = prueba['categoria'] as String;
    final busqueda = prueba['busqueda'] as String;
    final esperado = prueba['esperado'] as int;

    final filtrados = filtrarPorCategoriaYBusqueda(documentos, categoria, busqueda);
    final nombreCat = formatearNombreCategoria(categoria);

    final resultado = filtrados.length == esperado ? '✅' : '❌';
    print('  $resultado $nombreCat + "$busqueda": ${filtrados.length} (esperado: $esperado)');

    if (filtrados.length != esperado) {
      print('    Detalles: ${filtrados.map((d) => d['nombre_archivo']).join(', ')}');
    }
  }
  print('');

  // Estadísticas
  print('📊 Estadísticas del sistema:');
  final totalDocumentos = documentos.length;
  final categoriasUsadas = documentos.map((d) => d['categoria']).toSet().length;

  print('  • Total documentos: $totalDocumentos');
  print('  • Categorías disponibles: ${categorias.length - 1}'); // Excluyendo "Todas"
  print('  • Categorías con documentos: $categoriasUsadas');

  // Distribución por categoría
  print('  • Distribución:');
  final distribucion = <String, int>{};
  for (var doc in documentos) {
    final cat = doc['categoria'] as String;
    distribucion[cat] = (distribucion[cat] ?? 0) + 1;
  }

  distribucion.forEach((cat, count) {
    final nombre = formatearNombreCategoria(cat);
    print('    - $nombre: $count documento(s)');
  });

  print('\n✅ Pruebas completadas exitosamente!');
}

/// Simula la función de filtrado por categoría
List<Map<String, dynamic>> filtrarPorCategoria(List<Map<String, dynamic>> documentos, String categoria) {
  if (categoria == 'Todas las categorías') {
    return documentos;
  }
  return documentos.where((doc) => doc['categoria'] == categoria).toList();
}

/// Simula la función de filtrado combinado (categoría + búsqueda)
List<Map<String, dynamic>> filtrarPorCategoriaYBusqueda(
  List<Map<String, dynamic>> documentos,
  String categoria,
  String busqueda
) {
  // Primero filtrar por categoría
  var filtrados = filtrarPorCategoria(documentos, categoria);

  // Luego buscar en el texto
  if (busqueda.isNotEmpty) {
    final busquedaLower = busqueda.toLowerCase();
    filtrados = filtrados.where((doc) {
      final contenido = (doc['contenido_texto'] as String? ?? '').toLowerCase();
      final nombre = (doc['nombre_archivo'] as String? ?? '').toLowerCase();
      final tipo = (doc['tipo'] as String? ?? '').toLowerCase();
      final cat = (doc['categoria'] as String? ?? '').toLowerCase();

      return contenido.contains(busquedaLower) ||
             nombre.contains(busquedaLower) ||
             tipo.contains(busquedaLower) ||
             cat.contains(busquedaLower);
    }).toList();
  }

  return filtrados;
}

/// Simula la función _formatearNombreCategoria del código real
String formatearNombreCategoria(String categoria) {
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