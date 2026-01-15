# Enhanced QR Scanner with Product Database Integration

This guide explains how to use the enhanced QR scanner that automatically checks scanned QR codes against the product database and returns product information.

## Files Overview

### Core Files
- `lib/utils/qr_scanner_with_product_check.dart` - Enhanced QR scanner with database integration
- `lib/utils/qr_scanner_helper.dart` - Unified helper class with multiple scanning options
- `lib/utils/qr_scanner.dart` - Original QR scanner (for backward compatibility)

### Example Files
- `lib/examples/qr_scanner_integration_examples.dart` - Practical usage examples

## Quick Start

### Basic Usage (Product-Aware Scanning)

```dart
import 'package:your_app/utils/qr_scanner_helper.dart';

final result = await QRScannerHelper.showProductScanner(
  context,
  initialMessage: 'Scan a product QR code',
);

if (result != null) {
  final productInfo = result['productInfo'] as Map<String, dynamic>?;
  final qrCode = result['qrCode'] as String;
  
  if (productInfo != null) {
    // Product found in database
    print('Product: ${productInfo['name']}');
    print('Price: ${productInfo['selling_price']}');
    print('Status: ${productInfo['scanned_item_status']}');
  } else {
    // Product not found
    print('QR Code: $qrCode (not found in database)');
  }
}
```

### Legacy Usage (String Only)

```dart
final qrCode = await QRScannerHelper.showBasicScanner(
  context,
  initialMessage: 'Scan any QR code',
);

if (qrCode != null) {
  print('QR Code: $qrCode');
}
```

## API Reference

### QRScannerHelper Class

#### `showBasicScanner(BuildContext context, {String? initialMessage})`
- **Purpose**: Shows the original QR scanner that returns only the QR code string
- **Parameters**: 
  - `context`: BuildContext
  - `initialMessage`: Optional message to show in the scanner
- **Returns**: `Future<String?>` - QR code string or null

#### `showProductScanner(BuildContext context, {String? initialMessage})`
- **Purpose**: Shows enhanced QR scanner that checks product database
- **Parameters**:
  - `context`: BuildContext
  - `initialMessage`: Optional message to show in the scanner
- **Returns**: `Future<Map<String, dynamic>?>` with keys:
  - `productInfo`: `Map<String, dynamic>?` - Product information or null
  - `qrCode`: `String` - The scanned QR code

#### `checkQRCodeForProduct(String qrCode)`
- **Purpose**: Manually check if a QR code corresponds to a product
- **Parameters**: 
  - `qrCode`: String - QR code to check
- **Returns**: `Future<Map<String, dynamic>?>` - Product info or null

#### `showProductInfoDialog(BuildContext context, productInfo, qrCode)`
- **Purpose**: Show a dialog with product information
- **Parameters**:
  - `context`: BuildContext
  - `productInfo`: Product information map or null
  - `qrCode`: The scanned QR code

## Product Information Structure

When a product is found in the database, the `productInfo` contains:

```dart
{
  'local_id': int,           // Local database ID
  'server_id': int?,         // Server database ID (if synced)
  'name': String,            // Product name
  'sku': String?,            // Product SKU
  'selling_price': double?,  // Selling price
  'scanned_item_id': int?,   // Specific item ID (for serialized items)
  'scanned_item_server_id': int?, // Specific item server ID
  'scanned_item_status': String?, // Item status (available/sold/damaged)
  // ... other product fields
}
```

## Database Integration

The enhanced scanner uses the existing `DatabaseService.findProductByBarcodeOrSku()` method which:

1. **First Priority**: Checks `product_items` table for QR codes (specific serialized items)
2. **Second Priority**: Checks `products` table for barcode or SKU matches (bulk items)
3. **Returns**: Complete product information with item-specific details if found

## Implementation Examples

### Sales Integration

```dart
class SalesPage extends StatefulWidget {
  @override
  _SalesPageState createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final List<Map<String, dynamic>> _cart = [];

  Future<void> _scanProduct() async {
    final result = await QRScannerHelper.showProductScanner(
      context,
      initialMessage: 'Scan product to add to cart',
    );

    if (result != null) {
      final productInfo = result['productInfo'];
      final qrCode = result['qrCode'];

      if (productInfo != null) {
        setState(() {
          _cart.add({
            'product': productInfo,
            'qrCode': qrCode,
            'quantity': 1,
          });
        });
      } else {
        // Handle product not found
        _showProductNotFound(qrCode);
      }
    }
  }
}
```

### Inventory Check Integration

```dart
class InventoryCheck extends StatefulWidget {
  @override
  _InventoryCheckState createState() => _InventoryCheckState();
}

class _InventoryCheckState extends State<InventoryCheck> {
  Map<String, dynamic>? _currentItem;

  Future<void> _scanForInventory() async {
    final result = await QRScannerHelper.showProductScanner(
      context,
      initialMessage: 'Scan item to check inventory status',
    );

    if (result != null) {
      setState(() {
        _currentItem = result['productInfo'];
      });
    }
  }

  Widget _buildInventoryDisplay() {
    if (_currentItem == null) {
      return Text('No item scanned');
    }

    final item = _currentItem!;
    return Card(
      child: ListTile(
        title: Text(item['name']),
        subtitle: Text('Status: ${item['scanned_item_status']}'),
        trailing: Text('\$${item['selling_price']}'),
      ),
    );
  }
}
```

## Error Handling

The enhanced scanner includes comprehensive error handling:

```dart
try {
  final result = await QRScannerHelper.showProductScanner(context);
  // Handle result
} catch (e) {
  // Handle scanning errors
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Scanning error: $e')),
  );
}
```

## Performance Considerations

1. **Database Queries**: Each scan triggers a database query
2. **Loading States**: Scanner shows "Checking product..." overlay during database lookup
3. **Duplicate Prevention**: Same QR code won't be scanned multiple times in one session
4. **Error Recovery**: Graceful handling of database connection issues

## Migration from Old Scanner

To migrate existing code using the old QR scanner:

### Before (Old)
```dart
final qrCode = await showModalBottomSheet<String>(
  context: context,
  builder: (context) => QRCodeScanner(
    onQRCodeScanned: (code) => Navigator.pop(context, code),
  ),
);
```

### After (New)
```dart
final result = await QRScannerHelper.showProductScanner(context);
final qrCode = result?['qrCode'] as String?;
final productInfo = result?['productInfo'] as Map<String, dynamic>?;
```

## Testing

Use the provided example classes for testing:

```dart
// In your app's main.dart or route
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => QRScannerExample()),
);
```

This provides a demo page with all three scanning modes for testing.

## Support

If you encounter issues:

1. Check database connection in `DatabaseService`
2. Verify QR codes exist in `product_items` or `products` tables
3. Ensure proper context is passed to scanner functions
4. Check Flutter console for detailed error messages