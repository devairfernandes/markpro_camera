import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // CONFIGURALÇÃO REAL PARA DEV AIR FERNANDES
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Mudanças:"),
            Text(
              changelog,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Depois"),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              try {
                // Tenta abrir o navegador diretamente
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                // Fallback: se falhar o externalApplication, tenta o padrão
                try {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Não foi possível abrir o link de download.",
                        ),
                      ),
                    );
                  }
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text("Atualizar"),
          ),
        ],
      ),
    );
  }
}
