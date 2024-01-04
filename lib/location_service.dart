import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  LatLng currentCentre = LatLng(0, 0);
  double currentSpeed = 0.0;

  Future<void> initLocationStream(Function(double, double, double) onLocationUpdate) async {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );


      Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position? position) {
          if (position != null) {
            currentCentre = LatLng(position.latitude, position.longitude);
            double speedFiltered = 0;
            if (position.speed * 3.6 < 0.1) {
              speedFiltered = 0;
            } else {
              speedFiltered = position.speed * 3.6;
            }
            onLocationUpdate(position.latitude, position.longitude, speedFiltered);

            // Speed currently only updates when location is updated, will not reset to 0 when stationary.
          }
        },
      );

  }

  Future<void> requestLocationPermission() async {
    final permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
    } else if (permissionStatus.isDenied) {
    } else if (permissionStatus.isPermanentlyDenied) {
      openAppSettings();
    }
  }
}
