import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalle_nino_page.dart';

class BusquedaAvanzadaPage extends StatefulWidget {
  const BusquedaAvanzadaPage({super.key});

  @override
  State<BusquedaAvanzadaPage> createState() => _BusquedaAvanzadaPageState();
}

class _BusquedaAvanzadaPageState extends State<BusquedaAvanzadaPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> resultados = [];
  bool isLoading = false;
  String? errorMessage;
  List<String> palabrasClaveGlobales = []; // Palabras clave extraídas de todos los documentos
  Map<String, List<String>> palabrasClavePorDocumento = {}; // Palabras clave por documento

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Función para extraer palabras clave del texto OCR
  List<String> _extraerPalabrasClave(String texto) {
    if (texto.isEmpty) return [];

    // Convertir a minúsculas y limpiar
    String textoLimpio = texto.toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ') // Remover puntuación pero mantener acentos
        .replaceAll(RegExp(r'\s+'), ' ') // Normalizar espacios
        .trim();

    // Palabras comunes a excluir (stop words en español)
    final stopWords = {
      'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es', 'un', 'una', 'por', 'con',
      'se', 'para', 'como', 'su', 'al', 'lo', 'le', 'me', 'mi', 'tu', 'te', 'si', 'no', 'pero',
      'o', 'este', 'esta', 'estos', 'estas', 'son', 'fue', 'era', 'eran', 'ser', 'estar', 'haber',
      'tener', 'hacer', 'ir', 'ver', 'dar', 'saber', 'querer', 'llegar', 'pasar', 'deber', 'poner',
      'parecer', 'quedar', 'creer', 'hablar', 'llevar', 'dejar', 'seguir', 'encontrar', 'llamar',
      'venir', 'pensar', 'salir', 'volver', 'tomar', 'conocer', 'vivir', 'sentir', 'tratar', 'mirar',
      'contar', 'empezar', 'esperar', 'buscar', 'existir', 'entrar', 'trabajar', 'escribir', 'perder',
      'producir', 'ocurrir', 'entender', 'pedir', 'recibir', 'recordar', 'terminar', 'permitir',
      'aparecer', 'conseguir', 'comenzar', 'servir', 'sacar', 'necesitar', 'mantener', 'resultar',
      'leer', 'caer', 'cambiar', 'presentar', 'crear', 'abrir', 'considerar', 'oír', 'acabar',
      'convertir', 'ganar', 'formar', 'traer', 'partir', 'morir', 'aceptar', 'realizar', 'suponer',
      'comprender', 'lograr', 'explicar', 'preguntar', 'tocar', 'reconocer', 'estudiar', 'alcanzar',
      'nacer', 'dirigir', 'correr', 'utilizar', 'pagar', 'ayudar', 'gustar', 'jugar', 'escuchar',
      'cumplir', 'ofrecer', 'descubrir', 'levantar', 'acercar', 'separar', 'morar', 'viajar'
    };

    // Dividir en palabras y filtrar
    List<String> palabras = textoLimpio.split(' ')
        .where((palabra) => palabra.length > 2) // Mínimo 3 caracteres
        .where((palabra) => !stopWords.contains(palabra)) // Excluir stop words
        .where((palabra) => !RegExp(r'^\d+$').hasMatch(palabra)) // Excluir números puros
        .toList();

    // Contar frecuencia de palabras
    Map<String, int> frecuencia = {};
    for (var palabra in palabras) {
      frecuencia[palabra] = (frecuencia[palabra] ?? 0) + 1;
    }

    // Extraer términos compuestos (2-3 palabras) que aparecen juntos
    List<String> terminosCompuestos = _extraerTerminosCompuestos(textoLimpio);

    // Combinar palabras individuales y compuestas, ordenar por frecuencia
    List<String> todasPalabras = [...frecuencia.keys, ...terminosCompuestos];

    // Puntuar palabras clave (frecuencia + longitud + si es término compuesto)
    List<MapEntry<String, double>> puntuadas = todasPalabras.map((palabra) {
      double puntuacion = (frecuencia[palabra] ?? 1).toDouble(); // Frecuencia base
      puntuacion *= (palabra.length / 10.0).clamp(0.5, 2.0); // Bonus por longitud
      if (palabra.contains(' ')) puntuacion *= 1.5; // Bonus por ser compuesto
      return MapEntry(palabra, puntuacion);
    }).toList();

    // Ordenar por puntuación y tomar las mejores
    puntuadas.sort((a, b) => b.value.compareTo(a.value));
    return puntuadas.take(10).map((e) => e.key).toList(); // Top 10 palabras clave
  }

  // Función para extraer términos compuestos (frases de 2-3 palabras)
  List<String> _extraerTerminosCompuestos(String texto) {
    List<String> terminos = [];
    List<String> palabras = texto.split(' ')
        .where((p) => p.length > 2)
        .where((p) => !RegExp(r'^\d+$').hasMatch(p))
        .toList();

    // Buscar bigramas (2 palabras)
    for (int i = 0; i < palabras.length - 1; i++) {
      String bigrama = '${palabras[i]} ${palabras[i + 1]}';
      if (bigrama.length > 6 && bigrama.length < 30) { // Longitud razonable
        terminos.add(bigrama);
      }
    }

    // Buscar trigramas (3 palabras) - menos comunes pero más específicos
    for (int i = 0; i < palabras.length - 2; i++) {
      String trigrama = '${palabras[i]} ${palabras[i + 1]} ${palabras[i + 2]}';
      if (trigrama.length > 10 && trigrama.length < 40) {
        terminos.add(trigrama);
      }
    }

    return terminos;
  }

  // Función para buscar por palabras clave
  Future<void> _buscarPorPalabrasClave(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        resultados = [];
        errorMessage = null;
        palabrasClaveGlobales = [];
        palabrasClavePorDocumento.clear();
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Buscar documentos que contengan las palabras clave
      final response = await supabase
          .from('ninos')
          .select('''
            *,
            documentos!inner(
              id,
              tipo,
              nombre_archivo,
              contenido_texto,
              categoria,
              created_at
            )
          ''')
          .filter('documentos.contenido_texto', 'ilike', '%${query.trim()}%');

      // Procesar resultados y extraer palabras clave
      final Map<String, Map<String, dynamic>> ninosUnicos = {};
      final Set<String> todasPalabrasClave = {};

      for (final nino in response) {
        final ninoId = nino['id'];
        if (!ninosUnicos.containsKey(ninoId)) {
          ninosUnicos[ninoId] = {
            ...nino,
            'documentos_coincidentes': [],
            'palabras_clave_relevantes': <String>[],
          };
        }

        // Procesar documentos del niño
        final documentos = nino['documentos'] as List<dynamic>;
        for (final doc in documentos) {
          if (_documentoCoincideConPalabrasClave(doc, query)) {
            ninosUnicos[ninoId]!['documentos_coincidentes'].add(doc);

            // Extraer palabras clave del documento
            final palabrasClave = _extraerPalabrasClave(doc['contenido_texto'] ?? '');
            palabrasClavePorDocumento[doc['id']] = palabrasClave;
            todasPalabrasClave.addAll(palabrasClave);

            // Agregar palabras clave relevantes al niño
            final palabrasRelevantes = ninosUnicos[ninoId]!['palabras_clave_relevantes'] as List<String>;
            palabrasRelevantes.addAll(palabrasClave.where((pc) =>
                pc.toLowerCase().contains(query.toLowerCase()) ||
                query.toLowerCase().contains(pc.toLowerCase())
            ));
          }
        }

        // Remover duplicados y limitar palabras clave por niño
        final palabrasRelevantes = ninosUnicos[ninoId]!['palabras_clave_relevantes'] as List<String>;
        ninosUnicos[ninoId]!['palabras_clave_relevantes'] = palabrasRelevantes.toSet().toList().take(5).toList();
      }

      setState(() {
        resultados = ninosUnicos.values.toList();
        palabrasClaveGlobales = todasPalabrasClave.toList()..sort();
        isLoading = false;
      });

      print('✅ Búsqueda por palabras clave completada: ${resultados.length} niños encontrados');
      print('📝 Palabras clave extraídas: ${palabrasClaveGlobales.length}');

    } catch (e) {
      print('❌ Error en búsqueda por palabras clave: $e');

      // Fallback a búsqueda básica
      try {
        await _buscarEnDocumentosBasico(query);
      } catch (fallbackError) {
        setState(() {
          errorMessage = 'Error en búsqueda: ${e.toString()}';
          isLoading = false;
          resultados = [];
        });
      }
    }
  }

  // Función para verificar si un documento coincide con palabras clave
  bool _documentoCoincideConPalabrasClave(Map<String, dynamic> documento, String query) {
    final contenido = documento['contenido_texto'] as String? ?? '';
    final palabrasClaveDocumento = _extraerPalabrasClave(contenido);

    // Verificar si alguna palabra clave del documento coincide con la búsqueda
    final queryLower = query.toLowerCase();
    return palabrasClaveDocumento.any((palabraClave) =>
        palabraClave.toLowerCase().contains(queryLower) ||
        queryLower.contains(palabraClave.toLowerCase())
    ) || contenido.toLowerCase().contains(queryLower);
  }

  Future<void> _buscarEnDocumentosAvanzada(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        resultados = [];
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Versión optimizada usando full-text search si está disponible
      // Si no tienes full-text search configurado, usa la versión básica

      // VERSIÓN CON FULL-TEXT SEARCH (Recomendada - más rápida)
      final queryVector = query.trim().split(' ').where((word) => word.isNotEmpty).join(' & ');

      final response = await supabase.rpc('buscar_documentos_fts', params: {
        'query_text': query.trim(),
        'limit_results': 50,
      });

      // Si no tienes la función RPC, usa esta consulta directa:
      /*
      final response = await supabase
          .from('ninos')
          .select('''
            *,
            documentos!inner(
              id,
              tipo,
              nombre_archivo,
              contenido_texto,
              categoria,
              created_at
            )
          ''')
          .filter('documentos.contenido_texto', 'ilike', '%${query.trim()}%')
          .limit(50);
      */

      // Procesar resultados para evitar duplicados y agregar metadatos
      final Map<String, Map<String, dynamic>> ninosUnicos = {};

      for (final item in response) {
        final nino = item['nino'] ?? item; // Dependiendo de si usas RPC o consulta directa
        final documentos = item['documentos'] ?? [item['documento']].where((d) => d != null);

        final ninoId = nino['id'];
        if (!ninosUnicos.containsKey(ninoId)) {
          ninosUnicos[ninoId] = {
            ...nino,
            'documentos_coincidentes': [],
            'total_coincidencias': 0,
            'rank_maximo': item['rank'] ?? 0,
          };
        }

        // Agregar documentos coincidentes
        for (final doc in documentos) {
          if (doc != null && _documentoCoincide(doc, query)) {
            ninosUnicos[ninoId]!['documentos_coincidentes'].add(doc);
            ninosUnicos[ninoId]!['total_coincidencias'] =
                ninosUnicos[ninoId]!['total_coincidencias'] + 1;
          }
        }
      }

      // Ordenar por relevancia (rank) y número de coincidencias
      final resultadosOrdenados = ninosUnicos.values.toList()
        ..sort((a, b) {
          final rankA = a['rank_maximo'] ?? 0;
          final rankB = b['rank_maximo'] ?? 0;
          if (rankA != rankB) return rankB.compareTo(rankA);

          final coincidenciasA = a['total_coincidencias'] ?? 0;
          final coincidenciasB = b['total_coincidencias'] ?? 0;
          return coincidenciasB.compareTo(coincidenciasA);
        });

      setState(() {
        resultados = resultadosOrdenados;
        isLoading = false;
      });

      print('✅ Búsqueda avanzada completada: ${resultados.length} niños encontrados');

    } catch (e) {
      print('❌ Error en búsqueda avanzada: $e');

      // Fallback a búsqueda básica si la avanzada falla
      try {
        await _buscarEnDocumentosBasico(query);
      } catch (fallbackError) {
        setState(() {
          errorMessage = 'Error en búsqueda: ${e.toString()}';
          isLoading = false;
          resultados = [];
        });
      }
    }
  }

  bool _documentoCoincide(Map<String, dynamic> documento, String query) {
    final contenido = documento['contenido_texto'] as String? ?? '';
    final nombreArchivo = documento['nombre_archivo'] as String? ?? '';
    final categoria = documento['categoria'] as String? ?? '';

    final queryLower = query.toLowerCase();
    return contenido.toLowerCase().contains(queryLower) ||
           nombreArchivo.toLowerCase().contains(queryLower) ||
           categoria.toLowerCase().contains(queryLower);
  }

  Future<void> _buscarEnDocumentosBasico(String query) async {
    // Búsqueda básica como fallback
    final response = await supabase
        .from('ninos')
        .select('''
          *,
          documentos!inner(
            id,
            tipo,
            nombre_archivo,
            contenido_texto,
            categoria
          )
        ''')
        .filter('documentos.contenido_texto', 'ilike', '%${query.trim()}%');

    // Procesar resultados para evitar duplicados
    final Map<String, Map<String, dynamic>> ninosUnicos = {};

    for (final nino in response) {
      final ninoId = nino['id'];
      if (!ninosUnicos.containsKey(ninoId)) {
        ninosUnicos[ninoId] = {
          ...nino,
          'documentos_coincidentes': [],
        };
      }

      // Agregar documentos coincidentes
      final documentos = nino['documentos'] as List<dynamic>;
      for (final doc in documentos) {
        if (_documentoCoincide(doc, query)) {
          ninosUnicos[ninoId]!['documentos_coincidentes'].add(doc);
        }
      }
    }

    setState(() {
      resultados = ninosUnicos.values.toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Búsqueda Avanzada'),
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
          child: Column(
            children: [
              // Campo de búsqueda
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F8C93B5),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar en documentos escaneados...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFB39DDB),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color(0xFFB39DDB),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _buscarPorPalabrasClave('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // Debounce la búsqueda para evitar llamadas excesivas
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (value == _searchController.text) {
                          _buscarPorPalabrasClave(value);
                        }
                      });
                    },
                  ),
                ),
              ),

              // Palabras clave extraídas
              if (palabrasClaveGlobales.isNotEmpty && _searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5DDFB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.key,
                              color: Color(0xFFB39DDB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Palabras clave encontradas',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4E4A67),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: palabrasClaveGlobales.take(20).map((palabra) {
                            final esRelevante = palabra.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                                               _searchController.text.toLowerCase().contains(palabra.toLowerCase());
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: esRelevante ? const Color(0xFFB39DDB).withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: esRelevante ? const Color(0xFFB39DDB) : const Color(0xFFE5DDFB),
                                ),
                              ),
                              child: Text(
                                palabra,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: esRelevante ? const Color(0xFFB39DDB) : const Color(0xFF7A7890),
                                  fontWeight: esRelevante ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (palabrasClaveGlobales.length > 20)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${palabrasClaveGlobales.length - 20} más...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A7890),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Indicador de carga
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB39DDB)),
                  ),
                ),

              // Mensaje de error
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Resultados
              Expanded(
                child: resultados.isEmpty && !isLoading && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron resultados para "${_searchController.text}"',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: resultados.length,
                        itemBuilder: (context, index) {
                          final nino = resultados[index];
                          final documentosCoincidentes = nino['documentos_coincidentes'] as List<dynamic>;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1F8C93B5),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetalleNinoPage(id: nino['id']),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Información del niño
                                    Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFE5DDFB),
                                              width: 2,
                                            ),
                                            image: (nino['foto_url'] != null && nino['foto_url'].isNotEmpty)
                                                ? DecorationImage(
                                                    image: NetworkImage(nino['foto_url']),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: (nino['foto_url'] == null || nino['foto_url'].isEmpty)
                                              ? const Icon(
                                                  Icons.person_outline,
                                                  color: Color(0xFFB39DDB),
                                                  size: 25,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nino['nombre'] ?? 'Sin nombre',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4E4A67),
                                                ),
                                              ),
                                              Text(
                                                'ID: ${nino['id']}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Color(0xFFB39DDB),
                                          size: 20,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Palabras clave relevantes del niño
                                    if (nino['palabras_clave_relevantes'] != null &&
                                        (nino['palabras_clave_relevantes'] as List).isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFB39DDB).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.lightbulb,
                                                  color: Color(0xFF4CAF50),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Palabras clave relevantes',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: (nino['palabras_clave_relevantes'] as List<String>).map((palabra) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    palabra,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF2E7D32),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 16),

                                    // Documentos coincidentes
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F5FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE5DDFB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.description,
                                                color: Color(0xFFB39DDB),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${documentosCoincidentes.length} documento(s) coincidente(s)',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4E4A67),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ...documentosCoincidentes.take(2).map((doc) {
                                            final contenido = doc['contenido_texto'] as String? ?? '';
                                            final query = _searchController.text.toLowerCase();
                                            final index = contenido.toLowerCase().indexOf(query);

                                            String preview = contenido;
                                            if (index >= 0) {
                                              final start = (index - 50).clamp(0, contenido.length);
                                              final end = (index + 100).clamp(0, contenido.length);
                                              preview = contenido.substring(start, end);
                                              if (start > 0) preview = '...$preview';
                                              if (end < contenido.length) preview = '$preview...';
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '"${doc['nombre_archivo'] ?? 'Documento'}"',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: Color(0xFF7A7890),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          if (documentosCoincidentes.length > 2)
                                            Text(
                                              '+ ${documentosCoincidentes.length - 2} más...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.withOpacity(0.6),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}