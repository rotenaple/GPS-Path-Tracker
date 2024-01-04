import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:gps_path_tracker/location_service.dart';
import 'package:gps_path_tracker/time_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _currentLocation = 'Fetching location...';
  double _currentSpeed = 0;
  double _linearDistance = 0.0;
  String _linearDistanceDisplay = "";
  List<List<dynamic>> nameLatLngSet = [
    ['University0', -35.0071618, 138.5727096],
    ['University1', -35.0090055, 138.5729734],
    ['University2', -35.0082896, 138.5688693],
  ];

  int _targetIndex = 1;
  LatLng _lastPoint = LatLng(0, 0);
  LatLng _targetPoint = LatLng(0, 0);
  String _targetStr = "";
  String _targetName = "";


  void initializeTarget() {
    _lastPoint = LatLng(nameLatLngSet[_targetIndex-1][1], nameLatLngSet[_targetIndex-1][2]);
    _targetPoint = LatLng(nameLatLngSet[_targetIndex][1], nameLatLngSet[_targetIndex][2]);
    print("target name");
    print(_targetPoint);
    _targetStr = '${nameLatLngSet[_targetIndex][1]}, ${nameLatLngSet[_targetIndex][2]}';
    _targetName = nameLatLngSet[_targetIndex][0];
  }

  final TimeController _timeController = TimeController();
  LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initLocationStream();
    initializeTarget();
  }

  void _initLocationStream() {
    _locationService.initLocationStream((latitude, longitude, speed) {
      setState(() {
        _currentLocation = '$latitude, $longitude';
        _currentSpeed = speed;
        _calculateDistanceDisplay();
        _calculateSpeedDisplay();
        _calculateEtaDisplay();
      });
    });
  }

  String _calculateDistanceDisplay() {
    final distance = Distance();
    String unit = "m";
    _linearDistance = distance(_locationService.currentCentre, _targetPoint);
    // Calculate distance to next checkpoint

    if (distance(_lastPoint,_targetPoint)
        <distance(_lastPoint,_locationService.currentCentre))
      {_targetIndex++;}

    if (_linearDistance >= 1000) {
      _linearDistanceDisplay = (_linearDistance / 1000).toStringAsFixed(2);
      unit = 'km';
    } else {
      _linearDistanceDisplay = (_linearDistance).toStringAsFixed(0);
    }
    return '$_linearDistanceDisplay$unit';
  }

  String _calculateSpeedDisplay() {
    return _currentSpeed.toStringAsFixed(1) + "km/h";
  }

  String _calculateEtaDisplay() {
    if (_currentSpeed > 0.0) {
      return  GetFutureTime().getFutureTime((_linearDistance / _currentSpeed * 3.6).toInt());
    } else {return "N/A";}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 200,
                  height: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        _timeController.getFormattedTime(),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 48,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            "CURRENTLY AT",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currentLocation,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0x1f000000),
                    border: Border.all(color: Color(0x4d9e9e9e), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "NEXT CHECKPOINT",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _targetName,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        _targetStr,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Color(0x1f000000),
                    border: Border.all(color: Color(0x4d9e9e9e), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(0, 0, 12, 0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text(
                                  "SPEED",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "EST. DISTANCE",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "EST. ARRIVAL TIME",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                _calculateSpeedDisplay(),
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _calculateDistanceDisplay(),
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _calculateEtaDisplay(),
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}