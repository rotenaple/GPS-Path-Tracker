import 'dart:async';
import 'package:intl/intl.dart';

class TimeUpdater {
  Stream<DateTime> getTimeStream() {
    return Stream<DateTime>.periodic(
      Duration(seconds: 15),
          (count) => DateTime.now(),
    );
  }
}

class TimeModel {
  String formattedTime = DateFormat.Hm().format(DateTime.now());
}

class TimeController {
  final TimeUpdater _updater = TimeUpdater();
  final TimeModel _model = TimeModel();
  late Stream<DateTime> timeStream;

  TimeController() {
    timeStream = _updater.getTimeStream();
    timeStream.listen((time) {
      _model.formattedTime = DateFormat.Hm().format(time);
    });
  }

  String getFormattedTime() {
    return _model.formattedTime;
  }
}

/*class GetFutureTime {
  String getFutureTime(int secondsToAdd) {
    final currentTime = DateTime.now();
    final futureTime = currentTime.add(Duration(seconds: secondsToAdd));
    return DateFormat.Hm().format(futureTime);
  }
}

Currently Borked*/
