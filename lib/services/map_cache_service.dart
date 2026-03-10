import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class MapCacheService {
  static bool _isDownloading = false;
  static double _progress = 0;

  static bool get isDownloading => _isDownloading;
  static double get progress => _progress;

  // Converte Coordenadas para Tile X/Y do OpenStreetMap
  static int lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * math.pow(2, zoom)).floor();
  }

  static int latToTileY(double lat, int zoom) {
    return ((1.0 -
                math.log(
                      math.tan(lat * math.pi / 180.0) +
                          1.0 / math.cos(lat * math.pi / 180.0),
                    ) /
                    math.pi) /
            2.0 *
            math.pow(2, zoom))
        .floor();
  }

  // Baixa uma região de 20km (aprox. 32 tiles de raio no Zoom 16)
  static Future<void> precacheRegion(
    double lat,
    double lon, {
    int radiusInTiles = 32,
  }) async {
    if (_isDownloading) return;
    _isDownloading = true;
    _progress = 0;

    const zoom = 16;
    final centerTileX = lonToTileX(lon, zoom);
    final centerTileY = latToTileY(lat, zoom);

    final appDocDir = await getApplicationDocumentsDirectory();
    final mapCacheDir = Directory(join(appDocDir.path, 'map_tiles'));
    if (!await mapCacheDir.exists()) await mapCacheDir.create(recursive: true);

    int total = (radiusInTiles * 2 + 1) * (radiusInTiles * 2 + 1);
    int count = 0;

    final client = http.Client();

    try {
      for (int dx = -radiusInTiles; dx <= radiusInTiles; dx++) {
        for (int dy = -radiusInTiles; dy <= radiusInTiles; dy++) {
          if (!_isDownloading) break; // Cancelamento se necessário

          final tx = centerTileX + dx;
          final ty = centerTileY + dy;
          final tileId = "v16_${tx}_$ty.png";
          final cacheFile = File(join(mapCacheDir.path, tileId));

          if (!await cacheFile.exists()) {
            final url =
                "https://basemaps.cartocdn.com/rastertiles/voyager/$zoom/$tx/$ty.png";
            try {
              final res = await client
                  .get(
                    Uri.parse(url),
                    headers: {'User-Agent': 'MarkTimeApp/1.0'},
                  )
                  .timeout(const Duration(seconds: 5));

              if (res.statusCode == 200) {
                await cacheFile.writeAsBytes(res.bodyBytes);
              }
            } catch (_) {}
          }

          count++;
          _progress = count / total;
          if (count % 20 == 0) {
            debugPrint(
              "Download Mapa: ${(_progress * 100).toStringAsFixed(1)}%",
            );
          }
        }
      }
    } finally {
      client.close();
      _isDownloading = false;
      _progress = 1.0;
    }
  }

  static void stopDownload() => _isDownloading = false;
}
