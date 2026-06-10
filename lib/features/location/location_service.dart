import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  Future<bool> openNearbySupportCenters() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse(
        'https://www.google.com/maps/search/logoped/@${position.latitude},${position.longitude},14z',
      );

      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      )) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}