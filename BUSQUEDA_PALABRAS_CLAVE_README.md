# Búsqueda por Palabras Clave - Funcionalidad Avanzada

## 🎯 **Nueva Funcionalidad: Búsqueda Inteligente por Palabras Clave**

Se ha implementado un sistema de búsqueda avanzado que extrae automáticamente palabras clave del texto OCR de los documentos, permitiendo búsquedas más precisas e inteligentes.

## 🧠 **Inteligencia Artificial en la Búsqueda**

### **Extracción Automática de Palabras Clave**
- **Análisis lingüístico**: Procesamiento inteligente del texto OCR
- **Filtrado de ruido**: Eliminación de palabras comunes (stop words)
- **Detección de términos compuestos**: Identificación de frases relevantes
- **Puntuación por relevancia**: Ranking basado en frecuencia y longitud

### **Algoritmo de Extracción**
```dart
// 1. Limpieza del texto OCR
String textoLimpio = texto.toLowerCase()
    .replaceAll(RegExp(r'[^\w\sáéíóúñü]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// 2. Filtrado de palabras relevantes
List<String> palabras = textoLimpio.split(' ')
    .where((palabra) => palabra.length > 2)
    .where((palabra) => !stopWords.contains(palabra))
    .where((palabra) => !RegExp(r'^\d+$').hasMatch(palabra));

// 3. Detección de términos compuestos
List<String> terminosCompuestos = _extraerTerminosCompuestos(textoLimpio);

// 4. Puntuación y ranking
double puntuacion = frecuencia * (longitud / 10.0) * (esCompuesto ? 1.5 : 1.0);
```

## 🔍 **Tipos de Búsqueda**

### **1. Búsqueda Directa**
- Busca coincidencias exactas en el texto completo
- Funciona con cualquier consulta del usuario

### **2. Búsqueda por Palabras Clave**
- Extrae palabras clave del texto OCR
- Busca coincidencias en términos relevantes
- Más precisa para consultas específicas

### **3. Búsqueda Híbrida**
- Combina búsqueda directa + palabras clave
- Mayor cobertura de resultados
- Mejor experiencia de usuario

## 📊 **Características Técnicas**

### **Procesamiento de Texto**
- **Idioma**: Español con soporte para acentos
- **Stop Words**: 50+ palabras comunes filtradas
- **Longitud mínima**: 3 caracteres por palabra
- **Términos compuestos**: Bigramas y trigramas detectados

### **Algoritmo de Puntuación**
```dart
double puntuacion = frecuenciaBase;
puntuacion *= (longitudPalabra / 10.0).clamp(0.5, 2.0); // Bonus por longitud
if (esTerminoCompuesto) puntuacion *= 1.5; // Bonus por compuestos
```

### **Límite de Resultados**
- **Palabras clave por documento**: Top 10 más relevantes
- **Palabras clave globales**: Top 20 para mostrar
- **Palabras clave por niño**: Top 5 más relevantes

## 🎨 **Interfaz de Usuario**

### **Búsqueda Global Avanzada** (`busqueda_avanzada_page.dart`)

#### **Campo de Búsqueda**
- Placeholder: "Buscar en documentos escaneados..."
- Iconos de búsqueda y limpieza
- Diseño consistente con la app

#### **Sección de Palabras Clave Globales**
- Muestra todas las palabras clave encontradas
- Resalta palabras relevantes para la búsqueda
- Diseño con chips coloridos
- Indicador de cantidad adicional

#### **Resultados por Niño**
- Información básica del niño
- **Palabras clave relevantes**: Chips verdes destacados
- Documentos coincidentes con preview
- Navegación directa al perfil

### **Búsqueda Local en Perfil** (`detalle_nino_page.dart`)

#### **Campo de Búsqueda Integrado**
- Ubicado en la sección de documentos
- Placeholder: "Buscar en documentos..."
- Filtrado instantáneo de documentos del niño

#### **Resultados Filtrados**
- Contador dinámico: "Mostrando X de Y documento(s)"
- Resaltado de coincidencias en el texto
- Mensajes diferenciados para diferentes estados

## 🔄 **Flujo de Funcionamiento**

