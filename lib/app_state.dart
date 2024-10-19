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

  Future<void> _checkOrders() async {
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
        'SELECT * FROM order_detail WHERE od_id > ? ORDER BY od_id',
        [lastProcessedOdId]
      );

      if (orderResults.isNotEmpty) {
        Set<int> processedOrderIds = {};

        for (var orderNewRow in orderResults) {
          var o_id = orderNewRow['o_id'];

          if (!processedOrderIds.contains(o_id)) {
            var orderInfoResults = await conn.query(
              'SELECT ta_id, t_id, is_id FROM `order` WHERE o_id = ?',
              [o_id]
            );

            if (orderInfoResults.isNotEmpty) {
              var ta_id = orderInfoResults.first['ta_id'];
              var t_id = orderInfoResults.first['t_id'];
              var is_id = orderInfoResults.first['is_id'];

              var printerResults = await conn.query(
                'SELECT COUNT(*) as count FROM order_printer_option WHERE o_id = ?',
                [o_id]
              );

              var countOrderDetail = await conn.query(
                'SELECT COUNT(*) as count FROM order_detail WHERE o_id = ?',
                [o_id]
              );

              int differenceCount = countOrderDetail.first['count'] - printerResults.first['count'];

              if (printerResults.first['count'] == 0) {
                for (var orderNewRow in orderResults) {
                  var od_id = orderNewRow['od_id'];
                  var u_id = orderNewRow['u_id'];
                  var i_id = orderNewRow['i_id'];
                  var od_name = orderNewRow['od_name'];
                  var od_quantity = (orderNewRow['od_quantity'] as double).toInt();

                  var orderDetailOptionResults = await conn.query(
                    'SELECT * FROM order_detail_option WHERE od_id = ?',
                    [od_id]
                  );
                  var op_id = orderDetailOptionResults.isNotEmpty ? orderDetailOptionResults.first['op_id'] : null;
                  var op_name = 'No Option';

                  if (op_id != null) {
                    var optionResults = await conn.query(
                      'SELECT op_name FROM options WHERE op_id = ?',
                      [op_id]
                    );
                    op_name = optionResults.isNotEmpty ? optionResults.first['op_name'] : 'No Option';
                  }

                  var tableResults = await conn.query(
                    'SELECT t_name FROM tables WHERE t_id = ?', 
                    [t_id],
                  );
                  var t_name = tableResults.first['t_name'];

                  var tableAreaResults = await conn.query(
                    'SELECT ta_name FROM tables_area WHERE ta_id = ?', 
                    [ta_id],
                  );
                  var ta_name = tableAreaResults.first['ta_name'];

                  var userResults = await conn.query(
                    'SELECT u_name FROM user WHERE u_id = ?', 
                    [u_id],
                  );
                  var u_name = userResults.first['u_name'];

                  bool isTambahan = false;
                  await insertOrderOption(conn, o_id, i_id, od_id, ta_id, ta_name, is_id, t_id, t_name, u_id, u_name, op_id, op_name, od_name, od_quantity, isTambahan);
                  await _updateLastProcessedOdId(conn, od_id);

                  logService.logMessage('$u_name menginput $od_quantity order BARU $od_name $op_name di table $t_name $ta_name');
                }
              } 
              else if (differenceCount > 0) {
                var addOrders = await conn.query(
                  '''
                  SELECT * FROM (
                    SELECT * FROM order_detail WHERE o_id = ? ORDER BY od_id DESC LIMIT ?
                  ) AS subquery
                  ORDER BY od_id ASC
                  ''',
                  [o_id, differenceCount]
                );

                for (var orderNewRow in addOrders) {
                  var od_id = orderNewRow['od_id'];
                  var u_id = orderNewRow['u_id'];
                  var i_id = orderNewRow['i_id'];
                  var od_name = orderNewRow['od_name'];
                  var od_quantity = (orderNewRow['od_quantity'] as double).toInt();

                  var orderDetailOptionResults = await conn.query(
                    'SELECT * FROM order_detail_option WHERE od_id = ?',
                    [od_id]
                  );

                  var op_id = orderDetailOptionResults.isNotEmpty ? orderDetailOptionResults.first['op_id'] : null;
                  var op_name = 'No Option';

                  if (op_id != null) {
                    var optionResults = await conn.query(
                      'SELECT op_name FROM options WHERE op_id = ?',
                      [op_id]
                    );
                    op_name = optionResults.isNotEmpty ? optionResults.first['op_name'] : 'No Option';
                  }

                  var tableResults = await conn.query(
                    'SELECT t_name FROM tables WHERE t_id = ?', 
                    [t_id],
                  );
                  var t_name = tableResults.first['t_name'];

                  var tableAreaResults = await conn.query(
                    'SELECT ta_name FROM tables_area WHERE ta_id = ?', 
                    [ta_id],
                  );
                  var ta_name = tableAreaResults.first['ta_name'];

                  var userResults = await conn.query(
                    'SELECT u_name FROM user WHERE u_id = ?', 
                    [u_id],
                  );
                  var u_name = userResults.first['u_name'];

                  bool isTambahan = true;
                  await insertOrderOption(conn, o_id, i_id, od_id, ta_id, ta_name, is_id, t_id, t_name, u_id, u_name, op_id, op_name, od_name, od_quantity, isTambahan);
                  await _updateLastProcessedOdId(conn, od_id);

                  logService.logMessage('$u_name menginput $od_quantity order TAMBAHAN $od_name $op_name di table $t_name $ta_name');
                }
              }
              processedOrderIds.add(o_id);
            }
          }
        }
      }

      await conn.close();
    } catch (e) {
      logService.logMessage('Error during MySQL operation: $e');
      _addLog('Error during MySQL operation: $e');
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

  Future<void> insertOrderOption(MySqlConnection conn, int o_id, int i_id, int od_id, int ta_id, String ta_name, int is_id, int t_id, String t_name, int u_id, String u_name, int? op_id, String op_name, String od_name, int od_quantity, bool isTambahan) async {
    var currentTime = DateTime.now().toString().split('.')[0];

    await conn.query(
      'INSERT INTO order_printer_option (o_id, i_id, u_id, od_id, od_name, od_quantity, ta_id, is_id, t_id, op_id, op_name, opr_printed, opo_stamps) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "False", ?)',
      [o_id, i_id, u_id, od_id, od_name, od_quantity, ta_id, is_id, t_id, op_id, op_name, currentTime]
    );

    await checkPrinterOption(conn, od_id, o_id, ta_id, ta_name, is_id, t_id, t_name, u_id, u_name, op_name, od_name, od_quantity, isTambahan);
  }

  Future<void> insertLogPrint(MySqlConnection conn, int od_id, int o_id, int ta_id, String ta_name, int is_id, int t_id, String t_name, int u_id, String u_name, String op_name, String od_name, int od_quantity, String matchingPrinter, bool isTambahan) async {
    var currentTime = DateTime.now().toString().split('.')[0];
    String tambahanText = isTambahan ? "[TAMBAHAN]\n" : "";

    String rtfMessageSource = '''{\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033{\\fonttbl{\\f0\\fnil FontB28;}{\\f1\\fnil FontA12;}{\\f2\\fnil Tahoma;}}
\\viewkind4\\uc1\\pard\\f0\\fs44 Table $t_name / $ta_name \\par
\\f1\\fs28 $tambahanText\\par
\\par

$matchingPrinter\\tab $currentTime\\par
================================\\par
[ ] $od_name x $od_quantity\\par
    - $op_name\\par
\\par
POS / $u_name\\par
\\f2\\fs16\\par
}''';

    await conn.query(
      '''
      INSERT INTO log_print (o_id, ta_id, is_id, t_id, u_id, br_id, ts_id, lp_print_type, lp_title, 
      lp_message, lp_message_source, lp_printer_name, lp_print_counter, lp_count, lp_time, lp_ip, 
      pos_id, lp_printed, lp_rpm_printed, lp_loaded, lp_redirected, lp_delayed_print, lp_rpm_session) 
      VALUES (?, ?, ?, ?, ?, 0, 0, 'Order', ?, ?, ?, ?, 0, 1, ?, '192.168.110.23', 'POS', 
      "False", "False", "False", "False", "True", 'a5347f67')
      ''',
      [
        o_id, ta_id, is_id, t_id, u_id, 'Table $t_id / $matchingPrinter', 
        'Table $t_name / $ta_name\n\n$tambahanText\n$matchingPrinter\t$currentTime\n=====================\n[ ] $od_name x $od_quantity\n - $op_name\nPOS / $u_name\n',
        rtfMessageSource, matchingPrinter, currentTime,
      ],
    );
  logService.logMessage('$u_name menginput $od_quantity $od_name dengan opsi $op_name ke printer: $matchingPrinter pada $currentTime');
  _addLog('$u_name menginput $od_quantity $od_name dengan opsi $op_name ke printer: $matchingPrinter pada $currentTime');
  }

  Future<void> checkPrinterOption(MySqlConnection conn, int od_id, int o_id, int ta_id, String ta_name, int is_id, int t_id, String t_name, int u_id, String u_name, String op_name, String od_name, int od_quantity, bool isTambahan) async {
    try {
      final config = await _readConfig();

      String? matchingPrinter;

      for (var printer in config.keys) {
        if (config[printer].contains(op_name)) {
          matchingPrinter = printer;
          break; 
        }
      }

      if (matchingPrinter != null) {
        await insertLogPrint(conn, od_id, o_id, ta_id, ta_name, is_id, t_id, t_name, u_id, u_name, op_name, od_name, od_quantity, matchingPrinter, isTambahan);
  
        await conn.query(
          'UPDATE order_printer_option SET opr_printed = "True" WHERE od_id = ? AND op_name = ?',
          [od_id, op_name]
        );
        logService.logMessage('op_name $op_name sesuai dengan config untuk printer $matchingPrinter');
      } else {
        logService.logMessage('op_name $op_name tidak ditemukan di config.json untuk printer manapun.');
      }
    } catch (e) {
      logService.logMessage('Error during checking printer option: $e');
    }
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
