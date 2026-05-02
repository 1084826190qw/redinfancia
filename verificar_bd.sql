-- Script para verificar que la BD esté funcionando correctamente
-- Ejecutar en Supabase SQL Editor

-- 1. Verificar que la columna contenido_texto_tsv existe
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'documentos' AND column_name = 'contenido_texto_tsv';

-- 2. Verificar que el trigger existe
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'documentos';

-- 3. Verificar que los índices existen
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'documentos';

-- 4. Verificar que la función RPC existe
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'buscar_documentos_fts';

-- 5. Probar una consulta simple
SELECT COUNT(*) as total_documentos FROM documentos;

-- 6. Verificar documentos con contenido_texto
SELECT id, nombre_archivo, LENGTH(contenido_texto) as longitud_texto
FROM documentos
WHERE contenido_texto IS NOT NULL AND contenido_texto != ''
LIMIT 5;