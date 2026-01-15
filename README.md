# StockFlow KP 📱

> **WIN THE DREAM** - A comprehensive stock management solution for modern businesses

StockFlow KP is a powerful, offline-first Flutter application designed for business officers to manage inventory, sales, customers, and analytics with seamless cloud synchronization. Built with modern architecture and user experience in mind.

[![Flutter](https://img.shields.io/badge/Flutter-3.7.2-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0-blue.svg)](https://dart.dev/)
[![SQLite](https://img.shields.io/badge/SQLite-2.4.2-green.svg)](https://pub.dev/packages/sqflite)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🌟 Key Features

### 📦 **Inventory Management**
- **Product CRUD Operations**: Add, edit, delete, and organize products
- **Category Management**: Hierarchical product categorization
- **Stock Tracking**: Real-time inventory monitoring with batch tracking
- **Barcode Integration**: Scan and generate barcodes/QR codes
- **Image Support**: Product photos and visual inventory

### 💰 **Sales & POS**
- **Point of Sale**: Intuitive sales interface with cart management
- **Customer Management**: Complete customer database with profiles
- **Proforma Invoices**: Create and manage quotation documents
- **Discount Management**: Flexible pricing and discount options
- **Sales Analytics**: Comprehensive reporting and insights

### 🔄 **Offline-First Architecture**
- **Local Database**: SQLite-powered offline functionality
- **Auto-Sync**: Automatic background synchronization every 2 minutes
- **Conflict Resolution**: Smart data merging and conflict handling
- **Pending Operations**: Queue operations for later sync

### 📊 **Analytics & Reporting**
- **Dashboard**: Real-time sales and inventory metrics
- **Sales Reports**: Detailed transaction history and analysis
- **Top Products**: Best-selling items tracking
- **Category Performance**: Sales breakdown by categories
- **Date Range Filtering**: Custom reporting periods

### 🌐 **Multi-Language Support**
- **English** 🇺🇸
- **French** 🇫🇷
- **Swahili** 🇹🇿

### 🔐 **Security & Permissions**
- **Role-Based Access**: Officer-specific permissions
- **Secure Authentication**: JWT-based login system
- **Data Encryption**: Local data protection
- **Tenant Isolation**: Multi-tenant architecture support

## 🏗️ Architecture

### **Technology Stack**
- **Frontend**: Flutter (Dart)
- **Database**: SQLite (local) + REST API (remote)
- **State Management**: Provider pattern with local state
- **Networking**: HTTP package with Dio
- **Storage**: SharedPreferences + File system
- **UI Framework**: Material Design 3

### **Project Structure**
```
lib/
├── auth/                 # Authentication screens
├── l10n/                 # Localization files
├── officer/              # Main application screens
│   ├── barcode_generator_screen.dart
│   ├── create_sale_page.dart
│   ├── officer_home.dart
│   ├── pending_sales_page.dart
│   ├── sales_analytics_page.dart
│   └── ...
├── services/             # Business logic and API
│   ├── api_service.dart
│   ├── database_service.dart
│   ├── sync_service.dart
│   └── sale_service.dart
└── utils/                # Helper utilities
```

### **Database Schema**
The application uses a comprehensive SQLite database with the following main tables:

- **users**: Authentication and user profiles
- **officers**: Officer-specific data and permissions
- **products**: Product catalog with images and barcodes
- **categories**: Product categorization hierarchy
- **stocks**: Inventory levels and batch tracking
- **sales**: Transaction records
- **sale_items**: Individual sale line items
- **customers**: Customer database
- **tenant_account**: Company/tenant information

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `^3.7.2`
- **Dart SDK**: `^3.0.0`
- **Android Studio** or **VS Code** with Flutter extensions
- **Android/iOS device** or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/stockflowkp.git
   cd stockflowkp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   - Update API endpoints in `lib/services/api_service.dart`
   - Configure database settings if needed

4. **Run the application**
   ```bash
   flutter run
   ```

### Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**iOS (on macOS):**
```bash
flutter build ios --release
```

## 📱 Usage Guide

### First Time Setup
1. **Launch App**: Open StockFlow KP on your device
2. **Language Selection**: Choose your preferred language (EN/FR/SW)
3. **Login**: Enter your officer credentials
4. **Dashboard**: Access main features from the home screen

### Core Workflows

#### **Managing Products**
1. Navigate to **Products** tab
2. Tap **+** to add new products
3. Fill product details, scan barcode, add images
4. Assign to categories and set pricing

#### **Creating Sales**
1. Go to **New Sale** from dashboard
2. Scan product barcodes or search manually
3. Add items to cart, apply discounts
4. Select customer and complete transaction

#### **Viewing Analytics**
1. Access **Analytics** tab
2. View sales trends and top products
3. Filter by date ranges and categories
4. Export reports as needed

#### **Offline Operation**
- All features work offline
- Data automatically syncs when online
- Pending operations show in dashboard
- Manual sync available in settings

## 🔧 Configuration

### API Configuration
Update `lib/services/api_service.dart` with your backend URLs:

```dart
class ApiService {
  static const String baseUrl = 'https://your-api-domain.com/api';
  // ... other configurations
}
```

### Database Configuration
Database settings are handled automatically, but you can customize:
- Database name: `petsonkisenyaa.db`
- Sync intervals: Currently set to 2 minutes
- Batch sizes for bulk operations

### Permissions
The app requires the following permissions:
- **Camera**: For barcode scanning
- **Storage**: For product images and exports
- **Location**: For store location tracking (optional)

## 🔄 Synchronization

### How It Works
1. **Local Changes**: All operations stored locally first
2. **Background Sync**: Automatic sync every 2 minutes when online
3. **Conflict Resolution**: Server data takes precedence for conflicts
4. **Retry Logic**: Failed syncs automatically retry

### Sync Status Indicators
- 🟢 **Synced**: Data successfully synchronized
- 🟡 **Pending**: Waiting for sync
- 🔴 **Failed**: Sync error, manual retry needed

### Manual Sync
Access manual sync from the drawer menu or settings.

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Test Coverage
```bash
flutter test --coverage
```

## 📦 Dependencies

### Core Dependencies
- **sqflite**: Local SQLite database
- **http**: API communication
- **shared_preferences**: Local storage
- **path_provider**: File system access

### UI & UX
- **google_fonts**: Typography
- **shimmer**: Loading animations
- **flutter_localizations**: Multi-language support

### Business Features
- **qr_code_scanner**: Barcode scanning
- **barcode_widget**: Barcode generation
- **fl_chart**: Data visualization
- **pdf**: Document generation
- **excel**: Spreadsheet export

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines
- Follow Flutter best practices
- Write comprehensive tests
- Update documentation
- Maintain code quality with `flutter analyze`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help
- **Documentation**: Check this README and inline code comments
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join community discussions

### Contact Information
- **Email**: support@stockflowkp.com
- **Website**: https://stockflowkp.com
- **Documentation**: https://docs.stockflowkp.com

## 🗺️ Roadmap

### Upcoming Features
- [ ] **Advanced Analytics**: AI-powered insights
- [ ] **Multi-Store Support**: Chain management
- [ ] **Mobile Payments**: Integrated payment processing
- [ ] **Inventory Forecasting**: Predictive stock management
- [ ] **API Documentation**: Complete API reference

### Version History
- **v1.0.0**: Initial release with core features
- **v1.1.0**: Enhanced analytics and reporting
- **v1.2.0**: Multi-language support and UI improvements

---

**Built with ❤️ for modern businesses**
