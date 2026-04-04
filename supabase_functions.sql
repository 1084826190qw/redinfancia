-- ===========================================
-- FUNCIÓN RPC PARA BÚSQUEDA AVANZADA EN SUPABASE
-- ===========================================

-- Función principal para búsqueda full-text search
CREATE OR REPLACE FUNCTION buscar_documentos_fts(
  query_text text,
  limit_results integer DEFAULT 50,
  offset_results integer DEFAULT 0
)
RETURNS TABLE(
  nino jsonb,
  documentos jsonb[],
  rank real,
  total_coincidencias bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
  query_tsquery tsquery;
BEGIN
  -- Crear query de full-text search
  query_tsquery := plainto_tsquery('spanish', trim(query_text));

  -- Si no hay términos válidos, usar búsqueda ILIKE como fallback
  IF query_tsquery IS NULL OR query_text = '' THEN
    RETURN QUERY
    SELECT
      jsonb_build_object(
        'id', n.id,
        'nombre', n.nombre,
        'genero', n.genero,
        'fecha_nacimiento', n.fecha_nacimiento,
        'categoria', n.categoria,
        'foto_url', n.foto_url
      ) as nino,
      array_agg(
        jsonb_build_object(
          'id', d.id,
          'tipo', d.tipo,
          'nombre_archivo', d.nombre_archivo,
          'categoria', d.categoria,
          'contenido_texto', d.contenido_texto,
          'created_at', d.created_at
        )
      ) as documentos,
      0::real as rank,
      count(d.id)::bigint as total_coincidencias
    FROM ninos n
    INNER JOIN documentos d ON n.id = d.id_nino
    WHERE d.contenido_texto ILIKE '%' || trim(query_text) || '%'
    GROUP BY n.id, n.nombre, n.genero, n.fecha_nacimiento, n.categoria, n.foto_url
    ORDER BY total_coincidencias DESC, n.nombre
    LIMIT limit_results
    OFFSET offset_results;
  ELSE
    -- Búsqueda full-text search optimizada
    RETURN QUERY
    WITH documentos_rankeados AS (
      SELECT
        d.id_nino,
        d.id as documento_id,
        ts_rank(d.contenido_texto_tsv, query_tsquery) as doc_rank,
        jsonb_build_object(
          'id', d.id,
          'tipo', d.tipo,
          'nombre_archivo', d.nombre_archivo,
          'categoria', d.categoria,
          'contenido_texto', d.contenido_texto,
          'created_at', d.created_at,
          'rank', ts_rank(d.contenido_texto_tsv, query_tsquery)
        ) as documento_json
      FROM documentos d
      WHERE d.contenido_texto_tsv @@ query_tsquery
      ORDER BY ts_rank(d.contenido_texto_tsv, query_tsquery) DESC
    ),
    ninos_con_documentos AS (
      SELECT
        dr.id_nino,
        MAX(dr.doc_rank) as max_rank,
        COUNT(dr.documento_id) as num_documentos,
        array_agg(dr.documento_json ORDER BY dr.doc_rank DESC) as documentos_array
      FROM documentos_rankeados dr
      GROUP BY dr.id_nino
      ORDER BY max_rank DESC, num_documentos DESC
      LIMIT limit_results
      OFFSET offset_results
    )
    SELECT
      jsonb_build_object(
        'id', n.id,
        'nombre', n.nombre,
        'genero', n.genero,
        'fecha_nacimiento', n.fecha_nacimiento,
        'categoria', n.categoria,
        'foto_url', n.foto_url
      ) as nino,
      ncd.documentos_array as documentos,
      ncd.max_rank as rank,
      ncd.num_documentos as total_coincidencias
    FROM ninos_con_documentos ncd
    INNER JOIN ninos n ON ncd.id_nino = n.id
    ORDER BY ncd.max_rank DESC, ncd.num_documentos DESC, n.nombre;
  END IF;
END;
$$;

-- ===========================================
-- FUNCIÓN PARA BÚSQUEDA CON FILTROS ADICIONALES
-- ===========================================

CREATE OR REPLACE FUNCTION buscar_documentos_avanzada(
  query_text text,
  tipos_documento text[] DEFAULT NULL,
  categorias_documento text[] DEFAULT NULL,
  fecha_desde date DEFAULT NULL,
  fecha_hasta date DEFAULT NULL,
  limit_results integer DEFAULT 50,
  offset_results integer DEFAULT 0
)
RETURNS TABLE(
  nino jsonb,
  documentos jsonb[],
  rank real,
  total_coincidencias bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
  query_tsquery tsquery;
  where_clause text := '';
BEGIN
  -- Crear query de full-text search
  query_tsquery := plainto_tsquery('spanish', trim(query_text));

  -- Construir cláusula WHERE dinámica
  IF tipos_documento IS NOT NULL AND array_length(tipos_documento, 1) > 0 THEN
    where_clause := where_clause || ' AND d.tipo = ANY($4)';
  END IF;

  IF categorias_documento IS NOT NULL AND array_length(categorias_documento, 1) > 0 THEN
    where_clause := where_clause || ' AND d.categoria = ANY($5)';
  END IF;

  IF fecha_desde IS NOT NULL THEN
    where_clause := where_clause || ' AND d.created_at >= $6';
  END IF;

  IF fecha_hasta IS NOT NULL THEN
    where_clause := where_clause || ' AND d.created_at <= $7';
  END IF;

  -- Si no hay términos válidos, usar búsqueda ILIKE como fallback
  IF query_tsquery IS NULL OR query_text = '' THEN
    RETURN QUERY EXECUTE
    'SELECT
      jsonb_build_object(
        ''id'', n.id,
        ''nombre'', n.nombre,
        ''genero'', n.genero,
        ''fecha_nacimiento'', n.fecha_nacimiento,
        ''categoria'', n.categoria,
        ''foto_url'', n.foto_url
      ) as nino,
      array_agg(
        jsonb_build_object(
          ''id'', d.id,
          ''tipo'', d.tipo,
          ''nombre_archivo'', d.nombre_archivo,
          ''categoria'', d.categoria,
          ''contenido_texto'', d.contenido_texto,
          ''created_at'', d.created_at
        )
      ) as documentos,
      0::real as rank,
      count(d.id)::bigint as total_coincidencias
    FROM ninos n
    INNER JOIN documentos d ON n.id = d.id_nino
    WHERE d.contenido_texto ILIKE ''%'' || $1 || ''%''' || where_clause || '
    GROUP BY n.id, n.nombre, n.genero, n.fecha_nacimiento, n.categoria, n.foto_url
    ORDER BY total_coincidencias DESC, n.nombre
    LIMIT $2
    OFFSET $3'
    USING trim(query_text), limit_results, offset_results,
          tipos_documento, categorias_documento, fecha_desde, fecha_hasta;
  ELSE
    -- Búsqueda full-text search con filtros
    RETURN QUERY EXECUTE
    'WITH documentos_rankeados AS (
      SELECT
        d.id_nino,
        d.id as documento_id,
        ts_rank(d.contenido_texto_tsv, $8) as doc_rank,
        jsonb_build_object(
          ''id'', d.id,
          ''tipo'', d.tipo,
          ''nombre_archivo'', d.nombre_archivo,
          ''categoria'', d.categoria,
          ''contenido_texto'', d.contenido_texto,
          ''created_at'', d.created_at,
          ''rank'', ts_rank(d.contenido_texto_tsv, $8)
        ) as documento_json
      FROM documentos d
      WHERE d.contenido_texto_tsv @@ $8' || where_clause || '
      ORDER BY ts_rank(d.contenido_texto_tsv, $8) DESC
    ),
    ninos_con_documentos AS (
      SELECT
        dr.id_nino,
        MAX(dr.doc_rank) as max_rank,
        COUNT(dr.documento_id) as num_documentos,
        array_agg(dr.documento_json ORDER BY dr.doc_rank DESC) as documentos_array
      FROM documentos_rankeados dr
      GROUP BY dr.id_nino
      ORDER BY max_rank DESC, num_documentos DESC
      LIMIT $2
      OFFSET $3
    )
    SELECT
      jsonb_build_object(
        ''id'', n.id,
        ''nombre'', n.nombre,
        ''genero'', n.genero,
        ''fecha_nacimiento'', n.fecha_nacimiento,
        ''categoria'', n.categoria,
        ''foto_url'', n.foto_url
      ) as nino,
      ncd.documentos_array as documentos,
      ncd.max_rank as rank,
      ncd.num_documentos as total_coincidencias
    FROM ninos_con_documentos ncd
    INNER JOIN ninos n ON ncd.id_nino = n.id
    ORDER BY ncd.max_rank DESC, ncd.num_documentos DESC, n.nombre'
    USING trim(query_text), limit_results, offset_results,
          tipos_documento, categorias_documento, fecha_desde, fecha_hasta, query_tsquery;
  END IF;
END;
$$;

-- ===========================================
-- FUNCIÓN PARA AUTOCOMPLETE/SUGERENCIAS
-- ===========================================

CREATE OR REPLACE FUNCTION sugerencias_busqueda(
  prefix text,
  limit_results integer DEFAULT 10
)
RETURNS TABLE(
  sugerencia text,
  frecuencia bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    word as sugerencia,
    nentry as frecuencia
  FROM ts_stat('
    SELECT contenido_texto_tsv
    FROM documentos
    WHERE contenido_texto_tsv IS NOT NULL
  ')
  WHERE word LIKE trim(prefix) || '%'
  ORDER BY nentry DESC, word
  LIMIT limit_results;
END;
$$;

-- ===========================================
-- PERMISOS PARA FUNCIONES RPC
-- ===========================================

-- Otorgar permisos para que las funciones sean accesibles desde la API
GRANT EXECUTE ON FUNCTION buscar_documentos_fts(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION buscar_documentos_avanzada(text, text[], text[], date, date, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION sugerencias_busqueda(text, integer) TO authenticated;

-- ===========================================
-- EJEMPLOS DE USO DESDE FLUTTER
-- ===========================================

/*
-- Búsqueda básica
SELECT * FROM buscar_documentos_fts('palabra clave', 20, 0);

-- Búsqueda con filtros
SELECT * FROM buscar_documentos_avanzada(
  'palabra clave',
  ARRAY['pdf', 'documento'], -- tipos
  ARRAY['certificado', 'informe'], -- categorías
  '2024-01-01'::date, -- fecha desde
  '2024-12-31'::date, -- fecha hasta
  50, -- límite
  0 -- offset
);

-- Sugerencias de autocompletado
SELECT * FROM sugerencias_busqueda('cert', 5);
*/

Widget _buildHighlightedText(String text, String query) {
  // Lógica compleja para resaltar coincidencias
  // con RichText y contexto inteligente
}