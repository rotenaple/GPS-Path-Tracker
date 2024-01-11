import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gps_path_tracker/location_service.dart';
import 'package:gps_path_tracker/pick_path.dart';
import 'package:gps_path_tracker/time_provider.dart';
import 'package:gps_path_tracker/csv.dart';
import 'package:gps_path_tracker/theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey();
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
  String _pathName = "";
  bool _manuallyIncremented = false;
  bool _buttonVisibility = false;
  String _isLoading = "true";
  bool _manualWarning = true;
  String loadStatus = "";

  final TimeController _timeController = TimeController();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    importData();
    await LocationService().checkLocationPermission(context);
    if (!permissionNotGranted) {
      _initLocationStream();
      getTargetLatlong();
    } else {
      setState(() {
        _isLoading = "failed";
      });
    }
  }

  Future<void> importData() async {
    var returnValue = await ParseCSV().readCSV('assets/pathdata.csv', "asset");
    nameLatLngSet = returnValue.$1;
    _pathName = returnValue.$2;
    _isLoading = "false";
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
    _targetName = "$_targetIndex ${nameLatLngSet[_targetIndex][0]}";
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
          .getFutureTime((_estDistance / _currentSpeed * 3.6).toInt());
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
  }

  void processSelectedPath(String path) async {
    var returnValue = await ParseCSV().readCSV(path, "path");
    var newData = returnValue.$1;
    _pathName = returnValue.$2;
    setState(() {
      nameLatLngSet = newData;
      _targetIndex = 1;
    });
    forceFetchTargetLatlong();
    _updateDisplayInfo();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => _isLoading == "true"
            ? _buildLoading()
            : _isLoading == "failed"
                ? _buildFailed()
                : _buildUIFramework(context),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColour,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: AppTheme.primaryColour,
                ),
              ),
            ),
            Text(
              "Loading",
              style: TextStyle(color: AppTheme.textColour),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.warning,
              color: AppTheme.warningColour,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                'Permission to use precise location is required for this app to function properly.',
                textAlign: TextAlign.center,
                style: AppTheme.dialogContentStyle,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
                exit(0);
              },
              style: AppTheme.primaryButtonStyle,
              child: const Text('OPEN SETTINGS',
                  style: AppTheme.dialogButtonStyle),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                exit(0);
              },
              style: AppTheme.primaryButtonStyle,
              child: const Text('QUIT APP', style: AppTheme.dialogButtonStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUIFramework(BuildContext context) {
    bool isHorizontal =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColour,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _buildTopLeftMenuIcon(),
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
                      visible: !isHorizontal,
                      child: const SizedBox(
                        height: 92,
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
                      _buildNavButtonDisplay(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopLeftMenuIcon() {
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
                color: AppTheme.textColour,
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
            child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColour,
                    ),
                    child: _buildDrawerHeader(),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.file_copy,
                      color: AppTheme.iconColor,
                    ),
                    title: const Text(
                      'Import Custom Path File',
                      style: AppTheme.listItemTextStyle,
                    ),
                    onTap: () async {
                      Future<(int, int, String)> result;
                      result = ParseCSV().importCSV();
                      (int, int, String) actualResult = await result;
                      Navigator.pop(context);

                      if (actualResult.$1 != -1) {
                        AppTheme.showSnackbar(context,
                            "File Not Imported \nFormat error in line ${actualResult.$1 + 1}, column ${actualResult.$2 + 1}\n${actualResult.$3}");
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.add_location,
                      color: AppTheme.iconColor,
                    ),
                    title: const Text(
                      'Choose a Path',
                      style: AppTheme.listItemTextStyle,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final selectedPath = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PickPath()),
                      );
                      processSelectedPath(selectedPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      color: AppTheme.iconColor,
                    ),
                    title: const Text(
                      'Toggle Manual Checkpoint Selection',
                      style: AppTheme.listItemTextStyle,
                    ),
                    onTap: () {
                      _toggleNavButtonVisibility();
                      Navigator.pop(context);
                      if (_manualWarning == true) {
                        AppTheme.showSnackbar(
                            context,
                            'App usually auto-updates checkpoints, '
                            'manual selection is only advised if over 1km past current point. '
                            '\'Find Nearest\' may not always be precise.');
                        _manualWarning = false;
                      }
                    },
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'by rotenaple & yuwei95123, 2024',
                style: AppTheme.creditTextStyle,
              ),
            ),
          ],
        ));
      },
    );
  }

  Widget _buildDrawerHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPS Path Tracker',
          style: AppTheme.headerStyle,
        ),
        Text(
          'for Flinders University, \nWorld Solar Challenge',
          style: AppTheme.subtitleStyle,
        ),
      ],
    );
  }

  Widget _buildTimeDisplay() {
    return SizedBox(
      width: 200,
      height: 140,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _timeController.getFormattedTime(),
            style: AppTheme.h1,
          ),
          Text(
            _pathName.toUpperCase(),
            style: AppTheme.boldTextStyle,
          ),
          const SizedBox(width: 200, height: 2),
          const Text(
            "CURRENTLY AT",
            style: AppTheme.normalTextStyle,
          ),
          Text(
            _currentLocation,
            style: AppTheme.boldTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildNextCheckpointDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      child: AppTheme.styledContainer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("NEXT CHECKPOINT", style: AppTheme.normalTextStyle),
            Text(
              _targetName,
              style: AppTheme.h2,
              textAlign: TextAlign.center,
            ),
            Text(_targetStr, style: AppTheme.boldTextStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatsDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 15),
      child: AppTheme.styledContainer(
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
                  Text("SPEED", style: AppTheme.normalTextStyle),
                  Text("LINEAR DIST.", style: AppTheme.normalTextStyle),
                  Text("EST. DIST.", style: AppTheme.normalTextStyle),
                  Text("EST. ARRIVAL TIME", style: AppTheme.normalTextStyle),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_calculateSpeedDisplay(), style: AppTheme.boldTextStyle),
                Text(_calculateDistanceDisplay(),
                    style: AppTheme.boldTextStyle),
                Text(_estDistanceDisplay, style: AppTheme.boldTextStyle),
                Text(_calculateEtaDisplay(), style: AppTheme.boldTextStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButtonDisplay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 5, 0, 15),
      child: Visibility(
        visible: _buttonVisibility,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _updateIndex("decrement"),
              style: AppTheme.primaryButtonStyle,
              child: const Text('PREV'),
            ),
            ElevatedButton(
              onPressed: () => _updateIndex("nearest"),
              style: AppTheme.primaryButtonStyle,
              child: const Text('FIND NEAREST'),
            ),
            ElevatedButton(
              onPressed: () => _updateIndex("increment"),
              style: AppTheme.primaryButtonStyle,
              child: const Text('NEXT'),
            )
          ],
        ),
      ),
    );
  }
}
