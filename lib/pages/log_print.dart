import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart'; 

class LogPrintPage extends StatelessWidget {
  const LogPrintPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Print Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Table(
            border: TableBorder.all(),
            columnWidths: const {
              0: FlexColumnWidth(1),
            },
            children: [
              // Header tabel
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[300]),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Log Message',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              ...List.generate(appState.getLogs().length, (index) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        appState.getLogs()[index],
                        style: const TextStyle(fontSize: 12), 
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}  
