import 'package:flutter/material.dart';
import 'qr_scanner.dart';
import 'qr_scanner_with_product_check.dart';
import '../services/database_service.dart';

/// Unified QR Scanner utility that provides both basic and product-aware scanning
class QRScannerHelper {
  /// Show basic QR scanner (returns only QR code string)
  static Future<String?> showBasicScanner(
    BuildContext context, {
    String? initialMessage,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => QRCodeScanner(
            onQRCodeScanned: (qrCode) {
              Navigator.pop(context, qrCode);
            },
            initialMessage: initialMessage,
          ),
    );
  }

  /// Show advanced QR scanner (checks product items and returns product info)
  static Future<Map<String, dynamic>?> showProductScanner(
    BuildContext context, {
    String? initialMessage,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => QRCodeScannerWithProductCheck(
            onProductFound: (productInfo, qrCode) {
              Navigator.pop(context, {
                'productInfo': productInfo,
                'qrCode': qrCode,
              });
            },
            initialMessage: initialMessage,
          ),
    );
  }

  /// Manually check if a QR code corresponds to a product item
  static Future<Map<String, dynamic>?> checkQRCodeForProduct(
    String qrCode,
  ) async {
    try {
      final databaseService = DatabaseService();
      return await databaseService.findProductByBarcodeOrSku(qrCode);
    } catch (e) {
      print('Error checking QR code for product: $e');
      return null;
    }
  }

  /// Show a dialog with product information if found
  static Future<void> showProductInfoDialog(
    BuildContext context,
    Map<String, dynamic>? productInfo,
    String qrCode,
  ) async {
    if (productInfo != null) {
      // Product found - show product details
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Product Found'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${productInfo['name'] ?? 'N/A'}'),
                  if (productInfo['sku'] != null)
                    Text('SKU: ${productInfo['sku']}'),
                  if (productInfo['selling_price'] != null)
                    Text('Price: \$${productInfo['selling_price']}'),
                  if (productInfo['scanned_item_status'] != null)
                    Text('Status: ${productInfo['scanned_item_status']}'),
                  Text('QR Code: $qrCode'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } else {
      // Product not found - show QR code only
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Product Not Found'),
              content: Text('No product found for QR code: $qrCode'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}

/// Example usage widget showing how to use the enhanced QR scanner
class QRScannerExample extends StatelessWidget {
  const QRScannerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner Examples')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final qrCode = await QRScannerHelper.showBasicScanner(
                  context,
                  initialMessage: 'Scan any QR code to get the raw string',
                );
                if (qrCode != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Scanned: $qrCode')));
                }
              },
              child: const Text('Basic QR Scanner (String Only)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await QRScannerHelper.showProductScanner(
                  context,
                  initialMessage:
                      'Scan a product QR code to check product info',
                );
                if (result != null) {
                  final productInfo =
                      result['productInfo'] as Map<String, dynamic>?;
                  final qrCode = result['qrCode'] as String;
                  await QRScannerHelper.showProductInfoDialog(
                    context,
                    productInfo,
                    qrCode,
                  );
                }
              },
              child: const Text('Product QR Scanner (With Database Check)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Example: Manually check a QR code
                const testQRCode = 'TEST_QR_CODE_123';
                final productInfo = await QRScannerHelper.checkQRCodeForProduct(
                  testQRCode,
                );
                await QRScannerHelper.showProductInfoDialog(
                  context,
                  productInfo,
                  testQRCode,
                );
              },
              child: const Text('Test Manual QR Check'),
            ),
          ],
        ),
      ),
    );
  }
}
