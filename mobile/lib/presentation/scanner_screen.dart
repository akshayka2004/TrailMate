import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scans a checkpoint QR and pops with the raw payload string
/// (`TRAILMATE:CP:<id>`). The caller resolves it to a checkpoint.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan checkpoint QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final codes = capture.barcodes;
          if (codes.isEmpty) return;
          final value = codes.first.rawValue;
          if (value == null) return;
          _handled = true;
          Navigator.of(context).pop(value);
        },
      ),
    );
  }
}
