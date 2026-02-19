import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
    Locale('fr')
  ];

  /// The title of the app displayed on the home screen
  ///
  /// In en, this message translates to:
  /// **'StockFlow KP'**
  String get appTitle;

  /// The subtitle describing the app features
  ///
  /// In en, this message translates to:
  /// **'Manage your business like a pro.\nSales • Inventory • Customers • Reports'**
  String get subtitle;

  /// The text on the enter button
  ///
  /// In en, this message translates to:
  /// **'Enter StockFlow KP'**
  String get enterButton;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Hint for email field
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// Hint for password field
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// Message shown when login fails
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// Message shown when login succeeds
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccessful;

  /// App brand name
  ///
  /// In en, this message translates to:
  /// **'StockflowKP'**
  String get stockflowKP;

  /// App tagline
  ///
  /// In en, this message translates to:
  /// **'WIN THE DREAM'**
  String get winTheDream;

  /// Greeting message for officer
  ///
  /// In en, this message translates to:
  /// **'Hello, {name} 👋'**
  String helloOfficer(Object name);

  /// Task readiness message
  ///
  /// In en, this message translates to:
  /// **'Ready for today\'s tasks?'**
  String get readyForTasks;

  /// Label for today's sales
  ///
  /// In en, this message translates to:
  /// **'Today\'s Sales'**
  String get todaysSales;

  /// Label for unsynced items
  ///
  /// In en, this message translates to:
  /// **'Unsynced'**
  String get unsynced;

  /// Label for low stock items
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Analytics navigation label
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// Products navigation label
  ///
  /// In en, this message translates to:
  /// **'products'**
  String get products;

  /// Clients navigation label
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// Dashboard navigation label
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Pending sales navigation label
  ///
  /// In en, this message translates to:
  /// **'Pending Sales'**
  String get pendingSales;

  /// Check stock navigation label
  ///
  /// In en, this message translates to:
  /// **'Check Stock'**
  String get checkStock;

  /// Activity log navigation label
  ///
  /// In en, this message translates to:
  /// **'Activity Log'**
  String get activityLog;

  /// Barcode generator navigation label
  ///
  /// In en, this message translates to:
  /// **'Barcode Generator'**
  String get barcodeGenerator;

  /// Backup and restore navigation label
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// How to use navigation label
  ///
  /// In en, this message translates to:
  /// **'How to use it'**
  String get howToUse;

  /// Support navigation label
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Sign out navigation label
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// New sale operation label
  ///
  /// In en, this message translates to:
  /// **'New Sale'**
  String get newSale;

  /// Sales operation label
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// Categories operation label
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// Permissions operation label
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// Customers operation label
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// My company operation label
  ///
  /// In en, this message translates to:
  /// **'My Company'**
  String get myCompany;

  /// Proforma operation label
  ///
  /// In en, this message translates to:
  /// **'Proforma'**
  String get proforma;

  /// Invoices operation label
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// Dialog title for unsynced data
  ///
  /// In en, this message translates to:
  /// **'Unsynced Data'**
  String get unsyncedData;

  /// Warning message for unsynced data
  ///
  /// In en, this message translates to:
  /// **'You have {count} pending items that haven\'t been synced yet. Signing out now will delete this data permanently.'**
  String unsyncedWarning(Object count);

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete and sign out button text
  ///
  /// In en, this message translates to:
  /// **'Delete & Sign Out'**
  String get deleteSignOut;

  /// Sync and sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sync & Sign Out'**
  String get syncSignOut;

  /// Sign out confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? All local data will be cleared.'**
  String get confirmSignOut;

  /// Success message for sync
  ///
  /// In en, this message translates to:
  /// **'Sync successful! Signing out...'**
  String get syncSuccessful;

  /// Failure message for sync
  ///
  /// In en, this message translates to:
  /// **'Sync failed. {count} items remaining.'**
  String syncFailed(Object count);

  /// Error message for sync failure
  ///
  /// In en, this message translates to:
  /// **'Sync error: {error}'**
  String syncError(Object error);

  /// Low stock alert message
  ///
  /// In en, this message translates to:
  /// **'⚠️ Alert: {count} products are low on stock!'**
  String lowStockAlert(Object count);

  /// View button text
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get view;

  /// Logout failure message
  ///
  /// In en, this message translates to:
  /// **'Logout failed: {error}'**
  String logoutFailed(Object error);

  /// Default officer name
  ///
  /// In en, this message translates to:
  /// **'Officer'**
  String get officer;

  /// Default email placeholder
  ///
  /// In en, this message translates to:
  /// **'email@example.com'**
  String get defaultEmail;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get manageProducts;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get item;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @tapAddFirstProduct.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first product'**
  String get tapAddFirstProduct;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get tryDifferentSearch;

  /// No description provided for @scanProductBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan product barcode to search'**
  String get scanProductBarcode;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'LOCAL'**
  String get local;

  /// No description provided for @sku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get sku;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get available;

  /// No description provided for @failedToLoadProducts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load products'**
  String get failedToLoadProducts;

  /// No description provided for @productDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product deleted successfully'**
  String get productDeletedSuccessfully;

  /// No description provided for @failedToDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete product'**
  String get failedToDeleteProduct;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @areYouSureDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String areYouSureDeleteProduct(Object name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @viewStock.
  ///
  /// In en, this message translates to:
  /// **'View Stock'**
  String get viewStock;

  /// No description provided for @stockInfo.
  ///
  /// In en, this message translates to:
  /// **'Stock Info'**
  String get stockInfo;

  /// No description provided for @productType.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get productType;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @bulkStock.
  ///
  /// In en, this message translates to:
  /// **'Bulk Stock'**
  String get bulkStock;

  /// No description provided for @trackedItemsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Tracked Items (available)'**
  String get trackedItemsAvailable;

  /// No description provided for @totalAvailable.
  ///
  /// In en, this message translates to:
  /// **'Total Available'**
  String get totalAvailable;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @couldNotLoadStockDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not load stock details'**
  String get couldNotLoadStockDetails;

  /// No description provided for @addProductItem.
  ///
  /// In en, this message translates to:
  /// **'Add Product Item'**
  String get addProductItem;

  /// No description provided for @debugInformation.
  ///
  /// In en, this message translates to:
  /// **'Debug Information'**
  String get debugInformation;

  /// No description provided for @debugInfoPrinted.
  ///
  /// In en, this message translates to:
  /// **'Debug information has been printed to the console.'**
  String get debugInfoPrinted;

  /// No description provided for @checkConsoleOutput.
  ///
  /// In en, this message translates to:
  /// **'Check the console output for detailed information about:'**
  String get checkConsoleOutput;

  /// No description provided for @userAuthDataStructure.
  ///
  /// In en, this message translates to:
  /// **'User authentication data structure'**
  String get userAuthDataStructure;

  /// No description provided for @tokenLocationFormat.
  ///
  /// In en, this message translates to:
  /// **'Token location and format'**
  String get tokenLocationFormat;

  /// No description provided for @pendingProductsStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending products status'**
  String get pendingProductsStatus;

  /// No description provided for @databaseSyncState.
  ///
  /// In en, this message translates to:
  /// **'Database synchronization state'**
  String get databaseSyncState;

  /// No description provided for @informationHelpTroubleshoot.
  ///
  /// In en, this message translates to:
  /// **'This information will help troubleshoot sync issues.'**
  String get informationHelpTroubleshoot;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @syncPendingProducts.
  ///
  /// In en, this message translates to:
  /// **'Sync pending products'**
  String get syncPendingProducts;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @debugSyncIssues.
  ///
  /// In en, this message translates to:
  /// **'Debug sync issues'**
  String get debugSyncIssues;

  /// No description provided for @successfullySyncedProducts.
  ///
  /// In en, this message translates to:
  /// **'Successfully synced {count} product{countPlural}'**
  String successfullySyncedProducts(Object count, Object countPlural);

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'product'**
  String get product;

  /// No description provided for @failedToSyncProducts.
  ///
  /// In en, this message translates to:
  /// **'{count} product{countPlural} failed to sync'**
  String failedToSyncProducts(Object count, Object countPlural);

  /// No description provided for @noProductsToSync.
  ///
  /// In en, this message translates to:
  /// **'No products to sync'**
  String get noProductsToSync;

  /// No description provided for @syncFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {message}'**
  String syncFailedMessage(Object message);

  /// No description provided for @syncErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Sync error: {error}'**
  String syncErrorMessage(Object error);

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// Page title for sale details
  ///
  /// In en, this message translates to:
  /// **'Sale Details'**
  String get saleDetails;

  /// Section title for purchased items
  ///
  /// In en, this message translates to:
  /// **'Items Purchased'**
  String get itemsPurchased;

  /// Customer section label
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// Refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Invoice button tooltip
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// Dialog title when invoice is ready
  ///
  /// In en, this message translates to:
  /// **'Invoice Ready'**
  String get invoiceReady;

  /// Print invoice button text
  ///
  /// In en, this message translates to:
  /// **'Print Invoice'**
  String get printInvoice;

  /// Email invoice button text
  ///
  /// In en, this message translates to:
  /// **'Email Invoice'**
  String get emailInvoice;

  /// Share invoice button text
  ///
  /// In en, this message translates to:
  /// **'Share Invoice'**
  String get shareInvoice;

  /// WhatsApp share button text
  ///
  /// In en, this message translates to:
  /// **'Share via WhatsApp'**
  String get shareViaWhatsApp;

  /// Paid status indicator
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get paid;

  /// Loan status indicator
  ///
  /// In en, this message translates to:
  /// **'LOAN'**
  String get loan;

  /// Subtotal label
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// Discount label
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// Total amount label
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Error message when sharing invoice fails
  ///
  /// In en, this message translates to:
  /// **'Error sharing invoice'**
  String get errorSharingInvoice;

  /// Email greeting
  ///
  /// In en, this message translates to:
  /// **'Dear Customer'**
  String get dearCustomer;

  /// Email body for invoice sharing
  ///
  /// In en, this message translates to:
  /// **'Please find attached the invoice for your recent purchase.\n\nThank you for shopping with us!'**
  String get invoiceEmailBody;

  /// PDF invoice header
  ///
  /// In en, this message translates to:
  /// **'INVOICE'**
  String get invoicePdfTitle;

  /// PDF bill to section
  ///
  /// In en, this message translates to:
  /// **'Bill To:'**
  String get billTo;

  /// Table header for item description
  ///
  /// In en, this message translates to:
  /// **'Item Description'**
  String get itemDescription;

  /// Table header for quantity
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// Table header for unit price
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get unitPrice;

  /// Table header for total
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// PDF total amount label
  ///
  /// In en, this message translates to:
  /// **'TOTAL AMOUNT'**
  String get totalAmountPdf;

  /// PDF footer thank you message
  ///
  /// In en, this message translates to:
  /// **'Thank you for choosing {company}!'**
  String thankYouChoosing(Object company);

  /// PDF generation timestamp
  ///
  /// In en, this message translates to:
  /// **'Generated on {date}'**
  String generatedOn(Object date);

  /// Telephone label
  ///
  /// In en, this message translates to:
  /// **'Tel:'**
  String get tel;

  /// Email label
  ///
  /// In en, this message translates to:
  /// **'Email:'**
  String get emailLabel;

  /// Default customer for cash sales
  ///
  /// In en, this message translates to:
  /// **'Walk-in Customer'**
  String get walkInCustomer;

  /// Description for cash sales
  ///
  /// In en, this message translates to:
  /// **'Cash Sale • No specific address provided'**
  String get cashSale;

  /// Label for registered customers
  ///
  /// In en, this message translates to:
  /// **'Registered Customer'**
  String get registeredCustomer;

  /// Items count display
  ///
  /// In en, this message translates to:
  /// **'{count} Items'**
  String itemsCount(Object count);

  /// Fallback for missing product names
  ///
  /// In en, this message translates to:
  /// **'Unknown Product'**
  String get unknownProduct;

  /// Fallback for unnamed items
  ///
  /// In en, this message translates to:
  /// **'Unnamed Item'**
  String get unnamedItem;

  /// Generic unknown label
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Walk-in sale description
  ///
  /// In en, this message translates to:
  /// **'Walk-in Sale'**
  String get walkInSale;

  /// Page title for sales analytics
  ///
  /// In en, this message translates to:
  /// **'Sales Analytics'**
  String get salesAnalytics;

  /// Analytics page subtitle
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days Overview'**
  String get last7DaysOverview;

  /// Total revenue label
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// Total sales label
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get totalSales;

  /// Date column header
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Day column header
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// Sales count column header
  ///
  /// In en, this message translates to:
  /// **'Sales Count'**
  String get salesCount;

  /// Revenue trend chart title
  ///
  /// In en, this message translates to:
  /// **'Revenue Trend'**
  String get revenueTrend;

  /// Weekly period indicator
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// Daily breakdown section title
  ///
  /// In en, this message translates to:
  /// **'Daily Breakdown'**
  String get dailyBreakdown;

  /// Sales by category section title
  ///
  /// In en, this message translates to:
  /// **'Sales by Category'**
  String get salesByCategory;

  /// Top selling products section title
  ///
  /// In en, this message translates to:
  /// **'Top Selling Products'**
  String get topSellingProducts;

  /// Top products for selected category
  ///
  /// In en, this message translates to:
  /// **'Top Products (Selected Category)'**
  String get topProductsSelectedCategory;

  /// Default category name
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// Message when no category data is available
  ///
  /// In en, this message translates to:
  /// **'No category data available'**
  String get noCategoryDataAvailable;

  /// Message when no sales data is available
  ///
  /// In en, this message translates to:
  /// **'No sales data available'**
  String get noSalesDataAvailable;

  /// Units sold label
  ///
  /// In en, this message translates to:
  /// **'units sold'**
  String get unitsSold;

  /// PDF report title
  ///
  /// In en, this message translates to:
  /// **'Sales Summary Report'**
  String get salesSummaryReport;

  /// PDF performance section title
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days Performance'**
  String get last7DaysPerformance;

  /// Error message for Excel export
  ///
  /// In en, this message translates to:
  /// **'Error exporting Excel'**
  String get errorExportingExcel;

  /// Select date range placeholder
  ///
  /// In en, this message translates to:
  /// **'Select Range'**
  String get selectRange;

  /// Comparison indicator
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get vs;

  /// Message when there are no pending sales
  ///
  /// In en, this message translates to:
  /// **'All sales are synced'**
  String get allSalesSynced;

  /// Button text to sync individual sale
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// Button tooltip to sync all pending sales
  ///
  /// In en, this message translates to:
  /// **'Sync All'**
  String get syncAll;

  /// Success message when a sale is synced
  ///
  /// In en, this message translates to:
  /// **'Sale synced successfully'**
  String get saleSyncedSuccessfully;

  /// Error message when sync fails with specific message
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {message}'**
  String syncFailedWithMessage(Object message);

  /// General error message format
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(Object error);

  /// Progress message showing sync results
  ///
  /// In en, this message translates to:
  /// **'Synced {count} of {total} sales'**
  String syncedCountOfTotal(Object count, Object total);

  /// Error message when user is not authenticated
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financialOverview;

  /// No description provided for @estProfit.
  ///
  /// In en, this message translates to:
  /// **'Est. Profit'**
  String get estProfit;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @netIncome.
  ///
  /// In en, this message translates to:
  /// **'Net Income'**
  String get netIncome;

  /// No description provided for @businessInventory.
  ///
  /// In en, this message translates to:
  /// **'Business & Inventory'**
  String get businessInventory;

  /// No description provided for @totalProducts.
  ///
  /// In en, this message translates to:
  /// **'Total Products'**
  String get totalProducts;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Account Balance'**
  String get accountBalance;

  /// No description provided for @stockValueCost.
  ///
  /// In en, this message translates to:
  /// **'Stock Value (Cost)'**
  String get stockValueCost;

  /// No description provided for @todaysPerformanceByShop.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Performance by Shop'**
  String get todaysPerformanceByShop;

  /// No description provided for @allShops.
  ///
  /// In en, this message translates to:
  /// **'All Shops'**
  String get allShops;

  /// No description provided for @tenantName.
  ///
  /// In en, this message translates to:
  /// **'Tenant Name'**
  String get tenantName;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @myShops.
  ///
  /// In en, this message translates to:
  /// **'My Shops'**
  String get myShops;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @serverSync.
  ///
  /// In en, this message translates to:
  /// **'Server Sync'**
  String get serverSync;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Today Sales'**
  String get todaySales;

  /// No description provided for @todayProfit.
  ///
  /// In en, this message translates to:
  /// **'Today Profit'**
  String get todayProfit;

  /// No description provided for @shopSettings.
  ///
  /// In en, this message translates to:
  /// **'Shop Settings'**
  String get shopSettings;

  /// No description provided for @viewFullReport.
  ///
  /// In en, this message translates to:
  /// **'View Full Report'**
  String get viewFullReport;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @performanceToday.
  ///
  /// In en, this message translates to:
  /// **'Performance Today'**
  String get performanceToday;

  /// No description provided for @stockCount.
  ///
  /// In en, this message translates to:
  /// **'Stock Count'**
  String get stockCount;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get created;

  /// No description provided for @noShopActivity.
  ///
  /// In en, this message translates to:
  /// **'No shop activity recorded today'**
  String get noShopActivity;

  /// No description provided for @retryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get retryConnection;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @refreshInventory.
  ///
  /// In en, this message translates to:
  /// **'Refresh Inventory'**
  String get refreshInventory;

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost Price'**
  String get costPrice;

  /// No description provided for @sellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get sellingPrice;

  /// No description provided for @margin.
  ///
  /// In en, this message translates to:
  /// **'MARGIN'**
  String get margin;

  /// No description provided for @waitingForSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sync...'**
  String get waitingForSync;

  /// No description provided for @noLocalProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No Local Products Found'**
  String get noLocalProductsFound;

  /// No description provided for @addProductsOrSync.
  ///
  /// In en, this message translates to:
  /// **'Add products or sync from server'**
  String get addProductsOrSync;

  /// No description provided for @profitAndLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get profitAndLoss;

  /// No description provided for @manageOfficers.
  ///
  /// In en, this message translates to:
  /// **'Manage Officers'**
  String get manageOfficers;

  /// No description provided for @productCategories.
  ///
  /// In en, this message translates to:
  /// **'Product Categories'**
  String get productCategories;

  /// No description provided for @transactionsReport.
  ///
  /// In en, this message translates to:
  /// **'Transactions Report'**
  String get transactionsReport;

  /// No description provided for @inventoryAndAging.
  ///
  /// In en, this message translates to:
  /// **'Inventory & Aging'**
  String get inventoryAndAging;

  /// No description provided for @registerNewShop.
  ///
  /// In en, this message translates to:
  /// **'Register New Shop'**
  String get registerNewShop;

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon'**
  String get featureComingSoon;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
    case 'sw': return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
