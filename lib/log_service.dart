import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogService {
  Future<void> writeLogToFile(String logMessage) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/app_log.txt';
      final file = File(filePath);

      if (!(await file.exists())) {
        await file.create();
      }

      await file.writeAsString('$logMessage\n', mode: FileMode.append);
      print('Log berhasil ditulis ke file: $filePath');
    } catch (e) {
      print('Gagal menulis log ke file: $e');
    }
  }

  void logMessage(String message) {
    print(message); 
    writeLogToFile(message); 
  }
}
