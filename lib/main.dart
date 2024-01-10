import 'package:flutter/material.dart';
import 'dart:io';
import 'package:gps_path_tracker/location_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gps_path_tracker/pick_path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gps_path_tracker/time_provider.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _currentLocation = 'Fetching location...';
  double _currentSpeed = 0;
  double _linearDistance = 0.0;
  String _linearDistanceDisplay = "";
  double _estDistance = 0.0;
  String _estDistanceDisplay = "";
  List<List<dynamic>> nameLatLngSet = [];
  int _targetIndex = 1;
  LatLng _lastPoint = const LatLng(0, 0);
  LatLng _targetPoint = const LatLng(0, 0);
  String _targetStr = "";
  String _targetName = "";
  bool _manuallyIncremented = false;
  bool _buttonVisibility = false;

  final TimeController _timeController = TimeController();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await importData();
    _initLocationStream();
    await getTargetLatlong();
  }

  Future<void> importData() async {
    nameLatLngSet = await ReadCSV().readCSV('assets/pathdata.csv', "asset");
  }

  Future<void> importCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);

      final input = await file.readAsString();
      final lines = input.split('\n');
      bool csvNoErrors = true;

      for (var line in lines) {
        if (line.trim().isEmpty || line.trim().startsWith('#')) {
          continue;
        }

        List<dynamic> row = line.split(',');
        if (row.length != 4 ||
            double.tryParse(row[1]) == null ||
            double.tryParse(row[1])! < -90 ||
            double.tryParse(row[1])! > 90 ||
            double.tryParse(row[2]) == null ||
            double.tryParse(row[2])! < -180 ||
            double.tryParse(row[2])! > 180 ||
            double.tryParse(row[3]) == null ||
            double.tryParse(row[3])! < 0) {
          csvNoErrors = false;
          break;
        }
      }

      if (csvNoErrors) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String appDocPath = appDocDir.path;
        final String newFilePath = '$appDocPath/${file.uri.pathSegments.last}';
        await file.copy(newFilePath);
      }
    }
  }

  void _initLocationStream() {
    _locationService.initLocationStream((latitude, longitude, speed) {
      setState(() {
        _currentLocation = '$latitude, $longitude';
        _currentSpeed = speed;
        _manuallyIncremented = false;
        _updateDisplayInfo();
      });
    });
  }

  Future<void> getTargetLatlong() async {
    if (shouldFetchTargetLatlong()) {
      forceFetchTargetLatlong();
    }
  }

  bool shouldFetchTargetLatlong() {
    return nameLatLngSet.length > 2 && _linearDistance < 1000;
  }

  Future<void> forceFetchTargetLatlong() async {
    _lastPoint = LatLng(
        nameLatLngSet[_targetIndex - 1][1], nameLatLngSet[_targetIndex - 1][2]);
    _targetPoint =
        LatLng(nameLatLngSet[_targetIndex][1], nameLatLngSet[_targetIndex][2]);
    _targetStr =
        '${nameLatLngSet[_targetIndex][1].toStringAsFixed(7)}, ${nameLatLngSet[_targetIndex][2].toStringAsFixed(7)}';
    _targetName = nameLatLngSet[_targetIndex][0];
  }

  void _updateDisplayInfo() {
    _calculateDistanceDisplay();
    _calculateSpeedDisplay();
    _calculateEtaDisplay();
  }

  String _calculateDistanceDisplay() {
    const distance = Distance();
    String unit = "m";
    double distanceRatio = 0.0;
    _linearDistance = distance(_locationService.currentCentre, _targetPoint);
    double linearPTPDistance = distance(_lastPoint, _targetPoint);
    double actualPTPDistance = nameLatLngSet[_targetIndex][3];
    if (actualPTPDistance != 0) {
      distanceRatio = actualPTPDistance / linearPTPDistance;
      if (distanceRatio < 1) distanceRatio = 1;
    }

    _estDistance = _linearDistance * distanceRatio;

    if (_targetIndex < nameLatLngSet.length - 1 &&
        distance(_lastPoint, _targetPoint) <
            distance(_lastPoint, _locationService.currentCentre)) {
      if (_manuallyIncremented == false) {
        _targetIndex++;
      }
      getTargetLatlong();
    }

    if (_linearDistance >= 1000) {
      _linearDistanceDisplay = (_linearDistance / 1000).toStringAsFixed(2);
      _estDistanceDisplay = (_estDistance / 1000).toStringAsFixed(2);
      unit = 'km';
    } else {
      _linearDistanceDisplay = (_linearDistance).toStringAsFixed(0);
      _estDistanceDisplay = (_estDistance).toStringAsFixed(0);
    }
    _estDistanceDisplay = '$_estDistanceDisplay$unit';
    return '$_linearDistanceDisplay$unit';
  }

  String _calculateSpeedDisplay() {
    return "${_currentSpeed.toStringAsFixed(1)}km/h";
  }

  String _calculateEtaDisplay() {
    if (_currentSpeed > 0.0) {
      return GetFutureTime()
          .getFutureTime((_linearDistance / _currentSpeed * 3.6).toInt());
    } else {
      return "N/A";
    }
  }

  void _updateIndex(String select) {
    setState(() {
      switch (select) {
        case "increment":
          if (_targetIndex < nameLatLngSet.length - 1) {
            _targetIndex++;
          }
          break;
        case "decrement":
          if (_targetIndex > 1) {
            _targetIndex--;
          }
          break;
        case "nearest":
          _targetIndex = findNextCheckpoint();
          break;
      }

      _manuallyIncremented = true;
    });

    forceFetchTargetLatlong();
    _updateDisplayInfo();
  }

  int findNextCheckpoint() {
    // This code finds the 2 nearest checkpoints, then selects the one higher in index.
    // This assumes a relatively equal spacing of checkpoints,
    // and therefore the 2 found points are the previous and next checkpoints.
    // May not work if the spacing of checkpoints are too irregular.

    if (nameLatLngSet.length < 2) {
      return 1;
    }

    List<double> distances = [];
    LatLng currentLoc = _locationService.currentCentre;

    for (var point in nameLatLngSet) {
      const distance = Distance();
      LatLng checkpoint = LatLng(point[1], point[2]);
      double distanceToCurrent = distance(currentLoc, checkpoint);
      distances.add(distanceToCurrent);
    }

    List<int> sortedIndexes = List.generate(distances.length, (i) => i);
    sortedIndexes.sort((a, b) => distances[a].compareTo(distances[b]));

    return sortedIndexes[0] > sortedIndexes[1]
        ? sortedIndexes[0]
        : sortedIndexes[1];
  }

  void _toggleNavButtonVisibility() async {
    setState(() {
      _buttonVisibility = !_buttonVisibility;
    });

    //Popup confirmation not functional, throws "No MaterialLocalizations Found" error

    /*final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text('Are you sure you want to toggle?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            )
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _buttonVisibility = !_buttonVisibility;
      });
    }*/
  }

  void processSelectedPath(String path) async {
    // Process the file at the given path
    // For example, read the CSV, update the state, etc.
    var newData = await ReadCSV().readCSV(path, "path");
    setState(() {
      nameLatLngSet = newData;
      _targetIndex = 1;
    });
    forceFetchTargetLatlong();
    _updateDisplayInfo();
  }

  @override
  Widget build(BuildContext context) {
    bool isHorizontal =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
              backgroundColor: Colors.white,
              drawer: _buildDrawer(),
              body: Stack(
                children: [
                  _buildMenuIcon(),
                  Flex(
                    direction: isHorizontal ? Axis.horizontal : Axis.vertical,
                    children: [
                      Flexible(
                        flex: isHorizontal ? 1 : 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Visibility(
                              visible: isHorizontal ? false : true,
                              child: const SizedBox(
                                height: 125,
                                width: 200,
                              ),
                            ),
                            _buildTimeDisplay(),
                          ],
                        ),
                      ),
                      Flexible(
                        flex: isHorizontal ? 2 : 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 25, 20, 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildNextCheckpointDisplay(),
                              _buildCurrentStatsDisplay(),
                              _buildButtonDisplay(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ));
        },
      ),
    );
  }

  Widget _buildMenuIcon() {
    return Builder(
      builder: (BuildContext context) {
        return Positioned(
          top: 40,
          left: 16,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(
                Icons.menu,
                color: Color(0xff000000),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Builder(
      builder: (context) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                  ),
                  child: _buildDrawerHeader()),
              ListTile(
                leading: const Icon(Icons.file_copy),
                title: const Text('Import Custom Path File'),
                onTap: () {
                  importCSV();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_location),
                title: const Text('Choose a Path'),
                onTap: () async {
                  Navigator.pop(context);
                  final selectedPath = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PickPath()),
                  );
                  if (selectedPath != null) {
                    processSelectedPath(selectedPath);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Toggle Manual Checkpoint Selection'),
                onTap: () {
                  _toggleNavButtonVisibility();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPS Path Tracker',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'for Flinders University, \nWorld Solar Challenge',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDisplay() {
    return SizedBox(
      width: 200,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_timeController.getFormattedTime(),
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 48)),
          const Text("CURRENTLY AT",
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
          Text(_currentLocation,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNextCheckpointDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      child: Container(
        width: 200,
        height: 100,
        decoration: BoxDecoration(
            color: const Color(0x1f000000),
            border: Border.all(color: const Color(0x4d9e9e9e), width: 1)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("NEXT CHECKPOINT",
                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
            Text(_targetName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 24)),
            Text(_targetStr,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatsDisplay() {
    return Padding(
        padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
        child: Container(
          width: 200,
          height: 100,
          decoration: BoxDecoration(
              color: const Color(0x1f000000),
              border: Border.all(color: const Color(0x4d9e9e9e), width: 1)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 12, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SPEED",
                        style: TextStyle(
                            fontWeight: FontWeight.w400, fontSize: 14)),
                    Text("LINEAR DIST.",
                        style: TextStyle(
                            fontWeight: FontWeight.w400, fontSize: 14)),
                    Text("EST. DIST.",
                        style: TextStyle(
                            fontWeight: FontWeight.w400, fontSize: 14)),
                    Text("EST. ARRIVAL TIME",
                        style: TextStyle(
                            fontWeight: FontWeight.w400, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_calculateSpeedDisplay(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_calculateDistanceDisplay(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_estDistanceDisplay,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_calculateEtaDisplay(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildButtonDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 15),
      child: Visibility(
          visible: _buttonVisibility,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              MaterialButton(
                onPressed: () {
                  _updateIndex("decrement");
                },
                color: Colors.blue,
                child:
                    const Text('PREV', style: TextStyle(color: Colors.white)),
              ),
              MaterialButton(
                onPressed: () {
                  _updateIndex("nearest");
                },
                color: Colors.blue,
                child: const Text('FIND NEAREST',
                    style: TextStyle(color: Colors.white)),
              ),
              MaterialButton(
                onPressed: () {
                  _updateIndex("increment");
                },
                color: Colors.blue,
                child:
                    const Text('NEXT', style: TextStyle(color: Colors.white)),
              ),
            ],
          )),
    );
  }
}
