import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'theme.dart';

/// Scans a checkpoint QR and pops with the raw payload string
/// (`TRAILMATE:CP:<id>`). The caller resolves it to a checkpoint.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handled = false;
  // Managed explicitly (rather than letting MobileScanner auto-create one)
  // so a failed camera bind can be retried without recreating the whole
  // widget, and so start()/dispose() are always paired.
  late final MobileScannerController _controller;
  String? _startError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(autoStart: false);
    _startScanner();
  }

  Future<void> _startScanner() async {
    setState(() => _startError = null);
    try {
      await _controller.start();
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() => _startError = switch (e.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              'Camera permission denied — enable it in system settings to scan.',
            _ => 'Could not start the camera (${e.errorCode.name}).',
          });
    } catch (_) {
      // Covers the native NullPointerException some devices throw when the
      // camera binder isn't ready yet (ML Kit barcode plugin quirk) —
      // surface it as a retryable error instead of crashing the screen.
      if (!mounted) return;
      setState(() => _startError = 'Camera failed to initialize. Try again.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan checkpoint QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_startError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 40, color: kMuted),
                    const SizedBox(height: 12),
                    Text(_startError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _startScanner,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) {
                // Any post-start failure lands here instead of crashing.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: kDestructive),
                        const SizedBox(height: 12),
                        Text(
                          switch (error.errorCode) {
                            MobileScannerErrorCode.permissionDenied =>
                              'Camera permission denied — enable it in system settings.',
                            MobileScannerErrorCode.unsupported =>
                              'This device has no usable camera for scanning.',
                            // genericError is CameraX/ML Kit failing to bind a
                            // camera device — common on emulators without a
                            // configured webcam, or if another app is holding
                            // the camera.
                            MobileScannerErrorCode.genericError =>
                              'Could not access the camera. On an emulator, '
                                  'enable a webcam for it in AVD settings; on a '
                                  'real device, close any other app using the '
                                  'camera and retry.',
                            _ => 'Camera error: ${error.errorCode.name}',
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _startScanner,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
          if (_startError == null)
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: kAccent, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          if (_startError == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Align the checkpoint QR code within the frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
