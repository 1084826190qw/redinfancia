-- ===========================================
-- OPTIMIZACIÓN DE BÚSQUEDA PARA DOCUMENTOS OCR
-- ===========================================

-- 1. ÍNDICE PARA BÚSQUEDA DE TEXTO (ILIKE)
-- Este índice acelera las búsquedas case-insensitive
CREATE INDEX IF NOT EXISTS idx_documentos_contenido_texto_ilike
ON documentos USING gin (contenido_texto gin_trgm_ops);

-- 2. FULL-TEXT SEARCH - Crear columna para búsqueda avanzada
-- Agregar columna de búsqueda si no existe
ALTER TABLE documentos
ADD COLUMN IF NOT EXISTS contenido_texto_tsv tsvector;

-- Crear función para actualizar el vector de búsqueda
CREATE OR REPLACE FUNCTION documentos_contenido_texto_trigger() RETURNS trigger AS $$
begin
  new.contenido_texto_tsv :=
    setweight(to_tsvector('spanish', coalesce(new.contenido_texto, '')), 'A');
  return new;
end
$$ LANGUAGE plpgsql;

-- Crear trigger para mantener actualizado el vector de búsqueda
DROP TRIGGER IF EXISTS tsvector_update_trigger ON documentos;
CREATE TRIGGER tsvector_update_trigger
  BEFORE INSERT OR UPDATE ON documentos
  FOR EACH ROW EXECUTE FUNCTION documentos_contenido_texto_trigger();

-- Actualizar registros existentes
UPDATE documentos SET contenido_texto = contenido_texto WHERE contenido_texto_tsv IS NULL;

-- 3. ÍNDICE GIN para full-text search
CREATE INDEX IF NOT EXISTS idx_documentos_contenido_texto_tsv
ON documentos USING gin (contenido_texto_tsv);

-- ===========================================
-- CONSULTAS DE BÚSQUEDA OPTIMIZADAS
-- ===========================================

-- BÚSQUEDA BÁSICA (ILIKE) - Para consultas simples
-- SELECT n.*, d.id as documento_id, d.nombre_archivo, d.tipo
-- FROM ninos n
-- INNER JOIN documentos d ON n.id = d.id_nino
-- WHERE d.contenido_texto ILIKE '%palabra_clave%';

-- BÚSQUEDA AVANZADA (FULL-TEXT SEARCH) - Para mejor rendimiento
-- SELECT n.*, d.id as documento_id, d.nombre_archivo, d.tipo,
--        ts_rank(d.contenido_texto_tsv, plainto_tsquery('spanish', 'palabra clave')) as rank
-- FROM ninos n
-- INNER JOIN documentos d ON n.id = d.id_nino
-- WHERE d.contenido_texto_tsv @@ plainto_tsquery('spanish', 'palabra clave')
-- ORDER BY rank DESC;

-- BÚSQUEDA CON MÚLTIPLES PALABRAS Y RANKING
-- SELECT DISTINCT n.*,
--        COUNT(d.id) as documentos_coincidentes,
--        MAX(ts_rank(d.contenido_texto_tsv, query)) as max_rank
-- FROM ninos n
-- INNER JOIN documentos d ON n.id = d.id_nino,
--      plainto_tsquery('spanish', 'palabra1 palabra2') as query
-- WHERE d.contenido_texto_tsv @@ query
-- GROUP BY n.id, n.nombre, n.genero, n.fecha_nacimiento, n.categoria, n.foto_url
-- ORDER BY max_rank DESC, documentos_coincidentes DESC;

-- ===========================================
-- FUNCIONES DE LIMPIEZA PARA TEXTO OCR
-- ===========================================

-- Función para limpiar texto OCR antes de guardar
CREATE OR REPLACE FUNCTION limpiar_texto_ocr(texto text) RETURNS text AS $$
BEGIN
  texto := lower(texto);
  texto := regexp_replace(texto, '[^a-zA-Z0-9áéíóúñü\s]', ' ', 'g');
  texto := regexp_replace(texto, '\s+', ' ', 'g');
  RETURN trim(texto);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Actualizar trigger para usar limpieza automática
CREATE OR REPLACE FUNCTION documentos_contenido_texto_trigger() RETURNS trigger AS $$
begin
  -- Limpiar el texto OCR
  new.contenido_texto := limpiar_texto_ocr(coalesce(new.contenido_texto, ''));

  -- Crear vector de búsqueda
  new.contenido_texto_tsv :=
    setweight(to_tsvector('spanish', new.contenido_texto), 'A');

  return new;
end
$$ LANGUAGE plpgsql;

-- ===========================================
-- OPTIMIZACIONES ADICIONALES
-- ===========================================

-- Índice compuesto para búsquedas por niño + tipo de documento
CREATE INDEX IF NOT EXISTS idx_documentos_nino_tipo
ON documentos (id_nino, tipo);

-- Índice para fecha de creación (útil para ordenamiento)
CREATE INDEX IF NOT EXISTS idx_documentos_created_at
ON documentos (created_at DESC);

-- Vista materializada para búsquedas frecuentes (opcional)
-- CREATE MATERIALIZED VIEW busqueda_documentos AS
-- SELECT n.id as nino_id, n.nombre, n.genero, n.fecha_nacimiento,
--        d.id as documento_id, d.nombre_archivo, d.tipo, d.categoria,
--        d.contenido_texto, d.contenido_texto_tsv
-- FROM ninos n
-- INNER JOIN documentos d ON n.id = d.id_nino;

-- Para actualizar la vista materializada:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY busqueda_documentos;

-- ===========================================
-- MONITOREO DE RENDIMIENTO
-- ===========================================

-- Verificar uso de índices
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes
-- WHERE tablename IN ('documentos', 'ninos')
-- ORDER BY idx_scan DESC;

-- Verificar consultas lentas
-- SELECT query, calls, total_time, mean_time, rows
-- FROM pg_stat_statements
-- WHERE query LIKE '%documentos%'
-- ORDER BY mean_time DESC
-- LIMIT 10;

-- BÚSQUEDA BÁSICA (ILIKE) - Para consultas simples
SELECT n.*, d.id as documento_id
FROM ninos n
INNER JOIN documentos d ON n.id = d.id_nino
WHERE d.contenido_texto ILIKE '%palabra_clave%';

-- BÚSQUEDA AVANZADA (FULL-TEXT SEARCH) - Para mejor rendimiento
SELECT n.*, d.id as documento_id,
       ts_rank(d.contenido_texto_tsv, query) as rank
FROM ninos n
INNER JOIN documentos d ON n.id = d.id_nino,
     plainto_tsquery('spanish', 'palabra clave') as query
WHERE d.contenido_texto_tsv @@ query
ORDER BY rank DESC;