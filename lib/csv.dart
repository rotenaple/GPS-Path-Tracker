import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ParseCSV {
  String _pathName = "Unnamed Path";

  Future<(List<List<dynamic>>, String)> readCSV(String path, String source) async {
    String csvData = await _loadCSVData(path, source);
    final lines = csvData.split('\n');
    if (kDebugMode) {
      print(lines);
    }

    return (_processLines(lines), _pathName);
  }

  Future<String> _loadCSVData(String path, String source) async {
    if (source == "asset") {
      return await rootBundle.loadString(path);
    } else {
      final file = File(path);
      return await file.readAsString();
    }
  }

  List<List<dynamic>> _processLines(List<String> lines) {
    List<List<dynamic>> data = [];
    for (var line in lines) {
      if (_isPathNameLine(line)) {
        _pathName = line.substring(2).trim();
        continue;
      }

      if (_isCommentOrEmpty(line)) {
        continue;
      }

      var row = _processRow(line);
      if (row != null) {
        data.add(row);
      }
    }
    return data;
  }

  bool _isPathNameLine(String line) => line.trim().startsWith('##');

  bool _isCommentOrEmpty(String line) => line.trim().isEmpty || line.trim().startsWith('#');

  List<dynamic>? _processRow(String line) {
    List<dynamic> row = line.split(',');
    if (row.length >= 4) {
      return [
        row[0],
        double.tryParse(row[1]) ?? 0.0,
        double.tryParse(row[2]) ?? 0.0,
        double.tryParse(row[3]) ?? 0.0
      ];
    }
    return null;
  }

  Future<void> importCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      if (await _validateCSV(file)) {
        await _saveFileToAppDirectory(file);
      }
    }
  }

  Future<bool> _validateCSV(File file) async {
    final input = await file.readAsString();
    final lines = input.split('\n');

    for (var line in lines) {
      if (_isCommentOrEmpty(line)) {
        continue;
      }

      if (!_isValidCSVRow(line)) {
        return false;
      }
    }
    return true;
  }

  bool _isValidCSVRow(String line) {
    List<dynamic> row = line.split(',');
    return row.length == 4 &&
        _isValidDouble(row[1], -90, 90) &&
        _isValidDouble(row[2], -180, 180) &&
        _isValidDouble(row[3], 0, double.infinity);
  }

  bool _isValidDouble(String value, double min, double max) {
    double? val = double.tryParse(value);
    return val != null && val >= min && val <= max;
  }

  Future<void> _saveFileToAppDirectory(File file) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String baseFilePath = '${appDocDir.path}/${file.uri.pathSegments.last}';
    String newFilePath = baseFilePath;

    int counter = 2;
    while (File(newFilePath).existsSync()) {
      newFilePath = _appendNumberSuffix(baseFilePath, counter);
      counter++;
    }

    await file.copy(newFilePath);
  }

  String _appendNumberSuffix(String filePath, int counter) {
    String extension = filePath.substring(filePath.lastIndexOf('.'));
    String pathWithoutExtension = filePath.substring(0, filePath.lastIndexOf('.'));
    return '${pathWithoutExtension}_$counter$extension';
  }
}