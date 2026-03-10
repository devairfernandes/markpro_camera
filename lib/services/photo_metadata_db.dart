import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Banco de dados local permanente de fotos tiradas pelo MarkPro Camera.
/// Cada entrada contém o caminho da cópia local, lat, lon e endereço.
class PhotoMetadataDB {
  static const String _prefsKey = 'markpro_photo_db_v2';

  static Future<Directory> _getPhotosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(join(appDir.path, 'markpro_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Salva uma foto no banco local, copiando o arquivo para o diretório do app.
  /// Retorna o caminho da cópia local salva.
  static Future<String?> save({
    required String originalPath,
    required double? lat,
    required double? lon,
    required String address,
  }) async {
    try {
      final dir = await _getPhotosDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localPath = join(dir.path, 'markpro_$timestamp.jpg');

      // Copiar arquivo para o diretório interno do app
      await File(originalPath).copy(localPath);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);

      list.insert(0, {
        'path': localPath,
        'lat': lat,
        'lon': lon,
        'address': address,
        'timestamp': timestamp,
      });

      // Manter apenas as últimas 200 fotos
      if (list.length > 200) list.removeRange(200, list.length);

      await prefs.setString(_prefsKey, jsonEncode(list));
      return localPath;
    } catch (e) {
      return null;
    }
  }

  /// Retorna todas as fotos salvas, da mais recente para a mais antiga.
  static Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);

      // Filtrar apenas arquivos que ainda existem
      final valid = <Map<String, dynamic>>[];
      for (final item in list) {
        final path = item['path'] as String;
        if (await File(path).exists()) {
          valid.add(Map<String, dynamic>.from(item));
        }
      }

      // Atualizar lista removendo arquivos deletados
      if (valid.length != list.length) {
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setString(_prefsKey, jsonEncode(valid));
      }

      return valid;
    } catch (e) {
      return [];
    }
  }

  /// Remove uma foto do banco e do disco.
  static Future<void> delete(String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      list.removeWhere((e) => e['path'] == localPath);
      await prefs.setString(_prefsKey, jsonEncode(list));
      try {
        await File(localPath).delete();
      } catch (_) {}
    } catch (_) {}
  }
}
