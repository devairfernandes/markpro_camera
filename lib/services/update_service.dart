import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  // CONFIGURACAO REAL PARA DEV AIR FERNANDES
  static const String _repoUrl =
      "https://raw.githubusercontent.com/devairfernandes/markpro_camera/main/version.json";

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      final response = await http
          .get(Uri.parse(_repoUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String latestVersion = data['version'] ?? "1.0.0";
        final String changelog = data['changelog'] ?? "Nova versão disponível!";
        final String downloadUrl =
            data['download_url'] ??
            "https://github.com/devairfernandes/markpro_camera/releases/latest";

        final packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;

        if (_isNewer(latestVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, changelog, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao verificar atualizações: $e");
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      List<int> latestParts = latest.split('.').map(int.parse).toList();
      List<int> currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String changelog,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.system_update_alt, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text("Nova Versão!"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MarkPro Camera v$version",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            const Text(
              "O que há de novo:",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              changelog,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("DEPOIS", style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(context, downloadUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("ATUALIZAR AGORA"),
          ),
        ],
      ),
    );
  }

  static void _startUpdate(BuildContext context, String url) {
    double progress = 0;
    String status = "Iniciando download...";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          try {
            OtaUpdate()
                .execute(url, destinationFilename: 'markpro_update.apk')
                .listen((OtaEvent event) {
                  setModalState(() {
                    switch (event.status) {
                      case OtaStatus.DOWNLOADING:
                        status = "Baixando atualização...";
                        progress = double.tryParse(event.value!) ?? 0;
                        break;
                      case OtaStatus.INSTALLING:
                        status = "Pronto para instalar!";
                        progress = 100;
                        // O Android deve abrir o instalador automaticamente aqui
                        break;
                      case OtaStatus.ALREADY_RUNNING_ERROR:
                        status = "Atualização já em curso.";
                        break;
                      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                        status = "Permissão negada.";
                        break;
                      case OtaStatus.INTERNAL_ERROR:
                      case OtaStatus.DOWNLOAD_ERROR:
                      case OtaStatus.CHECKSUM_ERROR:
                        status = "Erro no download: ${event.value}";
                        break;
                      default:
                        status = "Status: ${event.status}";
                    }
                  });

                  if (event.status == OtaStatus.INSTALLING) {
                    Future.delayed(const Duration(seconds: 2), () {
                      if (context.mounted) Navigator.pop(context);
                    });
                  }

                  if (event.status == OtaStatus.DOWNLOAD_ERROR ||
                      event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR ||
                      event.status == OtaStatus.INTERNAL_ERROR) {
                    Future.delayed(const Duration(seconds: 3), () {
                      if (context.mounted) Navigator.pop(context);
                    });
                  }
                });
          } catch (e) {
            setModalState(() {
              status = "Erro ao iniciar: $e";
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (context.mounted) Navigator.pop(context);
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Atualizando..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00E676),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  status,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (progress > 0)
                  Text(
                    "${progress.toInt()}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E676),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
