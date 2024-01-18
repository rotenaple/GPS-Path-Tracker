import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_path_tracker/theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

late PermissionStatus permissionStatus;
bool permissionNotGranted = false;


class LocationService {
  LatLng currentCentre = const LatLng(0, 0);
  double currentSpeed = 0.0;

  Future<void> initLocationStream(Function(double, double, double) onLocationUpdate) async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
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

  Future<void> checkLocationPermission(BuildContext context) async {
    PermissionStatus permissionStatus = PermissionStatus.granted;
    if (!Platform.isWindows) {
      permissionStatus = await Permission.location.request();

<<<<<<< Updated upstream
      if (!permissionStatus.isGranted) {
        permissionNotGranted = true;
      }
    }
    if (kDebugMode) {
      print("permissionStatus");
      print(permissionStatus);
    }
  }
=======
      locationServiceEnabled = await Geolocator.isLocationServiceEnabled();

      //if (!kIsWeb) {
        LocationPermission permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          locationPermissionGranted = false;
        }
      /*} else {
        PermissionStatus permission2 = await Permission.location.request();
        if (permission2 != PermissionStatus.granted) {
          locationPermissionGranted = false;
        }
      }*/

    if (kDebugMode) {
        print("locationServiceEnabled: $locationServiceEnabled");
        print("locationPermissionGranted: $locationPermissionGranted");
      }

      if (locationServiceEnabled && locationPermissionGranted){
        return "";
      } else {
        permissionFail = true;
      }

      String platform = ReturnOS().returnOS();

      if (platform == "android") {
        if (!locationServiceEnabled) return "LocationService";
        else return "Permission";}
        else if (platform == "windows") return "Windows";
        else return "Default";
      }

>>>>>>> Stashed changes
}
