# Búsqueda Avanzada en Documentos OCR - Guía Completa

## 🎯 Objetivo
Implementar un sistema de búsqueda eficiente que permita encontrar niños basándose en el contenido de texto extraído de sus documentos mediante OCR.

## 📊 Estructura de Base de Datos

### Tabla `ninos`
```sql
CREATE TABLE ninos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  genero TEXT,
  fecha_nacimiento DATE,
  categoria TEXT,
  foto_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Tabla `documentos`
```sql
CREATE TABLE documentos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_nino UUID REFERENCES ninos(id) ON DELETE CASCADE,
  nombre_archivo TEXT,
  tipo TEXT, -- 'imagen', 'pdf', 'documento', etc.
  categoria TEXT,
  contenido_texto TEXT, -- Texto extraído por OCR
  contenido_texto_tsv tsvector, -- Para full-text search
  url TEXT, -- URL del archivo en storage
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🔍 Estrategias de Búsqueda

### 1. Búsqueda Básica (ILIKE)
- **Ventajas**: Simple, funciona con cualquier texto
- **Desventajas**: Lento con grandes volúmenes de datos
- **Uso**: Consultas simples, pocos documentos

```sql
SELECT n.*, d.id as documento_id
FROM ninos n
INNER JOIN documentos d ON n.id = d.id_nino
WHERE d.contenido_texto ILIKE '%palabra_clave%';
```

### 2. Full-Text Search (Recomendado)
- **Ventajas**: Muy rápido, soporta ranking, stemming
- **Desventajas**: Requiere configuración inicial
- **Uso**: Grandes volúmenes, búsquedas complejas

```sql
SELECT n.*, d.id as documento_id,
       ts_rank(d.contenido_texto_tsv, query) as rank
FROM ninos n
INNER JOIN documentos d ON n.id = d.id_nino,
     plainto_tsquery('spanish', 'palabra clave') as query
WHERE d.contenido_texto_tsv @@ query
ORDER BY rank DESC;
```

## ⚡ Optimizaciones de Rendimiento

### Índices Recomendados
```sql
-- Para ILIKE
CREATE INDEX idx_documentos_contenido_texto_ilike
ON documentos USING gin (contenido_texto gin_trgm_ops);

-- Para full-text search
CREATE INDEX idx_documentos_contenido_texto_tsv
ON documentos USING gin (contenido_texto_tsv);

-- Índices adicionales
CREATE INDEX idx_documentos_nino_tipo ON documentos (id_nino, tipo);
CREATE INDEX idx_documentos_created_at ON documentos (created_at DESC);
```

### Triggers Automáticos
```sql
-- Función de limpieza y vectorización automática
CREATE OR REPLACE FUNCTION documentos_contenido_texto_trigger() RETURNS trigger AS $$
begin
  -- Limpiar texto OCR
  new.contenido_texto := limpiar_texto_ocr(coalesce(new.contenido_texto, ''));

  -- Crear vector de búsqueda
  new.contenido_texto_tsv :=
    setweight(to_tsvector('spanish', new.contenido_texto), 'A');

  return new;
end
$$ LANGUAGE plpgsql;

-- Trigger
CREATE TRIGGER tsvector_update_trigger
  BEFORE INSERT OR UPDATE ON documentos
  FOR EACH ROW EXECUTE FUNCTION documentos_contenido_texto_trigger();
```

## 🧹 Procesamiento de Texto OCR

### Función de Limpieza
```sql
CREATE OR REPLACE FUNCTION limpiar_texto_ocr(texto text) RETURNS text AS $$
BEGIN
  -- Convertir a minúsculas
  texto := lower(texto);

  -- Remover caracteres especiales
  texto := regexp_replace(texto, '[^a-zA-Z0-9áéíóúñü\s]', ' ', 'g');

  -- Normalizar espacios
  texto := regexp_replace(texto, '\s+', ' ', 'g');

  -- Trim
  texto := trim(texto);

  RETURN texto;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### Mejores Prácticas para OCR
1. **Validación**: Verificar calidad del texto extraído
2. **Limpieza**: Remover ruido antes de guardar
3. **Normalización**: Convertir a minúsculas, remover acentos si es necesario
4. **Chunking**: Dividir textos muy largos en chunks más pequeños
5. **Compresión**: Comprimir texto si es muy largo (> 10MB)

## 📱 Implementación en Flutter

### Búsqueda con Debounce
```dart
Future<void> _buscarEnDocumentos(String query) async {
  if (query.trim().isEmpty) return;

  // Debounce para evitar llamadas excesivas
  Future.delayed(const Duration(milliseconds: 500), () {
    if (value == _searchController.text) {
      _performSearch(value);
    }
  });
}
```

### Consulta Optimizada
```dart
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
```

### Paginación
```dart
final response = await supabase
  .from('ninos')
  .select('...')
  .range(offset, offset + limit);
```

## 📈 Escalabilidad

### Para Grandes Volúmenes
1. **Paginación**: Limitar resultados por página
2. **Cache**: Almacenar resultados frecuentes
3. **Background Jobs**: Procesar OCR en background
4. **Shardding**: Dividir tablas si es necesario

### Monitoreo
```sql
-- Verificar uso de índices
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename IN ('documentos', 'ninos')
ORDER BY idx_scan DESC;

-- Consultas lentas
SELECT query, calls, total_time, mean_time, rows
FROM pg_stat_statements
WHERE query LIKE '%documentos%'
ORDER BY mean_time DESC;
```

## 🔧 Mantenimiento

### Actualización de Índices
```sql
-- Reconstruir índices si es necesario
REINDEX INDEX idx_documentos_contenido_texto_tsv;

-- Actualizar estadísticas
ANALYZE documentos;
ANALYZE ninos;
```

### Limpieza Periódica
```sql
-- Eliminar documentos huérfanos
DELETE FROM documentos
WHERE id_nino NOT IN (SELECT id FROM ninos);

-- Limpiar texto vacío
UPDATE documentos
SET contenido_texto = NULL, contenido_texto_tsv = NULL
WHERE contenido_texto = '';
```

## 🚀 Próximas Mejoras

1. **Búsqueda por Categorías**: Filtrar por tipo de documento
2. **Búsqueda Avanzada**: Operadores booleanos (AND, OR, NOT)
3. **Sugerencias**: Autocomplete basado en términos frecuentes
4. **Filtros**: Por fecha, tipo de documento, categoría
5. **Exportación**: Exportar resultados de búsqueda
6. **Analytics**: Métricas de uso de búsqueda

## 📝 Notas Importantes

- **Idioma**: Configurado para español (`spanish`)
- **Encoding**: Asegurar UTF-8 para caracteres especiales
- **Backup**: Respaldar regularmente la tabla `documentos`
- **Testing**: Probar con diferentes tipos de documentos OCR
- **Performance**: Monitorear queries lentas regularmente