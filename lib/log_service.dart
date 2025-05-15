import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogService {
  Future<String> _getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${directory.path}/app_log_$dateString.txt';
  }

  Future<void> _cleanOldLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync().where((entity) => entity is File && entity.path.contains('app_log_'));

    final sortedFiles = files.map((file) => file as File).toList()
      ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    if (sortedFiles.length > 7) {
      for (var i = 0; i < sortedFiles.length - 7; i++) {
        await sortedFiles[i].delete();
      }
    }
  }

  Future<void> writeLogToFile(String logMessage) async {
    try {
      final filePath = await _getLogFilePath();
      final file = File(filePath);

      if (!(await file.exists())) {
        await file.create();
      }

      await file.writeAsString('$logMessage\n', mode: FileMode.append);
      print('Log berhasil ditulis ke file: $filePath');

      await _cleanOldLogs();
    } catch (e) {
      print('Gagal menulis log ke file: $e');
    }
  }

  void logMessage(String message) {
    print(message); 
    writeLogToFile(message); 
  }
}