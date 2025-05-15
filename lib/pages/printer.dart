import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  List<String> printers = [];
  List<String> options = [];
  List<String> filteredOptions = [];
  List<String> selectedOptions = [];
  String? selectedPrinter;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPrintersAndOptions();
    filteredOptions = options; 
  }

  Future<void> _fetchPrintersAndOptions() async {
    final settings = ConnectionSettings(
      host: dotenv.env['DB_HOST']!,
      port: int.parse(dotenv.env['DB_PORT']!),
      user: dotenv.env['DB_USER']!,
      password: dotenv.env['DB_PASSWORD']!,
      db: dotenv.env['DB_NAME']!,
    );

    try {
      var conn = await MySqlConnection.connect(settings);
      var br_id = dotenv.env['BR_ID']!;

      var printerResults = await conn.query('SELECT pr_name FROM printer WHERE br_id = ? AND pr_status = "Active"',
      [br_id],
      );
      printers = printerResults.map((row) => row['pr_name'].toString()).toList();

      var optionResults = await conn.query('SELECT op_name FROM options WHERE op_status = "Active"');
      options = optionResults.map((row) => row['op_name'].toString()).toList();
      filteredOptions = options; 

      setState(() {});

      await conn.close();
    } catch (e) {
      debugPrint('Error during MySQL operation: $e');
    }
  }

  void _filterOptions(String query) {
    setState(() {
      filteredOptions = options
          .where((option) => option.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
  
  Future<void> _saveSelectedOptions() async {
    if (selectedPrinter != null) {
      final config = await _readConfig();

      config[selectedPrinter!] = selectedOptions;

      await _writeConfig(config);

      final message = 'Berhasil update opsi untuk printer: $selectedPrinter';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );

      debugPrint(message);
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

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    final file = File('config.json');
    await file.writeAsString(jsonEncode(config));
  }

  void _toggleOptionSelection(String option) {
    setState(() {
      if (selectedOptions.contains(option)) {
        selectedOptions.remove(option);
      } else {
        selectedOptions.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Printer Page'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "LIST PRINTER",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 18.0),
                      Expanded(
                        child: ListView.builder(
                          itemCount: printers.length,
                          itemBuilder: (context, index) {
                            return InkWell(
                              onTap: () async {
                                final config = await _readConfig();
                                setState(() {
                                  selectedPrinter = printers[index];
                                  if (config.containsKey(selectedPrinter)) {
                                    selectedOptions = List<String>.from(config[selectedPrinter!]);
                                  } else {
                                    selectedOptions = [];
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(8.0),
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedPrinter == printers[index] ? Colors.green : Colors.grey,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(12.0),
                                  color: selectedPrinter == printers[index] ? Colors.green[100] : Colors.white,
                                ),
                                child: Center(
                                  child: Text(
                                    printers[index],
                                    style: const TextStyle(fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: searchController,
                          onChanged: _filterOptions,
                          decoration: InputDecoration(
                            hintText: 'Cari opsi...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: filteredOptions.length, 
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.all(4.0),
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selectedOptions.contains(filteredOptions[index])
                                      ? Colors.green
                                      : Colors.grey,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                                color: selectedOptions.contains(filteredOptions[index])
                                    ? Colors.green[100]
                                    : Colors.white,
                              ),
                              child: ListTile(
                                title: Text(
                                  filteredOptions[index],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                trailing: Checkbox(
                                  value: selectedOptions.contains(filteredOptions[index]),
                                  onChanged: (bool? value) {
                                    _toggleOptionSelection(filteredOptions[index]);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: _saveSelectedOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0), 
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text(
                  'Save', 
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
