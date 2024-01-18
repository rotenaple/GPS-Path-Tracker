import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ParseCSV {
  String _pathName = 'Unnamed Path';

  Future<(List<List<dynamic>>, String)> readCSV(String source,
      {String path = "", String content = ""}) async {
    String csvData = "";

    switch (source) {
      case "asset":
        {
          csvData = await rootBundle.loadString(path);
        }
        break;
      case "path":
        {
          csvData = await File(path).readAsString();
        }
        break;
      case "string":
        {
          csvData = content;
        }
        break;
    }

    final lines = csvData.split('\n');
    if (kDebugMode) {
      print(lines);
    }
    return (_processLines(lines), _pathName);
  }

  List<List<dynamic>> _processLines(List<String> lines) {
    var data = <List<dynamic>>[];
    for (var line in lines) {
      if (_isPathNameLine(line)) {
        _pathName = line.substring(2).trim();
        continue;
      }
      if (_isCommentOrEmpty(line)) continue;
      var row = _processRow(line);
      if (row != null) data.add(row);
    }
    return data;
  }

  bool _isPathNameLine(String line) => line.trim().startsWith('##');
  bool _isCommentOrEmpty(String line) =>
      line.trim().isEmpty || line.trim().startsWith('#');

  List<dynamic>? _processRow(String line) {
    var row = line.split(',');
    if (row.length >= 4) {
      return [
        row[0],
        double.tryParse(row[1]) ?? 0.0,
        double.tryParse(row[2]) ?? 0.0,
        double.tryParse(row[3]) ?? 0.0,
      ];
    }
    return null;
  }

  Future<(int, int, String, String)> importCSV() async {
    if (!kIsWeb) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      File file = File(result!.files.single.path!);
      (bool, int, int, String) returnVal = await _validateCSV(true, file: file);

      if (returnVal.$1) {
        await _saveFileToAppDirectory(file);
        await _clearCache(file);
        return (-1, -1, "", "");
      } else {
        return (returnVal.$2, returnVal.$3, returnVal.$4, "");
      }
    } else {
      FilePickerResult? file =
          await FilePicker.platform.pickFiles(type: FileType.any);

      if (file == null) {
        return (-2, -2, "Aborted", ""); // Specific value for aborted operation
      }

      if (file != null) {
        PlatformFile pickedFile = file.files.first;

        if (pickedFile.bytes != null) {
          String fileContents = utf8.decode(pickedFile.bytes!);
          print("File contents: $fileContents");
          (bool, int, int, String) returnVal =
              await _validateCSV(false, content: fileContents);

          if (returnVal.$1) {

            return (-1, -1, "", fileContents);
          } else {
            return (returnVal.$2, returnVal.$3, returnVal.$4, "");
          }
        }
      }
    }

    return (-1, -1, "", "");
  }

  Future<void> _clearCache(File file) async {
    try {
      String cachedFilePath = file.path;

      if (await File(cachedFilePath).exists()) {
        await File(cachedFilePath).delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  Future<(bool, int, int, String)> _validateCSV(bool isFile,
      {File? file, String? content}) async {
    String input = "";

    if (isFile)
      input = (await file?.readAsString())!;
    else
      input = content!;

    final lines = input.split('\n');
    int index = 0;

    for (var line in lines) {
      if (_isCommentOrEmpty(line)) continue;

      (bool, int) errorLocationColumn = _isValidCSVRow(line);

      if (!errorLocationColumn.$1) {
        int errorLocationRow = index;
        return (false, errorLocationRow, errorLocationColumn.$2, line);
      }

      index++;
    }
    return (true, -1, -1, "");
  }

  (bool, int) _isValidCSVRow(String line) {
    List<dynamic> row = line.split(',');

    if (row.length != 4) {
      return (false, 0);
    }

    if (!_isValidDouble(row[1], -90, 90)) {
      return (false, 1);
    }

    if (!_isValidDouble(row[2], -180, 180)) {
      return (false, 2);
    }

    if (!_isValidDouble(row[3], 0, double.infinity)) {
      return (false, 3);
    }

    return (true, -1);
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
    String pathWithoutExtension =
        filePath.substring(0, filePath.lastIndexOf('.'));
    return '${pathWithoutExtension}_$counter$extension';
  }
}
