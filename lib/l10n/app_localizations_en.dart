// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SmartBiz';

  @override
  String get subtitle => 'Manage your business like a pro.\nSales • Inventory • Customers • Reports';

  @override
  String get enterButton => 'Enter SmartBiz';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginSuccessful => 'Login successful';

  @override
  String get stockflowKP => 'StockflowKP';

  @override
  String get winTheDream => 'WIN THE DREAM';

  @override
  String helloOfficer(Object name) {
    return 'Hello, $name 👋';
  }

  @override
  String get readyForTasks => 'Ready for today\'s tasks?';

  @override
  String get todaysSales => 'Today\'s Sales';

  @override
  String get unsynced => 'Unsynced';

  @override
  String get lowStock => 'Low Stock';

  @override
  String get home => 'Home';

  @override
  String get analytics => 'Analytics';

  @override
  String get products => 'products';

  @override
  String get clients => 'Clients';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get pendingSales => 'Pending Sales';

  @override
  String get checkStock => 'Check Stock';

  @override
  String get activityLog => 'Activity Log';

  @override
  String get barcodeGenerator => 'Barcode Generator';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get howToUse => 'How to use it';

  @override
  String get support => 'Support';

  @override
  String get signOut => 'Sign Out';

  @override
  String get newSale => 'New Sale';

  @override
  String get sales => 'Sales';

  @override
  String get categories => 'Categories';

  @override
  String get permissions => 'Permissions';

  @override
  String get customers => 'Customers';

  @override
  String get myCompany => 'My Company';

  @override
  String get proforma => 'Proforma';

  @override
  String get invoices => 'Invoices';

  @override
  String get unsyncedData => 'Unsynced Data';

  @override
  String unsyncedWarning(Object count) {
    return 'You have $count pending items that haven\'t been synced yet. Signing out now will delete this data permanently.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteSignOut => 'Delete & Sign Out';

  @override
  String get syncSignOut => 'Sync & Sign Out';

  @override
  String get confirmSignOut => 'Are you sure you want to sign out? All local data will be cleared.';

  @override
  String get syncSuccessful => 'Sync successful! Signing out...';

  @override
  String syncFailed(Object count) {
    return 'Sync failed. $count items remaining.';
  }

  @override
  String syncError(Object error) {
    return 'Sync error: $error';
  }

  @override
  String lowStockAlert(Object count) {
    return '⚠️ Alert: $count products are low on stock!';
  }

  @override
  String get view => 'VIEW';

  @override
  String logoutFailed(Object error) {
    return 'Logout failed: $error';
  }

  @override
  String get officer => 'Officer';

  @override
  String get defaultEmail => 'email@example.com';

  @override
  String get manageProducts => 'Manage Products';

  @override
  String get items => 'items';

  @override
  String get item => 'item';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get tapAddFirstProduct => 'Tap + to add your first product';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get tryDifferentSearch => 'Try a different search term';

  @override
  String get scanProductBarcode => 'Scan product barcode to search';

  @override
  String get scan => 'Scan';

  @override
  String get addProduct => 'Add Product';

  @override
  String get local => 'LOCAL';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Description';

  @override
  String get noDescription => 'No description';

  @override
  String get available => 'available';

  @override
  String get failedToLoadProducts => 'Failed to load products';

  @override
  String get productDeletedSuccessfully => 'Product deleted successfully';

  @override
  String get failedToDeleteProduct => 'Failed to delete product';

  @override
  String get deleteProduct => 'Delete Product';

  @override
  String areYouSureDeleteProduct(Object name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get viewStock => 'View Stock';

  @override
  String get stockInfo => 'Stock Info';

  @override
  String get productType => 'Product Type';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get bulkStock => 'Bulk Stock';

  @override
  String get trackedItemsAvailable => 'Tracked Items (available)';

  @override
  String get totalAvailable => 'Total Available';

  @override
  String get close => 'Close';

  @override
  String get couldNotLoadStockDetails => 'Could not load stock details';

  @override
  String get addProductItem => 'Add Product Item';

  @override
  String get debugInformation => 'Debug Information';

  @override
  String get debugInfoPrinted => 'Debug information has been printed to the console.';

  @override
  String get checkConsoleOutput => 'Check the console output for detailed information about:';

  @override
  String get userAuthDataStructure => 'User authentication data structure';

  @override
  String get tokenLocationFormat => 'Token location and format';

  @override
  String get pendingProductsStatus => 'Pending products status';

  @override
  String get databaseSyncState => 'Database synchronization state';

  @override
  String get informationHelpTroubleshoot => 'This information will help troubleshoot sync issues.';

  @override
  String get ok => 'OK';

  @override
  String get sort => 'Sort';

  @override
  String get name => 'Name';

  @override
  String get price => 'Price';

  @override
  String get syncPendingProducts => 'Sync pending products';

  @override
  String get syncing => 'Syncing...';

  @override
  String get sync => 'Sync';

  @override
  String get debugSyncIssues => 'Debug sync issues';

  @override
  String successfullySyncedProducts(Object count, Object countPlural) {
    return 'Successfully synced $count product$countPlural';
  }

  @override
  String get product => 'product';

  @override
  String failedToSyncProducts(Object count, Object countPlural) {
    return '$count product$countPlural failed to sync';
  }

  @override
  String get noProductsToSync => 'No products to sync';

  @override
  String syncFailedMessage(Object message) {
    return 'Sync failed: $message';
  }

  @override
  String syncErrorMessage(Object error) {
    return 'Sync error: $error';
  }

  @override
  String get left => 'left';

  @override
  String get saleDetails => 'Sale Details';

  @override
  String get itemsPurchased => 'Items Purchased';

  @override
  String get customer => 'Customer';

  @override
  String get refresh => 'Refresh';

  @override
  String get invoice => 'Invoice';

  @override
  String get invoiceReady => 'Invoice Ready';

  @override
  String get printInvoice => 'Print Invoice';

  @override
  String get emailInvoice => 'Email Invoice';

  @override
  String get paid => 'PAID';

  @override
  String get loan => 'LOAN';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get errorSharingInvoice => 'Error sharing invoice';

  @override
  String get dearCustomer => 'Dear Customer';

  @override
  String get invoiceEmailBody => 'Please find attached the invoice for your recent purchase.\n\nThank you for shopping with us!';

  @override
  String get invoicePdfTitle => 'INVOICE';

  @override
  String get billTo => 'Bill To:';

  @override
  String get itemDescription => 'Item Description';

  @override
  String get qty => 'Qty';

  @override
  String get unitPrice => 'Unit Price';

  @override
  String get total => 'Total';

  @override
  String get totalAmountPdf => 'TOTAL AMOUNT';

  @override
  String thankYouChoosing(Object company) {
    return 'Thank you for choosing $company!';
  }

  @override
  String generatedOn(Object date) {
    return 'Generated on $date';
  }

  @override
  String get tel => 'Tel:';

  @override
  String get emailLabel => 'Email:';

  @override
  String get walkInCustomer => 'Walk-in Customer';

  @override
  String get cashSale => 'Cash Sale • No specific address provided';

  @override
  String get registeredCustomer => 'Registered Customer';

  @override
  String itemsCount(Object count) {
    return '$count Items';
  }

  @override
  String get unknownProduct => 'Unknown Product';

  @override
  String get unnamedItem => 'Unnamed Item';

  @override
  String get unknown => 'Unknown';

  @override
  String get walkInSale => 'Walk-in Sale';

  @override
  String get salesAnalytics => 'Sales Analytics';

  @override
  String get last7DaysOverview => 'Last 7 Days Overview';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get date => 'Date';

  @override
  String get day => 'Day';

  @override
  String get salesCount => 'Sales Count';

  @override
  String get revenueTrend => 'Revenue Trend';

  @override
  String get weekly => 'Weekly';

  @override
  String get dailyBreakdown => 'Daily Breakdown';

  @override
  String get salesByCategory => 'Sales by Category';

  @override
  String get topSellingProducts => 'Top Selling Products';

  @override
  String get topProductsSelectedCategory => 'Top Products (Selected Category)';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get noCategoryDataAvailable => 'No category data available';

  @override
  String get noSalesDataAvailable => 'No sales data available';

  @override
  String get unitsSold => 'units sold';

  @override
  String get salesSummaryReport => 'Sales Summary Report';

  @override
  String get last7DaysPerformance => 'Last 7 Days Performance';

  @override
  String get errorExportingExcel => 'Error exporting Excel';

  @override
  String get selectRange => 'Select Range';

  @override
  String get vs => 'vs';

  @override
  String get allSalesSynced => 'All sales are synced';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncAll => 'Sync All';

  @override
  String get saleSyncedSuccessfully => 'Sale synced successfully';

  @override
  String syncFailedWithMessage(Object message) {
    return 'Sync failed: $message';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String syncedCountOfTotal(Object count, Object total) {
    return 'Synced $count of $total sales';
  }

  @override
  String get notAuthenticated => 'Not authenticated';
}
