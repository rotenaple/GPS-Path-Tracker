import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ReadCSV {
  String _pathName = "Unnamed Path";
  late (Future<List<List<dynamic>>>, int) record;


  Future<(List<List<dynamic>>, String)> readCSV(String path, String source) async {
    String csvData;
    if (source == "asset") {
      csvData = await rootBundle.loadString(path);
    } else {
      final file = File(path);
      csvData = await file.readAsString();
    }

    final lines = csvData.split('\n');
    if (kDebugMode) {
      print(lines);
    }

    List<List<dynamic>> data = [];
    for (var line in lines) {

      if (line.trim().startsWith('##')) {
        _pathName = line.substring(2).trim();
        continue;
      }

      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        continue;
      }

      List<dynamic> row = line.split(',');
      if (row.isNotEmpty && row.length >= 4) {
        row = [
          row[0],  // Assuming the first column is a String
          double.tryParse(row[1]) ?? 0.0,  // Latitude
          double.tryParse(row[2]) ?? 0.0,  // Longitude
          double.tryParse(row[3]) ?? 0.0   // Some other numeric value
        ];
        data.add(row);
      }
    }
    return (data,_pathName);
  }
}

class FileDetails {
  final File file;
  final DateTime addedDate;

  FileDetails(this.file, this.addedDate);
}

class PickPath extends StatelessWidget {
  Future<List<FileDetails>> listCsvFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    List<FileDetails> fileDetails = [];

    for (var fileEntity in files) {
      if (fileEntity.path.endsWith('.csv')) {
        File file = File(fileEntity.path);
        DateTime addedDate = await file.lastModified();
        fileDetails.add(FileDetails(file, addedDate));
      }
    }

    return fileDetails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose an Imported Path'),
      ),
      body: buildFileList(context),
    );
  }

  Widget buildFileList(BuildContext context) {
    return FutureBuilder<List<FileDetails>>(
      future: listCsvFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No CSV files found'));
        }
        final filesDetails = snapshot.data!;
        return ListView.builder(
          itemCount: filesDetails.length,
          itemBuilder: (context, index) {
            final fileDetail = filesDetails[index];
            final fileName = fileDetail.file.uri.pathSegments.last;
            return buildFileCard(fileDetail, fileName, context);
          },
        );
      },
    );
  }

  Widget buildFileCard(FileDetails fileDetail, String fileName, BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, fileDetail.file.path);
      },
      child: Card(
        child: buildListTile(fileDetail, fileName, context),
      ),
    );
  }

  ListTile buildListTile(FileDetails fileDetail, String fileName, BuildContext context) {
    final addedDate = DateFormat('dd MMM yyyy kk:mm').format(fileDetail.addedDate);
    return ListTile(
      leading: const Icon(Icons.map),
      title: Text(fileName),
      subtitle: Text(addedDate),
      trailing: buildTrailingIcons(fileDetail, context),
    );
  }

  Row buildTrailingIcons(FileDetails fileDetail, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDeleteButton(fileDetail, context),
      ],
    );
  }

  IconButton buildDeleteButton(FileDetails fileDetail, BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete File'),
            content: const Text('Are you sure you want to delete this file?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Cancel deletion
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await fileDetail.file.delete();
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }
}
