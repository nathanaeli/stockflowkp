import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QRCodeScanner extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  final String? initialMessage;

  const QRCodeScanner({
    Key? key,
    required this.onQRCodeScanned,
    this.initialMessage,
  }) : super(key: key);

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool hasPermission = false;
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
        setState(() {
          hasPermission = cameraStatus.isGranted;
        });
      } else {
        setState(() {
          hasPermission = true;
        });
      }
    } else {
      setState(() {
        hasPermission = true;
      });
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (isScanning && scanData.code != null) {
        isScanning = false;
        widget.onQRCodeScanned(scanData.code!);
        controller.pauseCamera();
      }
    });
  }

  void _resumeScanning() {
    if (controller != null) {
      isScanning = true;
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission) {
      return _buildPermissionDeniedWidget();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR Scanner View
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 16,
              borderLength: 30,
              borderWidth: 4,
              cutOutSize: 250,
            ),
          ),

          // Top Bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'Scan QR Code',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
                  onPressed: _resumeScanning,
                ),
              ],
            ),
          ),

          // Instructions
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (widget.initialMessage != null)
                  Text(
                    widget.initialMessage!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Align the QR code within the frame to scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildFlashButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashButton() {
    return FutureBuilder(
      future: controller?.getFlashStatus(),
      builder: (context, snapshot) {
        return IconButton(
          icon: Icon(
            snapshot.data == true ? Icons.flash_on : Icons.flash_off,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () async {
            if (controller != null) {
              await controller?.toggleFlash();
              setState(() {});
            }
          },
        );
      },
    );
  }

  Widget _buildPermissionDeniedWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please grant camera permission to scan QR codes.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _checkPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}