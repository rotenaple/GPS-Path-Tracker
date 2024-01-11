import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gps_path_tracker/theme.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class FileDetails {
  final File file;
  final DateTime addedDate;

  FileDetails(this.file, this.addedDate);
}

class PickPath extends StatelessWidget {
  const PickPath({super.key});

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
        title: const Text('Choose an Imported Path', style: AppTheme.h3,),
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
        color: AppTheme.flindersDust,
        child: buildListTile(fileDetail, fileName, context),
      ),
    );
  }

  ListTile buildListTile(FileDetails fileDetail, String fileName, BuildContext context) {
    final addedDate = DateFormat('dd MMM yyyy kk:mm').format(fileDetail.addedDate);
    return ListTile(
      leading: const Icon(Icons.map, color: AppTheme.iconColor),
      title: Text(fileName, style: AppTheme.listItemTextStyle),
      subtitle: Text(addedDate, style: AppTheme.listItemTextStyle),
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
      icon: const Icon(Icons.delete, color: AppTheme.iconColor), // Updated to use AppTheme
      onPressed: () => showDeleteDialog(fileDetail, context),
    );
  }

  void showDeleteDialog(FileDetails fileDetail, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File', style: AppTheme.dialogTitleStyle), // Update style
        content: const Text('Are you sure you want to delete this file?', style: AppTheme.dialogContentStyle), // Update style
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: AppTheme.dialogButtonStyle), // Update style
          ),
          TextButton(
            onPressed: () async {
              await fileDetail.file.delete();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: AppTheme.dialogAlertButtonStyle), // Update style
          ),
        ],
      ),
    );
  }
}