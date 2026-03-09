import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Testar se os serviços de localização estão ativos.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Os serviços de localização estão desativados.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permissões de localização negadas.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('As permissões de localização foram negadas permanentemente.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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
