import 'package:flutter/material.dart';
import '../utils/qr_scanner_helper.dart';

/// Example page showing how to integrate the enhanced QR scanner
/// for sales or inventory management
class SalesWithQRScanner extends StatefulWidget {
  const SalesWithQRScanner({super.key});

  @override
  State<SalesWithQRScanner> createState() => _SalesWithQRScannerState();
}

class _SalesWithQRScannerState extends State<SalesWithQRScanner> {
  final List<Map<String, dynamic>> _scannedItems = [];
  double _totalAmount = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales - QR Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProduct,
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _scanProduct,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Product QR Code'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),

          // Scanned Items List
          Expanded(
            child:
                _scannedItems.isEmpty
                    ? const Center(
                      child: Text(
                        'No items scanned yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        final item = _scannedItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(item['status']),
                              child: Text(
                                item['name']?.substring(0, 1) ?? '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(item['name'] ?? 'Unknown Product'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item['sku'] != null)
                                  Text('SKU: ${item['sku']}'),
                                if (item['selling_price'] != null)
                                  Text('Price: \$${item['selling_price']}'),
                                Text('QR: ${item['qrCode']}'),
                                Text(
                                  'Status: ${item['status'] ?? 'available'}',
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeItem(index),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // Total and Checkout
          if (_scannedItems.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: \$${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _checkout,
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _scanProduct() async {
    try {
      final result = await QRScannerHelper.showProductScanner(
        context,
        initialMessage: 'Scan a product QR code to add to sale',
      );

      if (result != null) {
        final productInfo = result['productInfo'] as Map<String, dynamic>?;
        final qrCode = result['qrCode'] as String;

        if (productInfo != null) {
          // Product found in database
          _addProductToSale(productInfo, qrCode);
        } else {
          // Product not found - show options
          _showProductNotFoundDialog(qrCode);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error scanning: $e')));
    }
  }

  void _addProductToSale(Map<String, dynamic> productInfo, String qrCode) {
    final item = {
      'local_id': productInfo['local_id'],
      'server_id': productInfo['server_id'],
      'name': productInfo['name'],
      'sku': productInfo['sku'],
      'selling_price': productInfo['selling_price'] ?? 0.0,
      'qrCode': qrCode,
      'status': productInfo['scanned_item_status'] ?? 'available',
      'scanned_item_id': productInfo['scanned_item_id'],
    };

    setState(() {
      _scannedItems.add(item);
      _calculateTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${productInfo['name']} to sale'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showProductNotFoundDialog(String qrCode) {
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

  void _calculateTotal() {
    _totalAmount = _scannedItems.fold(0.0, (sum, item) {
      return sum + (item['selling_price'] as double? ?? 0.0);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _scannedItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _checkout() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing sale of ${_scannedItems.length} items'),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'sold':
        return Colors.red;
      case 'damaged':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
