import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'log_service.dart';

class AppState extends ChangeNotifier {
  Timer? _timer;
  List<String> logMessages = [];
  final LogService logService = LogService();
  
  AppState() {
    _startOrderChecking();
  }

  void _startOrderChecking() {
    _timer = Timer.periodic(const Duration(seconds: 10), (Timer timer) {
      _checkOrders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isProcessing = false;

  Future<void> _checkOrders() async {
    if (_isProcessing) return;
    _isProcessing = true;

    final settings = ConnectionSettings(
      host: dotenv.env['DB_HOST']!,
      port: int.parse(dotenv.env['DB_PORT']!),
      user: dotenv.env['DB_USER']!,
      password: dotenv.env['DB_PASSWORD']!,
      db: dotenv.env['DB_NAME']!,
    );

    try {
      var conn = await MySqlConnection.connect(settings);

      int lastProcessedOdId = await _getLastProcessedOdId(conn);

      var orderResults = await conn.query(
        'SELECT * FROM order_history WHERE oh_id > ? AND oh_type = "Addition" ORDER BY oh_id',
        [lastProcessedOdId]
      );

      if (orderResults.isNotEmpty) {
        Set<int> processedOrderIds = {};

        for (var orderNewRow in orderResults) {
          var oh_id = orderNewRow['oh_id'];
          var o_id = orderNewRow['o_id'];
          var i_id = orderNewRow['i_id'];
          var t_id = orderNewRow['t_id'];
          var is_id = orderNewRow['is_id'];
          var oh_table_area = orderNewRow['oh_table_area'];
          var u_id = orderNewRow['u_id'];
          var oh_qty = (orderNewRow['oh_qty'] as double).toStringAsFixed(3);
          var oh_options = orderNewRow['oh_options'];
          var oh_desc = orderNewRow['oh_desc'];

          var userResults = await conn.query(
            'SELECT u_name FROM user WHERE u_id = ?', 
            [u_id],
          );
          var u_name = userResults.first['u_name'];

          var itemResults = await conn.query(
            'SELECT i_name FROM item WHERE i_id = ?', 
            [i_id],
          );
          var i_name = itemResults.first['i_name'];

          var tableResults = await conn.query(
            'SELECT t_name FROM tables WHERE t_id = ?', 
            [t_id],
          );
          var t_name = tableResults.first['t_name'];

          var existingOrderResults = await conn.query(
            'SELECT COUNT(*) as count FROM order_history WHERE o_id = ?',
            [o_id],
          );

          bool isTambahan = false;

          if (existingOrderResults.first['count'] > 0) {
            isTambahan = true; 
          }

          final config = await _readConfig();

          String? matchingPrinter;

          for (var printer in config.keys) {
            if (config[printer].contains(oh_options)) {
              matchingPrinter = printer;
              break; 
            }
          }

          if (matchingPrinter != null) {
            await insertLogPrint(conn, o_id, i_name, t_name, is_id, oh_table_area, u_id, u_name, oh_qty, oh_options, oh_desc, matchingPrinter, isTambahan);
      
            logService.logMessage('op_name $oh_options sesuai dengan config untuk printer $matchingPrinter');
          } else {
            logService.logMessage('op_name $oh_options tidak ditemukan di config.json untuk printer manapun.');
          }

          await _updateLastProcessedOdId(conn, oh_id);

          logService.logMessage('$u_name menginput $oh_qty order ${isTambahan ? 'TAMBAHAN' : 'BARU'} $i_name $oh_options di table $t_name $oh_table_area');

          processedOrderIds.add(o_id);          
        }
      }

      await conn.close();
    } catch (e) {
      logService.logMessage('Error during MySQL operation: $e');
      _addLog('Error during MySQL operation: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<int> _getLastProcessedOdId(MySqlConnection conn) async {
    var result = await conn.query(
      'SELECT c_value FROM config WHERE c_key = "ORDER_DETAIL_CHECK"'
    );

    if (result.isNotEmpty) {
      return int.parse(result.first['c_value']);
    }
    return 0;
  }

  Future<void> _updateLastProcessedOdId(MySqlConnection conn, int lastProcessedOdId) async {
    await conn.query(
      'UPDATE config SET c_value = ? WHERE c_key = "ORDER_DETAIL_CHECK"',
      [lastProcessedOdId.toString()]
    );
  }

  Future<void> insertLogPrint(MySqlConnection conn, int o_id, String i_name, String t_name, int is_id, String oh_table_area, int u_id, String u_name, String oh_qty, String oh_options, String? oh_desc, String? matchingPrinter, bool isTambahan) async {
    var currentTime = DateTime.now().toString().split('.')[0];
    var posId = dotenv.env['POS_ID']!;
    String tambahanText = isTambahan ? "[TAMBAHAN]\n" : "";
    String odDescText = (oh_desc != null && oh_desc.isNotEmpty) ? '- [C] $oh_desc' : '';

    String rtfMessageSource = '''{\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033{\\fonttbl{\\f0\\fnil FontB28;}{\\f1\\fnil FontA12;}{\\f2\\fnil Tahoma;}}
\\viewkind4\\uc1\\pard\\f0\\fs44 Table $t_name / $oh_table_area \\par
\\f1\\fs28 $tambahanText\\par
\\par

$matchingPrinter\\tab $currentTime\\par
================================\\par
[ ] $i_name x $oh_qty\\par
    - $oh_options\\par
    $odDescText\\par
\\par
POS / $u_name\\par
\\f2\\fs16\\par
}''';

    await conn.query(
      '''
      INSERT INTO log_print (o_id, ta_id, is_id, t_id, u_id, br_id, ts_id, lp_print_type, lp_title, 
      lp_message, lp_message_source, lp_printer_name, lp_print_counter, lp_count, lp_time, lp_ip, 
      pos_id, lp_printed, lp_rpm_printed, lp_loaded, lp_redirected, lp_delayed_print, lp_rpm_session) 
      VALUES (?, 0, ?, 0, ?, 0, 0, 'Order', ?, ?, ?, ?, 0, 1, ?, '192.168.110.23', ?, 
      "False", "False", "False", "False", "True", 'a5347f67')
      ''',
      [
        o_id, is_id, u_id, 'Table $t_name / $matchingPrinter', 
        'Table $t_name / $oh_table_area\n\n$tambahanText\n$matchingPrinter\t$currentTime\n=====================\n[ ] $i_name x $oh_qty\n - $oh_options\n $odDescText\n POS / $u_name\n',
        rtfMessageSource, matchingPrinter, currentTime, posId
      ],
    );
  logService.logMessage('$u_name menginput $oh_qty $i_name dengan opsi $oh_options ke printer: $matchingPrinter pada $currentTime');
  _addLog('$u_name menginput $oh_qty $i_name dengan opsi $oh_options ke printer: $matchingPrinter pada $currentTime');
  }

  Future<Map<String, dynamic>> _readConfig() async {
    final file = File('config.json');
    if (await file.exists()) {
      final contents = await file.readAsString();
      return jsonDecode(contents);
    } else {
      return {};
    }
  }

  void _addLog(String message) {
    if (logMessages.length >= 500) {
      logMessages.removeAt(0); 
    }
    logMessages.add(message);
    notifyListeners(); 
  }

  List<String> getLogs() {
    return logMessages;
  }
}