### **Búsqueda Global**
1. Usuario ingresa consulta en página de búsqueda avanzada
2. Sistema busca documentos que contengan la consulta
3. Extrae palabras clave de todos los documentos encontrados
4. Muestra palabras clave globales + resultados por niño
5. Cada niño muestra sus palabras clave más relevantes

### **Búsqueda Local**
1. Usuario entra al perfil de un niño
2. Escribe en el campo de búsqueda de documentos
3. Sistema filtra documentos del niño por:
   - Contenido directo
   - Nombre de archivo
   - Tipo y categoría
   - Palabras clave extraídas

## 📈 **Beneficios**

### **Para Usuarios**
- **Más precisa**: Encuentra información relevante más fácilmente
- **Más rápida**: Resultados más específicos reducen tiempo de búsqueda
- **Más inteligente**: El sistema entiende el contexto del contenido
- **Más visual**: Palabras clave destacadas facilitan navegación

### **Para el Sistema**
- **Mejor rendimiento**: Búsqueda híbrida optimiza consultas
- **Menos falsos positivos**: Palabras clave reducen ruido
- **Mejor UX**: Resultados más relevantes y útiles
- **Escalabilidad**: Algoritmo eficiente para grandes volúmenes

## 🛠️ **Configuración y Optimización**

### **Stop Words Personalizables**
```dart
final stopWords = {
  'el', 'la', 'los', 'las', 'de', 'del', 'y', 'a', 'en', 'que', 'es',
  'un', 'una', 'por', 'con', 'se', 'para', 'como', 'su', 'al', 'lo',
  // ... más palabras según necesidad
};
```

### **Parámetros Ajustables**
- **Longitud mínima de palabras**: Actualmente 3 caracteres
- **Cantidad máxima de palabras clave**: 10 por documento
- **Puntuación mínima**: Para filtrar palabras irrelevantes
- **Tamaño de términos compuestos**: 6-30 caracteres

### **Idiomas Soportados**
- **Primario**: Español con acentos
- **Extensible**: Fácil agregar otros idiomas
- **Stop words**: Configurables por idioma

## 📊 **Métricas y Analytics**

### **Datos Recopilados**
- Consultas de búsqueda más frecuentes
- Palabras clave más utilizadas
- Tasa de éxito de búsquedas
- Tiempo promedio de búsqueda
- Documentos más consultados

### **Optimizaciones Futuras**
- **Machine Learning**: Aprender de patrones de búsqueda
- **Cache inteligente**: Palabras clave pre-calculadas
- **Búsqueda semántica**: Entender intención del usuario
- **Sugerencias automáticas**: Autocompletado inteligente

## 🔧 **Mantenimiento**

### **Actualización de Stop Words**
```sql
-- Agregar nuevas stop words según uso observado
INSERT INTO configuracion (clave, valor)
VALUES ('stop_words_adicionales', 'palabra1,palabra2,palabra3');
```

### **Monitoreo de Rendimiento**
- Consultas lentas en logs
- Palabras clave más frecuentes
- Tasa de aciertos de búsqueda
- Feedback de usuarios

### **Backup y Recuperación**
- Palabras clave se recalculan automáticamente
- No requieren backup especial
- Recuperación automática al reiniciar

## 🚀 **Próximas Mejoras**

### **Funcionalidades Avanzadas**
1. **Búsqueda por voz**: Integración con reconocimiento de voz
2. **Filtros avanzados**: Por fecha, tipo, categoría
3. **Búsqueda semántica**: Entender contexto e intención
4. **Sugerencias inteligentes**: Basadas en historial
5. **Exportación de resultados**: Con palabras clave destacadas

### **Optimizaciones Técnicas**
1. **Cache de palabras clave**: Pre-calcular para documentos frecuentes
2. **Indexación avanzada**: Full-text search optimizado
3. **Machine Learning**: Modelo de relevancia personalizado
4. **API de palabras clave**: Servicio separado para escalabilidad

---

*Esta implementación representa un salto significativo en la capacidad de búsqueda, haciendo que encontrar información específica en documentos OCR sea tan natural como buscar en texto normal.* 🎉