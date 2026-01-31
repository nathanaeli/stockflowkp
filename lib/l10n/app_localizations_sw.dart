// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'StockFlowKp';

  @override
  String get subtitle => 'Simamia biashara yako kama mtaalamu.\nMauzo • Hesabu • Wateja • Ripoti';

  @override
  String get enterButton => 'Ingia StockFlowKp';

  @override
  String get email => 'Barua pepe';

  @override
  String get password => 'Nenosiri';

  @override
  String get login => 'Ingia';

  @override
  String get enterEmail => 'Ingiza barua pepe yako';

  @override
  String get enterPassword => 'Ingiza nenosiri lako';

  @override
  String get loginFailed => 'Kuingia kumeshindikana';

  @override
  String get loginSuccessful => 'Kuingia kufanikiwa';

  @override
  String get stockflowKP => 'StockFlowKp';

  @override
  String get winTheDream => 'WIN THE DREAM';

  @override
  String helloOfficer(Object name) {
    return 'Halo, $name 👋';
  }

  @override
  String get readyForTasks => 'Je, tayari kwa kazi za leo?';

  @override
  String get todaysSales => 'Mauzo ya Leo';

  @override
  String get unsynced => 'Haijaunganishwa';

  @override
  String get lowStock => 'Hifadhi Ndogo';

  @override
  String get home => 'Nyumbani';

  @override
  String get analytics => 'Takwimu';

  @override
  String get products => 'bidhaa';

  @override
  String get clients => 'Wateja';

  @override
  String get dashboard => 'Dashibodi';

  @override
  String get pendingSales => 'Mauzo yanayosubiri';

  @override
  String get checkStock => 'Angalia Hifadhi';

  @override
  String get activityLog => 'Kumbukumbu ya Shughuli';

  @override
  String get barcodeGenerator => 'Kichapishaji cha Barcode';

  @override
  String get backupRestore => 'Hifadhi & Rudisha';

  @override
  String get howToUse => 'Jinsi ya kuitumia';

  @override
  String get support => 'Msaada';

  @override
  String get signOut => 'Toka';

  @override
  String get newSale => 'Mauzo Mapya';

  @override
  String get sales => 'Mauzo';

  @override
  String get categories => 'Vikundi';

  @override
  String get permissions => 'Idhini';

  @override
  String get customers => 'Wateja';

  @override
  String get myCompany => 'Kampuni Yangu';

  @override
  String get proforma => 'Proforma';

  @override
  String get invoices => 'Pesi';

  @override
  String get unsyncedData => 'Data Haijaunganishwa';

  @override
  String unsyncedWarning(Object count) {
    return 'Una kitu $count kinachosubiri ambacho bakijaunganishwa. Kutoka sasa itafuta data hii kila mmoja.';
  }

  @override
  String get cancel => 'Ghairi';

  @override
  String get deleteSignOut => 'Futa & Toka';

  @override
  String get syncSignOut => 'Unganisha & Toka';

  @override
  String get confirmSignOut => 'Je, una uhakika unataka kutoka? Data zote za ndani zitafutwa.';

  @override
  String get syncSuccessful => 'Uunganishaji umefanikiwa! Kutoa...';

  @override
  String syncFailed(Object count) {
    return 'Uunganishaji umeshindikana. Vitu $count vimebaki.';
  }

  @override
  String syncError(Object error) {
    return 'Hitilafu ya uunganishaji: $error';
  }

  @override
  String lowStockAlert(Object count) {
    return '⚠️ Onyo: Bidhaa $count zina hifadhi ndogo!';
  }

  @override
  String get view => 'ANGALIA';

  @override
  String logoutFailed(Object error) {
    return 'Kutoa kumeshindikana: $error';
  }

  @override
  String get officer => 'Mwanajeshi';

  @override
  String get defaultEmail => 'barua.pepe@mfano.com';

  @override
  String get manageProducts => 'Simamia Bidhaa';

  @override
  String get items => 'vitu';

  @override
  String get item => 'kitu';

  @override
  String get searchProducts => 'Tafuta bidhaa...';

  @override
  String get noProductsYet => 'Bado hakuna bidhaa';

  @override
  String get tapAddFirstProduct => 'Gonga + kuongeza bidhaa yako ya kwanza';

  @override
  String get noProductsFound => 'Hakuna bidhaa zilizopatikana';

  @override
  String get tryDifferentSearch => 'Jaribu neno la utafutaji tofauti';

  @override
  String get scanProductBarcode => 'Changanua barcode ya bidhaa kutafuta';

  @override
  String get scan => 'Changanua';

  @override
  String get addProduct => 'Ongeza Bidhaa';

  @override
  String get local => 'MAELEZO';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Maelezo';

  @override
  String get noDescription => 'Hakuna maelezo';

  @override
  String get available => 'Inapatikana';

  @override
  String get failedToLoadProducts => 'Kushindwa kupakia bidhaa';

  @override
  String get productDeletedSuccessfully => 'Bidhaa imefutwa kwa mafanikio';

  @override
  String get failedToDeleteProduct => 'Kushindwa kufuta bidhaa';

  @override
  String get deleteProduct => 'Futa Bidhaa';

  @override
  String areYouSureDeleteProduct(Object name) {
    return 'Je, una uhakika unataka kufuta \"$name\"? Hatua hii haiwezi kubadilishwa.';
  }

  @override
  String get delete => 'Futa';

  @override
  String get viewStock => 'Angalia Hifadhi';

  @override
  String get stockInfo => 'Maelezo ya Hifadhi';

  @override
  String get productType => 'Aina ya Bidhaa';

  @override
  String get online => 'Mtandaoni';

  @override
  String get offline => 'Nje ya mtandao';

  @override
  String get bulkStock => 'Hifadhi ya Wingi';

  @override
  String get trackedItemsAvailable => 'Vitu vinavyofuatwa (vinavyopatikana)';

  @override
  String get totalAvailable => 'Jumla Inapatikana';

  @override
  String get close => 'Funga';

  @override
  String get couldNotLoadStockDetails => 'Haikuweza kupakia maelezo ya hifadhi';

  @override
  String get addProductItem => 'Ongeza Kitu cha Bidhaa';

  @override
  String get debugInformation => 'Maelezo ya Utatuzi';

  @override
  String get debugInfoPrinted => 'Maelezo ya utatuzi yamechapishwa kwa koni.';

  @override
  String get checkConsoleOutput => 'Angalia matokeo ya koni kwa maelezo ya kina kuhusu:';

  @override
  String get userAuthDataStructure => 'Muundo wa data ya uthibitishaji wa mtumiaji';

  @override
  String get tokenLocationFormat => 'Mahali na muundo wa tokeni';

  @override
  String get pendingProductsStatus => 'Hali ya bidhaa zinazosubiri';

  @override
  String get databaseSyncState => 'Hali ya uunganishaji wa hifadhidata';

  @override
  String get informationHelpTroubleshoot => 'Maelezo haya yatasaidia kutatua matatizo ya uunganishaji.';

  @override
  String get ok => 'Sawa';

  @override
  String get sort => 'Panga';

  @override
  String get name => 'Jina';

  @override
  String get price => 'Bei';

  @override
  String get syncPendingProducts => 'Unganisha bidhaa zinazosubiri';

  @override
  String get syncing => 'Inaunganisha...';

  @override
  String get sync => 'Unganisha';

  @override
  String get debugSyncIssues => 'Utatuzi wa matatizo ya uunganishaji';

  @override
  String successfullySyncedProducts(Object count, Object countPlural) {
    return 'Imefanikiwa kuunganisha bidhaa $count';
  }

  @override
  String get product => 'bidhaa';

  @override
  String failedToSyncProducts(Object count, Object countPlural) {
    return 'Bidhaa $count zimeshindikana kuunganishwa';
  }

  @override
  String get noProductsToSync => 'Hakuna bidhaa za kuunganisha';

  @override
  String syncFailedMessage(Object message) {
    return 'Uunganishaji umeshindikana: $message';
  }

  @override
  String syncErrorMessage(Object error) {
    return 'Hitilafu ya uunganishaji: $error';
  }

  @override
  String get left => 'imesalia';

  @override
  String get saleDetails => 'Maelezo ya Mauzo';

  @override
  String get itemsPurchased => 'Vitu Vilivyotumwa';

  @override
  String get customer => 'Mteja';

  @override
  String get refresh => 'Sasisha';

  @override
  String get invoice => 'Pesi';

  @override
  String get invoiceReady => 'Pesi Tayari';

  @override
  String get printInvoice => 'Chapisha Pesi';

  @override
  String get emailInvoice => 'Tuma Pesi Barua Pepe';

  @override
  String get shareInvoice => 'Share Invoice';

  @override
  String get shareViaWhatsApp => 'Share via WhatsApp';

  @override
  String get paid => 'IMALIPWA';

  @override
  String get loan => 'MKOPO';

  @override
  String get subtotal => 'Jumla ndogo';

  @override
  String get discount => 'Punguzo';

  @override
  String get totalAmount => 'Jumla ya Mwisho';

  @override
  String get errorSharingInvoice => 'Hitilafu ya kushirikisha pesi';

  @override
  String get dearCustomer => 'Mpendwa Mteja';

  @override
  String get invoiceEmailBody => 'Tafadhali attach pesi kwa ununuzi wako wa hivi karibuni.\n\nAsante kwa kununua nasi!';

  @override
  String get invoicePdfTitle => 'PESI';

  @override
  String get billTo => 'Lipa kwa:';

  @override
  String get itemDescription => 'Maelezo ya Kitu';

  @override
  String get qty => 'Idadi';

  @override
  String get unitPrice => 'Bei ya Kila';

  @override
  String get total => 'Jumla';

  @override
  String get totalAmountPdf => 'JUMLA YA MWISHO';

  @override
  String thankYouChoosing(Object company) {
    return 'Asante kwa kuchagua $company!';
  }

  @override
  String generatedOn(Object date) {
    return 'Imeundwa $date';
  }

  @override
  String get tel => 'Simu:';

  @override
  String get emailLabel => 'Barua pepe:';

  @override
  String get walkInCustomer => 'Mteja wa Duka';

  @override
  String get cashSale => 'Mauzi ya Fedha Taslimu • Hakuna anwani maalum iliyotolewa';

  @override
  String get registeredCustomer => 'Mteja Aliyesajiliwa';

  @override
  String itemsCount(Object count) {
    return 'Vitu $count';
  }

  @override
  String get unknownProduct => 'Bidhaa Isiyojulikana';

  @override
  String get unnamedItem => 'Kisiwa Kisicho na Jina';

  @override
  String get unknown => 'Haijulikani';

  @override
  String get walkInSale => 'Mauzi ya Duka';

  @override
  String get salesAnalytics => 'Takwimu za Mauzo';

  @override
  String get last7DaysOverview => 'Muhtasari wa Siku 7';

  @override
  String get totalRevenue => 'Jumla ya Mapato';

  @override
  String get totalSales => 'Jumla ya Mauzo';

  @override
  String get date => 'Tarehe';

  @override
  String get day => 'Siku';

  @override
  String get salesCount => 'Idadi ya Mauzo';

  @override
  String get revenueTrend => 'Mwelekeo wa Mapato';

  @override
  String get weekly => 'Wiki';

  @override
  String get dailyBreakdown => 'Mgawanyiko wa Kila Siku';

  @override
  String get salesByCategory => 'Mauzo kwa Kikundi';

  @override
  String get topSellingProducts => 'Bidhaa Zinazouzwa Zaidi';

  @override
  String get topProductsSelectedCategory => 'Bidhaa zaidi (Kikundi Kilichochaguliwa)';

  @override
  String get uncategorized => 'Isiyokuwa na Kikundi';

  @override
  String get noCategoryDataAvailable => 'Hakuna data za kikundi';

  @override
  String get noSalesDataAvailable => 'Hakuna data za mauzo';

  @override
  String get unitsSold => 'vitu vimeuzwa';

  @override
  String get salesSummaryReport => 'Ripoti ya Muhtasari wa Mauzo';

  @override
  String get last7DaysPerformance => 'Utendaji wa Siku 7';

  @override
  String get errorExportingExcel => 'Hitilafu ya kuuza Excel';

  @override
  String get selectRange => 'Chagua Kipindi';

  @override
  String get vs => 'dhidi ya';

  @override
  String get allSalesSynced => 'Mauzo yote yameunganishwa';

  @override
  String get syncNow => 'Unganisha Sasa';

  @override
  String get syncAll => 'Unganisha Yote';

  @override
  String get saleSyncedSuccessfully => 'Mauzo yameunganishwa kwa mafanikio';

  @override
  String syncFailedWithMessage(Object message) {
    return 'Uunganishaji umeshindikana: $message';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Hitilafu: $error';
  }

  @override
  String syncedCountOfTotal(Object count, Object total) {
    return 'Yameunganishwa $count kati ya $total ya mauzo';
  }

  @override
  String get notAuthenticated => 'Haijaithibitishwa';

  @override
  String get financialOverview => 'Mapitio ya Kifedha';

  @override
  String get estProfit => 'Faida Iliyokadiriwa';

  @override
  String get expenses => 'Gharama';

  @override
  String get netIncome => 'Mapato Halisi';

  @override
  String get businessInventory => 'Biashara na Mali';

  @override
  String get totalProducts => 'Jumla ya Bidhaa';

  @override
  String get accountBalance => 'Salio la Akaunti';

  @override
  String get stockValueCost => 'Thamani ya Mali (Gharama)';

  @override
  String get todaysPerformanceByShop => 'Utendaji wa Leo kwa Duka';

  @override
  String get allShops => 'Maduka Yote';

  @override
  String get tenantName => 'Jina la Mpangaji';

  @override
  String get role => 'Wadhifa';

  @override
  String get joined => 'Amejiunga';

  @override
  String get editProfile => 'Hariri Wasifu';

  @override
  String get myShops => 'Maduka Yangu';

  @override
  String get profile => 'Wasifu';

  @override
  String get settings => 'Mipangilio';

  @override
  String get serverSync => 'Usawazishaji wa Seva';

  @override
  String get todaySales => 'Mauzo ya Leo';

  @override
  String get todayProfit => 'Faida ya Leo';

  @override
  String get shopSettings => 'Mipangilio ya Duka';

  @override
  String get viewFullReport => 'Angalia Ripoti Kamili';

  @override
  String get management => 'Usimamizi';

  @override
  String get performanceToday => 'Utendaji wa Leo';

  @override
  String get stockCount => 'Idadi ya Mali';

  @override
  String get created => 'Imeundwa';

  @override
  String get noShopActivity => 'Hakuna shughuli za duka zilizorekodiwa leo';

  @override
  String get retryConnection => 'Jaribu Kuunganisha Tena';

  @override
  String get somethingWentWrong => 'Kuna hitilafu imetokea';

  @override
  String get selectLanguage => 'Chagua Lugha';

  @override
  String get inventory => 'Mali';

  @override
  String get refreshInventory => 'Sasisha Mali';

  @override
  String get costPrice => 'Bei ya Kununua';

  @override
  String get sellingPrice => 'Bei ya Kuuza';

  @override
  String get margin => 'FAIDA';

  @override
  String get waitingForSync => 'inasubiri kuunganishwa...';

  @override
  String get noLocalProductsFound => 'Hakuna Mali Iliyopatikana';

  @override
  String get addProductsOrSync => 'Ongeza bidhaa au unganisha kutoka kwa seva';

  @override
  String get profitAndLoss => 'Faida na Hasara';

  @override
  String get manageOfficers => 'Dhibiti Maafisa';

  @override
  String get productCategories => 'Aina za Bidhaa';

  @override
  String get transactionsReport => 'Ripoti ya Mauzo';

  @override
  String get inventoryAndAging => 'Mali na Uchakavu';

  @override
  String get registerNewShop => 'Sajili Duka Jipya';

  @override
  String get featureComingSoon => 'Kipengele hiki kinakuja hivi karibuni';
}
