-- ===========================================
-- SCRIPT COMPLETO PARA APLICAR OPTIMIZACIONES DE BÚSQUEDA
-- Ejecutar en Supabase SQL Editor
-- ===========================================

-- 1. Agregar columna para full-text search si no existe
ALTER TABLE documentos
ADD COLUMN IF NOT EXISTS contenido_texto_tsv tsvector;

-- 2. Crear función de limpieza (opcional pero recomendada)
CREATE OR REPLACE FUNCTION limpiar_texto_ocr(texto text) RETURNS text AS $$
BEGIN
  IF texto IS NULL THEN RETURN ''; END IF;
  texto := lower(texto);
  texto := regexp_replace(texto, '[^a-zA-Z0-9áéíóúñü\s]', ' ', 'g');
  texto := regexp_replace(texto, '\s+', ' ', 'g');
  RETURN trim(texto);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 3. Crear trigger para actualizar vector de búsqueda
CREATE OR REPLACE FUNCTION documentos_contenido_texto_trigger() RETURNS trigger AS $$
begin
  -- Solo procesar si hay contenido de texto
  IF new.contenido_texto IS NOT NULL AND trim(new.contenido_texto) != '' THEN
    BEGIN
      -- Crear vector de búsqueda
      new.contenido_texto_tsv :=
        setweight(to_tsvector('spanish', new.contenido_texto), 'A');
    EXCEPTION
      WHEN OTHERS THEN
        -- Si hay error, crear vector vacío
        new.contenido_texto_tsv := ''::tsvector;
        RAISE NOTICE 'Error creando vector de búsqueda para documento: %', new.id;
    END;
  ELSE
    -- Si no hay contenido, crear vector vacío
    new.contenido_texto_tsv := ''::tsvector;
  END IF;

  return new;
end
$$ LANGUAGE plpgsql;

-- 4. Crear el trigger
DROP TRIGGER IF EXISTS tsvector_update_trigger ON documentos;
CREATE TRIGGER tsvector_update_trigger
  BEFORE INSERT OR UPDATE ON documentos
  FOR EACH ROW EXECUTE FUNCTION documentos_contenido_texto_trigger();

-- 5. Crear índices
CREATE INDEX IF NOT EXISTS idx_documentos_contenido_texto_ilike
ON documentos USING gin (contenido_texto gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_documentos_contenido_texto_tsv
ON documentos USING gin (contenido_texto_tsv);

-- 6. Actualizar documentos existentes
UPDATE documentos SET contenido_texto = contenido_texto WHERE contenido_texto_tsv IS NULL;

-- 7. Crear función RPC para búsqueda (si no existe)
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
    FROM ninos n
    INNER JOIN ninos_con_documentos ncd ON n.id = ncd.id_nino;
  END IF;
END;
$$;

-- Verificar que todo esté funcionando
SELECT 'Optimizaciones aplicadas correctamente' as status;