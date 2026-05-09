import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  /// Obtiene la ruta local para un archivo dado niño, categoría y nombre de archivo.
  Future<String> _getLocalFilePath(String nino, String categoria, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final basePath = '${directory.path}/RedInfancia_Documentos/$nino/$categoria';
    await Directory(basePath).create(recursive: true);
    return '$basePath/$fileName';
  }

  /// Verifica si el archivo existe localmente.
  Future<bool> _fileExistsLocally(String filePath) async {
    return await File(filePath).exists();
  }

  /// Descarga el archivo desde Supabase Storage y lo guarda localmente.
  Future<void> _downloadAndSaveFile(String bucket, String filePath, String localPath) async {
    try {
      final url = _supabase.storage.from(bucket).getPublicUrl(filePath);
      final response = await _dio.download(url, localPath);
      if (response.statusCode != 200) {
        throw Exception('Error al descargar el archivo: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al descargar el archivo: $e');
    }
  }

  /// Abre el archivo usando open_file.
  Future<void> _openFile(String filePath) async {
    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Error al abrir el archivo: ${result.message}');
    }
  }

  /// Método para obtener y guardar un archivo sin abrirlo.
  /// - bucket: El bucket de Supabase Storage.
  /// - filePath: La ruta del archivo en Supabase (ej: 'nino/categoria/archivo.pdf').
  /// - nino: Nombre del niño.
  /// - categoria: Nombre de la categoría.
  /// - fileName: Nombre del archivo.
  Future<String> getAndSaveFile(String bucket, String filePath, String nino, String categoria, String fileName) async {
    try {
      final localPath = await _getLocalFilePath(nino, categoria, fileName);
      print('Ruta local calculada: $localPath');

      final exists = await _fileExistsLocally(localPath);
      print('¿Archivo existe localmente? $exists');

      if (exists) {
        // Verificar también el tamaño del archivo para asegurar que no esté vacío
        final file = File(localPath);
        final length = await file.length();
        print('Tamaño del archivo local: $length bytes');

        if (length > 0) {
          // El archivo existe localmente y tiene contenido, no hacer nada.
          print('Archivo ya existe localmente');
          return localPath;
        } else {
          // El archivo existe pero está vacío, descargarlo de nuevo
          print('Archivo existe pero está vacío, descargando de nuevo');
          await _downloadAndSaveFile(bucket, filePath, localPath);
          return localPath;
        }
      } else {
        // El archivo no existe, descargarlo y guardarlo.
        print('Archivo no existe, descargando desde Supabase');
        await _downloadAndSaveFile(bucket, filePath, localPath);
        return localPath;
      }
    } catch (e) {
      // Manejo de errores: puedes agregar logging aquí.
      print('Error en getAndSaveFile: $e');
      rethrow;
    }
  }

  /// Método para abrir un archivo que ya existe localmente.
  Future<void> openLocalFile(String nino, String categoria, String fileName) async {
    try {
      final localPath = await _getLocalFilePath(nino, categoria, fileName);
      print('Abriendo archivo: $localPath');
      await _openFile(localPath);
    } catch (e) {
      print('Error al abrir archivo: $e');
      rethrow;
    }
  }

  /// Método principal para obtener y abrir un archivo.
  /// - bucket: El bucket de Supabase Storage.
  /// - filePath: La ruta del archivo en Supabase (ej: 'nino/categoria/archivo.pdf').
  /// - nino: Nombre del niño.
  /// - categoria: Nombre de la categoría.
  /// - fileName: Nombre del archivo.
  Future<void> getAndOpenFile(String bucket, String filePath, String nino, String categoria, String fileName) async {
    try {
      final localPath = await _getLocalFilePath(nino, categoria, fileName);
      print('Ruta local calculada: $localPath');

      final exists = await _fileExistsLocally(localPath);
      print('¿Archivo existe localmente? $exists');

      if (exists) {
        // Verificar también el tamaño del archivo para asegurar que no esté vacío
        final file = File(localPath);
        final length = await file.length();
        print('Tamaño del archivo local: $length bytes');

        if (length > 0) {
          // El archivo existe localmente y tiene contenido, abrirlo directamente.
          print('Abriendo archivo existente localmente');
          await _openFile(localPath);
        } else {
          // El archivo existe pero está vacío, descargarlo de nuevo
          print('Archivo existe pero está vacío, descargando de nuevo');
          await _downloadAndSaveFile(bucket, filePath, localPath);
          await _openFile(localPath);
        }
      } else {
        // El archivo no existe, descargarlo y guardarlo.
        print('Archivo no existe, descargando desde Supabase');
        await _downloadAndSaveFile(bucket, filePath, localPath);
        // Después de guardar, abrirlo.
        await _openFile(localPath);
      }
    } catch (e) {
      // Manejo de errores: puedes agregar logging aquí.
      print('Error en getAndOpenFile: $e');
      rethrow;
    }
  }
}