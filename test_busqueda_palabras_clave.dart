import 'dart:convert';

/// Script de prueba para validar la funcionalidad de búsqueda por palabras clave
/// Ejecutar con: dart test_busqueda_palabras_clave.dart

void main() {
  print('🧪 Iniciando pruebas de búsqueda por palabras clave...\n');

  // Simular texto OCR de ejemplo
  final textoOCR = '''
    CERTIFICADO DE NACIMIENTO
    El niño Juan Carlos Martínez López nació el 15 de marzo de 2015
    en el Hospital General de Ciudad de México. Sus padres son María
    González Rodríguez y Pedro Martínez Sánchez. El niño presenta
    buen estado de salud general, peso al nacer 3.2 kg, talla 50 cm.
    Vacunas aplicadas: BCG, Hepatitis B primera dosis.
    Observaciones: Niño sano, sin complicaciones en el parto.
    Fecha de emisión: 20 de marzo de 2015.
    Firma del médico pediatra: Dr. Ana María Torres.
  ''';

  print('📄 Texto OCR de ejemplo:');
  print(textoOCR.substring(0, 200) + '...\n');

  // Simular función de extracción de palabras clave
  final palabrasClave = extraerPalabrasClave(textoOCR);

  print('🔑 Palabras clave extraídas (${palabrasClave.length}):');
  for (var i = 0; i < palabrasClave.length && i < 10; i++) {
    final palabra = palabrasClave[i];
    print('  ${i + 1}. ${palabra['palabra']} (puntuación: ${palabra['puntuacion'].toStringAsFixed(2)})');
  }

  if (palabrasClave.length > 10) {
    print('  ... y ${palabrasClave.length - 10} más');
  }
  print('');

  // Pruebas de búsqueda
  final consultasPrueba = [
    'Juan Carlos',
    'vacunas',
    'hospital',
    'peso nacer',
    'médico pediatra'
  ];

  print('🔍 Pruebas de búsqueda:');
  for (final consulta in consultasPrueba) {
    final resultados = buscarPorPalabrasClave(consulta, textoOCR);
    print('  Consulta: "$consulta" → ${resultados ? '✅ Encontrado' : '❌ No encontrado'}');
  }
  print('');

  // Estadísticas
  final stats = calcularEstadisticas(textoOCR);
  print('📊 Estadísticas del texto:');
  print('  • Total palabras: ${stats['totalPalabras']}');
  print('  • Palabras únicas: ${stats['palabrasUnicas']}');
  print('  • Palabras clave: ${stats['palabrasClave']}');
  print('  • Términos compuestos: ${stats['terminosCompuestos']}');
  print('  • Stop words filtradas: ${stats['stopWordsFiltradas']}');

  print('\n✅ Pruebas completadas exitosamente!');
}

