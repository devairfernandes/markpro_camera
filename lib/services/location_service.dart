import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  /// Solicita as permissões de localização de forma explícita.
  /// Deve ser chamado no início do app, antes de tentar obter a posição.
  static Future<bool> requestPermissions() async {
    // Usar permission_handler para garantir que o diálogo apareça na 1ª abertura
    final status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      return false;
    }
    return true;
  }

  /// Verifica se o GPS (serviço de localização) está ativado no dispositivo.
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Verifica se a permissão de localização está concedida.
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Obtém a posição atual com tratamento completo de erros.
  /// Retorna null se o serviço estiver desativado ou a permissão negada.
  static Future<Position?> getCurrentPosition() async {
    // 1. Verificar se o GPS está ligado
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Serviço de localização desativado.');
      return null;
    }

    // 2. Verificar / solicitar permissão
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permissão de localização negada.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permissão de localização negada permanentemente.');
      return null;
    }

    // 3. Obter posição
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Erro ao obter posição: $e");
      return null;
    }
  }

  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.street}, ${place.name} - ${place.subLocality}\n${place.locality}, ${place.subAdministrativeArea} - ${place.administrativeArea},\n${place.postalCode}";
      }
    } catch (e) {
      debugPrint("Erro ao obter endereço: $e");
    }
    return "Endereço não encontrado";
  }

  static String formatPosition(Position pos) {
    return "LAT: ${pos.latitude.toStringAsFixed(6)}  LNG: ${pos.longitude.toStringAsFixed(6)}";
  }
}
