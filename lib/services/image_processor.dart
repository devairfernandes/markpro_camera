import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gal/gal.dart';
import 'package:flutter/foundation.dart';

class ImageProcessParams {
  final String path;
  final double? lat;
  final double? lon;
  final double? alt;
  final double? acc;
  final String address;
  final String timeString;
  final String dateString;
  final String dayString;
  final String tempDirPath;
  final String cacheDirPath;
  final String? logoPath;
  final bool showTime;
  final bool showAddress;
  final bool showMap;
  final bool showLogo;
  final bool showCoords;
  final bool showAltitude;

  ImageProcessParams({
    required this.path,
    required this.lat,
    required this.lon,
    required this.alt,
    required this.acc,
    required this.address,
    required this.timeString,
    required this.dateString,
    required this.dayString,
    required this.tempDirPath,
    required this.cacheDirPath,
    this.logoPath,
    required this.showTime,
    required this.showAddress,
    required this.showMap,
    required this.showLogo,
    required this.showCoords,
    required this.showAltitude,
  });
}

class ImageProcessor {
  static const int mapW = 200;
  static const int mapH = 200;

  static Future<img.Image?> fetchStaticMap(
    double lat,
    double lon,
    String cacheDirPath,
  ) async {
    const zoom = 16;
    const tileSize = 256;

    double x = (lon + 180.0) / 360.0 * math.pow(2, zoom);
    double y =
        (1.0 -
            math.log(
                  math.tan(lat * math.pi / 180.0) +
                      1.0 / math.cos(lat * math.pi / 180.0),
                ) /
                math.pi) /
        2.0 *
        math.pow(2, zoom);

    int tileX = x.floor();
    int tileY = y.floor();
    int offsetX = ((x - tileX) * tileSize).toInt();
    int offsetY = ((y - tileY) * tileSize).toInt();

    final bigCanvas = img.Image(width: 768, height: 768);
    img.fill(bigCanvas, color: img.ColorRgb8(242, 241, 240));

    try {
      final mapCacheDir = Directory(join(cacheDirPath, 'map_tiles'));
      if (!await mapCacheDir.exists())
        await mapCacheDir.create(recursive: true);

      List<Future<void>> futures = [];
      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final tx = tileX + dx;
          final ty = tileY + dy;
          final tX = dx;
          final tY = dy;
          futures.add(() async {
            final tileId = "v16_${tx}_${ty}.png";
            final cacheFile = File(join(mapCacheDir.path, tileId));
            Uint8List? data;
            if (await cacheFile.exists()) {
              data = await cacheFile.readAsBytes();
            } else {
              final url =
                  "https://basemaps.cartocdn.com/rastertiles/voyager/$zoom/$tx/$ty.png";
              try {
                final res = await http
                    .get(
                      Uri.parse(url),
                      headers: {'User-Agent': 'MarkTimeApp/1.0'},
                    )
                    .timeout(const Duration(seconds: 10));
                if (res.statusCode == 200) {
                  data = res.bodyBytes;
                  await cacheFile.writeAsBytes(data);
                }
              } catch (_) {}
            }
            if (data != null) {
              final tile = img.decodeImage(data);
              if (tile != null) {
                img.compositeImage(
                  bigCanvas,
                  tile,
                  dstX: (tX + 1) * tileSize,
                  dstY: (tY + 1) * tileSize,
                );
              }
            }
          }());
        }
      }
      await Future.wait(futures);
      final cropX = (tileSize + offsetX) - (mapW ~/ 2);
      final cropY = (tileSize + offsetY) - (mapH ~/ 2);
      return img.copyCrop(
        bigCanvas,
        x: cropX,
        y: cropY,
        width: mapW,
        height: mapH,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _processImageIsolate(ImageProcessParams params) async {
    try {
      final mapFuture =
          (params.lat != null && params.lon != null && params.showMap)
          ? fetchStaticMap(params.lat!, params.lon!, params.cacheDirPath)
          : Future.value(null);

      final bytes = await File(params.path).readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);
      if (baseImage == null) return null;

      if (baseImage.width > baseImage.height) {
        baseImage = img.copyRotate(baseImage, angle: 90);
      }

      final int w = baseImage.width;
      final int h = baseImage.height;
      final mapImg = await mapFuture;

      if (params.showTime ||
          params.showAddress ||
          params.showMap ||
          params.showCoords ||
          params.showAltitude ||
          params.showLogo) {
        for (int i = 0; i < 480; i++) {
          img.fillRect(
            baseImage,
            x1: 0,
            y1: h - 480 + i,
            x2: w,
            y2: h - 480 + i + 1,
            color: img.ColorRgba8(0, 0, 0, (i / 480 * 180).toInt()),
          );
        }
      }

      img.drawString(
        baseImage,
        "Original Photo Verified",
        font: img.arial24,
        x: 50,
        y: 50,
        color: img.ColorRgb8(150, 150, 150),
      );

      // LOGO LÓGICA
      if (params.showLogo) {
        const logoTargetY = 485; // Ajustado para não colidir com o tempo
        if (params.logoPath != null && await File(params.logoPath!).exists()) {
          final logoData = await File(params.logoPath!).readAsBytes();
          final logoImg = img.decodeImage(logoData);
          if (logoImg != null) {
            // Logo Maior (75px de altura)
            final scaledLogo = img.copyResize(logoImg, height: 75);
            img.compositeImage(
              baseImage,
              scaledLogo,
              dstX: 50,
              dstY: h - logoTargetY,
            );
          }
        } else {
          // Placeholder Maior
          img.fillRect(
            baseImage,
            x1: 50,
            y1: h - 485,
            x2: 210,
            y2: h - 410,
            color: img.ColorRgb8(255, 255, 255),
          );
          img.drawRect(
            baseImage,
            x1: 50,
            y1: h - 485,
            x2: 210,
            y2: h - 410,
            color: img.ColorRgb8(0, 230, 118),
            thickness: 2,
          );
          img.drawString(
            baseImage,
            "LOGO",
            font: img.arial24,
            x: 80,
            y: h - 460,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }

      if (params.showTime) {
        img.drawString(
          baseImage,
          params.timeString,
          font: img.arial48,
          x: 50,
          y: h - 400,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.drawLine(
          baseImage,
          x1: 195,
          y1: h - 405,
          x2: 195,
          y2: h - 315,
          color: img.ColorRgb8(0, 230, 118),
          thickness: 8,
        );
        img.drawString(
          baseImage,
          params.dateString,
          font: img.arial24,
          x: 215,
          y: h - 395,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.drawString(
          baseImage,
          params.dayString.toUpperCase(),
          font: img.arial24,
          x: 215,
          y: h - 355,
          color: img.ColorRgb8(180, 180, 180),
        );
      }

      if (params.lat != null && params.showCoords) {
        img.drawString(
          baseImage,
          "${params.lat!.toStringAsFixed(6)}, ${params.lon!.toStringAsFixed(6)}",
          font: img.arial24,
          x: 50,
          y: h - 290,
          color: img.ColorRgb8(0, 230, 118),
        );
      }

      if (params.lat != null && params.showAltitude) {
        img.drawString(
          baseImage,
          "ALT: ${params.alt!.toStringAsFixed(1)}m ACC: ${params.acc!.toStringAsFixed(1)}m",
          font: img.arial24,
          x: 50,
          y: h - 250,
          color: img.ColorRgb8(180, 180, 180),
        );
      }

      if (params.showAddress) {
        final addrLines = params.address.split('\n');
        for (int i = 0; i < math.min(addrLines.length, 2); i++) {
          img.drawString(
            baseImage,
            addrLines[i],
            font: img.arial24,
            x: 50,
            y: h - 190 + (i * 40),
            color: img.ColorRgb8(255, 255, 255),
          );
        }
      }

      if (params.showMap) {
        final mapX = w - mapW - 60;
        final mapY = h - mapH - 60;
        img.fillRect(
          baseImage,
          x1: mapX - 6,
          y1: mapY - 6,
          x2: w - 54,
          y2: h - 54,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.drawRect(
          baseImage,
          x1: mapX - 1,
          y1: mapY - 1,
          x2: w - 59,
          y2: h - 59,
          color: img.ColorRgb8(0, 230, 118),
          thickness: 2,
        );
        if (mapImg != null) {
          img.compositeImage(baseImage, mapImg, dstX: mapX, dstY: mapY);
          final centerX = mapX + (mapW ~/ 2);
          final centerY = mapY + (mapH ~/ 2) - 10;
          img.fillCircle(
            baseImage,
            x: centerX,
            y: centerY,
            radius: 10,
            color: img.ColorRgb8(255, 0, 0),
          );
          img.fillCircle(
            baseImage,
            x: centerX,
            y: centerY,
            radius: 4,
            color: img.ColorRgb8(255, 255, 255),
          );
          img.drawLine(
            baseImage,
            x1: centerX - 9,
            y1: centerY + 4,
            x2: centerX,
            y2: centerY + 22,
            color: img.ColorRgb8(255, 0, 0),
            thickness: 2,
          );
          img.drawLine(
            baseImage,
            x1: centerX + 9,
            y1: centerY + 4,
            x2: centerX,
            y2: centerY + 22,
            color: img.ColorRgb8(255, 0, 0),
            thickness: 2,
          );
        }
      }

      final destPath = join(
        params.tempDirPath,
        "final_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      await File(destPath).writeAsBytes(img.encodeJpg(baseImage, quality: 85));
      return destPath;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> processAndSaveImage({
    required String path,
    required Position? position,
    required String address,
    required String timeString,
    required String dateString,
    required String dayString,
    required Map<String, bool> settings,
    String? logoPath,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final appDocDir = await getApplicationDocumentsDirectory();

    final finalPath = await compute(
      _processImageIsolate,
      ImageProcessParams(
        path: path,
        lat: position?.latitude,
        lon: position?.longitude,
        alt: position?.altitude,
        acc: position?.accuracy,
        address: address,
        timeString: timeString,
        dateString: dateString,
        dayString: dayString,
        tempDirPath: tempDir.path,
        cacheDirPath: appDocDir.path,
        logoPath: logoPath,
        showTime: settings['showTime'] ?? true,
        showAddress: settings['showAddress'] ?? true,
        showMap: settings['showMap'] ?? true,
        showLogo: settings['showLogo'] ?? true,
        showCoords: settings['showCoords'] ?? true,
        showAltitude: settings['showAltitude'] ?? true,
      ),
    );

    if (finalPath != null) {
      await Gal.putImage(finalPath, album: "MarkTime");
      try {
        await File(path).delete();
      } catch (_) {}
    }
    return finalPath;
  }
}