/// Simula la función _extraerPalabrasClave del código real
List<Map<String, dynamic>> extraerPalabrasClave(String texto) {
  // Stop words en español
  final stopWords = {
    'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es',
    'un', 'una', 'por', 'con', 'se', 'para', 'como', 'su', 'al', 'lo',
    'este', 'esta', 'estos', 'estas', 'nos', 'les', 'le', 'les', 'me',
    'te', 'nos', 'les', 'mi', 'tu', 'su', 'nuestro', 'vuestro', 'sus',
    'nuestra', 'vuestra', 'nuestros', 'vuestros', 'sus', 'sus', 'ha',
    'han', 'hay', 'he', 'hemos', 'habéis', 'han', 'había', 'habíamos',
    'habíais', 'habían', 'hube', 'hubiste', 'hubo', 'hubimos', 'hubisteis',
    'hubieron', 'habré', 'habrás', 'habrá', 'habremos', 'habréis', 'habrán'
  };

  // Limpiar texto
  String textoLimpio = texto.toLowerCase()
      .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Extraer palabras
  List<String> palabras = textoLimpio.split(' ')
      .where((palabra) => palabra.length > 2)
      .where((palabra) => !stopWords.contains(palabra))
      .where((palabra) => !RegExp(r'^\d+$').hasMatch(palabra))
      .toList();

  // Contar frecuencia
  Map<String, int> frecuencia = {};
  for (final palabra in palabras) {
    frecuencia[palabra] = (frecuencia[palabra] ?? 0) + 1;
  }

  // Extraer términos compuestos
  List<String> terminosCompuestos = extraerTerminosCompuestos(textoLimpio);

  // Calcular puntuaciones
  List<Map<String, dynamic>> palabrasClave = [];

  // Palabras individuales
  for (final entry in frecuencia.entries) {
    final palabra = entry.key;
    final freq = entry.value;
    final longitud = palabra.length;
    final puntuacion = freq * (longitud / 10.0).clamp(0.5, 2.0);

    palabrasClave.add({
      'palabra': palabra,
      'puntuacion': puntuacion,
      'frecuencia': freq,
      'tipo': 'individual'
    });
  }

  // Términos compuestos
  for (final termino in terminosCompuestos) {
    final puntuacion = 1.5 * (termino.length / 10.0).clamp(0.5, 2.0);
    palabrasClave.add({
      'palabra': termino,
      'puntuacion': puntuacion,
      'frecuencia': 1,
      'tipo': 'compuesto'
    });
  }

  // Ordenar por puntuación descendente
  palabrasClave.sort((a, b) => b['puntuacion'].compareTo(a['puntuacion']));

  // Limitar a top 20
  return palabrasClave.take(20).toList();
}

/// Simula la función _extraerTerminosCompuestos
List<String> extraerTerminosCompuestos(String texto) {
  List<String> terminos = [];

  // Buscar patrones comunes de términos compuestos
  final patrones = [
    RegExp(r'\b\w{4,}\s+\w{4,}\b'),  // Dos palabras de 4+ letras
    RegExp(r'\b\w{3,}\s+\w{3,}\s+\w{3,}\b'),  // Tres palabras
  ];

  for (final patron in patrones) {
    final matches = patron.allMatches(texto);
    for (final match in matches) {
      final termino = match.group(0)!;
      if (termino.length >= 6 && termino.length <= 30) {
        terminos.add(termino);
      }
    }
  }

  // Eliminar duplicados
  return terminos.toSet().toList();
}

/// Simula la función _buscarPorPalabrasClave
bool buscarPorPalabrasClave(String consulta, String texto) {
  final palabrasClave = extraerPalabrasClave(texto);
  final consultaMinuscula = consulta.toLowerCase();

  // Buscar coincidencia directa
  if (texto.toLowerCase().contains(consultaMinuscula)) {
    return true;
  }

  // Buscar en palabras clave
  for (final palabra in palabrasClave) {
    if (palabra['palabra'].toString().toLowerCase().contains(consultaMinuscula) ||
        consultaMinuscula.contains(palabra['palabra'].toString().toLowerCase())) {
      return true;
    }
  }

  return false;
}

/// Calcula estadísticas del texto
Map<String, int> calcularEstadisticas(String texto) {
  final palabras = texto.toLowerCase()
      .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .toList();

  final palabrasUnicas = palabras.toSet().length;
  final palabrasClave = extraerPalabrasClave(texto).length;
  final terminosCompuestos = extraerTerminosCompuestos(texto.toLowerCase()).length;

  final stopWords = {
    'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es',
    'un', 'una', 'por', 'con', 'se', 'para', 'como', 'su', 'al', 'lo'
  };

  final stopWordsFiltradas = palabras.where((p) => stopWords.contains(p)).length;

  return {
    'totalPalabras': palabras.length,
    'palabrasUnicas': palabrasUnicas,
    'palabrasClave': palabrasClave,
    'terminosCompuestos': terminosCompuestos,
    'stopWordsFiltradas': stopWordsFiltradas,
  };
}