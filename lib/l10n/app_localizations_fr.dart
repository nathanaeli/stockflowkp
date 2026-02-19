// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'StockFlow KP';

  @override
  String get subtitle => 'Gérez votre entreprise comme un pro.\nVentes • Inventaire • Clients • Rapports';

  @override
  String get enterButton => 'Entrer dans StockFlow KP';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mot de passe';

  @override
  String get login => 'Connexion';

  @override
  String get enterEmail => 'Entrez votre email';

  @override
  String get enterPassword => 'Entrez votre mot de passe';

  @override
  String get loginFailed => 'Échec de la connexion';

  @override
  String get loginSuccessful => 'Connexion réussie';

  @override
  String get stockflowKP => 'StockFlowKP';

  @override
  String get winTheDream => 'GAGNEZ LE RÊVE';

  @override
  String helloOfficer(Object name) {
    return 'Bonjour, $name 👋';
  }

  @override
  String get readyForTasks => 'Prêt pour les tâches d\'aujourd\'hui ?';

  @override
  String get todaysSales => 'Ventes d\'Aujourd\'hui';

  @override
  String get unsynced => 'Non synchronisé';

  @override
  String get lowStock => 'Stock Faible';

  @override
  String get home => 'Accueil';

  @override
  String get analytics => 'Analytique';

  @override
  String get products => 'produits';

  @override
  String get clients => 'Clients';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get pendingSales => 'Ventes en Attente';

  @override
  String get checkStock => 'Vérifier le Stock';

  @override
  String get activityLog => 'Journal d\'Activité';

  @override
  String get barcodeGenerator => 'Générateur de Code-barres';

  @override
  String get backupRestore => 'Sauvegarde & Restauration';

  @override
  String get howToUse => 'Comment l\'utiliser';

  @override
  String get support => 'Support';

  @override
  String get signOut => 'Se Déconnecter';

  @override
  String get newSale => 'Nouvelle Vente';

  @override
  String get sales => 'Ventes';

  @override
  String get categories => 'Catégories';

  @override
  String get permissions => 'Permissions';

  @override
  String get customers => 'Clients';

  @override
  String get myCompany => 'Mon Entreprise';

  @override
  String get proforma => 'Devis';

  @override
  String get invoices => 'Factures';

  @override
  String get unsyncedData => 'Données Non Synchronisées';

  @override
  String unsyncedWarning(Object count) {
    return 'Vous avez $count éléments en attente qui n\'ont pas encore été synchronisés. Vous déconnecter maintenant supprimera définitivement ces données.';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get deleteSignOut => 'Supprimer & Se Déconnecter';

  @override
  String get syncSignOut => 'Synchroniser & Se Déconnecter';

  @override
  String get confirmSignOut => 'Êtes-vous sûr de vouloir vous déconnecter ? Toutes les données locales seront effacées.';

  @override
  String get syncSuccessful => 'Synchronisation réussie ! Déconnexion...';

  @override
  String syncFailed(Object count) {
    return 'Synchronisation échouée. $count éléments restants.';
  }

  @override
  String syncError(Object error) {
    return 'Erreur de synchronisation : $error';
  }

  @override
  String lowStockAlert(Object count) {
    return '⚠️ Alerte : $count produits ont un stock faible !';
  }

  @override
  String get view => 'VOIR';

  @override
  String logoutFailed(Object error) {
    return 'Déconnexion échouée : $error';
  }

  @override
  String get officer => 'Agent';

  @override
  String get defaultEmail => 'email@exemple.com';

  @override
  String get manageProducts => 'Gérer les Produits';

  @override
  String get items => 'articles';

  @override
  String get item => 'article';

  @override
  String get searchProducts => 'Rechercher des produits...';

  @override
  String get noProductsYet => 'Aucun produit pour le moment';

  @override
  String get tapAddFirstProduct => 'Appuyez sur + pour ajouter votre premier produit';

  @override
  String get noProductsFound => 'Aucun produit trouvé';

  @override
  String get tryDifferentSearch => 'Essayez un terme de recherche différent';

  @override
  String get scanProductBarcode => 'Scannez le code-barres du produit pour rechercher';

  @override
  String get scan => 'Scanner';

  @override
  String get addProduct => 'Ajouter un Produit';

  @override
  String get local => 'LOCAL';

  @override
  String get sku => 'SKU';

  @override
  String get description => 'Description';

  @override
  String get noDescription => 'Aucune description';

  @override
  String get available => 'disponible';

  @override
  String get failedToLoadProducts => 'Échec du chargement des produits';

  @override
  String get productDeletedSuccessfully => 'Produit supprimé avec succès';

  @override
  String get failedToDeleteProduct => 'Échec de la suppression du produit';

  @override
  String get deleteProduct => 'Supprimer le Produit';

  @override
  String areYouSureDeleteProduct(Object name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ? Cette action ne peut pas être annulée.';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get viewStock => 'Voir le Stock';

  @override
  String get stockInfo => 'Informations sur le Stock';

  @override
  String get productType => 'Type de Produit';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String get bulkStock => 'Stock en Gros';

  @override
  String get trackedItemsAvailable => 'Articles Suivis (disponibles)';

  @override
  String get totalAvailable => 'Total Disponible';

  @override
  String get close => 'Fermer';

  @override
  String get couldNotLoadStockDetails => 'Impossible de charger les détails du stock';

  @override
  String get addProductItem => 'Ajouter un Article de Produit';

  @override
  String get debugInformation => 'Informations de Débogage';

  @override
  String get debugInfoPrinted => 'Les informations de débogage ont été imprimées dans la console.';

  @override
  String get checkConsoleOutput => 'Vérifiez la sortie de la console pour des informations détaillées sur :';

  @override
  String get userAuthDataStructure => 'Structure des données d\'authentification utilisateur';

  @override
  String get tokenLocationFormat => 'Emplacement et format du token';

  @override
  String get pendingProductsStatus => 'Statut des produits en attente';

  @override
  String get databaseSyncState => 'État de synchronisation de la base de données';

  @override
  String get informationHelpTroubleshoot => 'Ces informations aideront à résoudre les problèmes de synchronisation.';

  @override
  String get ok => 'OK';

  @override
  String get sort => 'Trier';

  @override
  String get name => 'Nom';

  @override
  String get price => 'Prix';

  @override
  String get syncPendingProducts => 'Synchroniser les produits en attente';

  @override
  String get syncing => 'Synchronisation...';

  @override
  String get sync => 'Synchroniser';

  @override
  String get debugSyncIssues => 'Déboguer les problèmes de synchronisation';

  @override
  String successfullySyncedProducts(Object count, Object countPlural) {
    return '$count produit$countPlural synchronisé$countPlural avec succès';
  }

  @override
  String get product => 'produit';

  @override
  String failedToSyncProducts(Object count, Object countPlural) {
    return '$count produit$countPlural a échoué à se synchroniser';
  }

  @override
  String get noProductsToSync => 'Aucun produit à synchroniser';

  @override
  String syncFailedMessage(Object message) {
    return 'Synchronisation échouée : $message';
  }

  @override
  String syncErrorMessage(Object error) {
    return 'Erreur de synchronisation : $error';
  }

  @override
  String get left => 'restant';

  @override
  String get saleDetails => 'Détails de la Vente';

  @override
  String get itemsPurchased => 'Articles Achetés';

  @override
  String get customer => 'Client';

  @override
  String get refresh => 'Actualiser';

  @override
  String get invoice => 'Facture';

  @override
  String get invoiceReady => 'Facture Prête';

  @override
  String get printInvoice => 'Imprimer la Facture';

  @override
  String get emailInvoice => 'Envoyer la Facture par Email';

  @override
  String get shareInvoice => 'Share Invoice';

  @override
  String get shareViaWhatsApp => 'Share via WhatsApp';

  @override
  String get paid => 'PAYÉ';

  @override
  String get loan => 'PRÊT';

  @override
  String get subtotal => 'Sous-total';

  @override
  String get discount => 'Remise';

  @override
  String get totalAmount => 'Montant Total';

  @override
  String get errorSharingInvoice => 'Erreur lors du partage de la facture';

  @override
  String get dearCustomer => 'Cher Client';

  @override
  String get invoiceEmailBody => 'Veuillez trouver ci-joint la facture de votre achat récent.\n\nMerci d\'avoir acheté chez nous !';

  @override
  String get invoicePdfTitle => 'FACTURE';

  @override
  String get billTo => 'Facturer à :';

  @override
  String get itemDescription => 'Description de l\'Article';

  @override
  String get qty => 'Qté';

  @override
  String get unitPrice => 'Prix Unitaire';

  @override
  String get total => 'Total';

  @override
  String get totalAmountPdf => 'MONTANT TOTAL';

  @override
  String thankYouChoosing(Object company) {
    return 'Merci d\'avoir choisi $company !';
  }

  @override
  String generatedOn(Object date) {
    return 'Généré le $date';
  }

  @override
  String get tel => 'Tél :';

  @override
  String get emailLabel => 'Email :';

  @override
  String get walkInCustomer => 'Client Passant';

  @override
  String get cashSale => 'Vente Comptoir • Aucune adresse spécifique fournie';

  @override
  String get registeredCustomer => 'Client Enregistré';

  @override
  String itemsCount(Object count) {
    return '$count Articles';
  }

  @override
  String get unknownProduct => 'Produit Inconnu';

  @override
  String get unnamedItem => 'Article Sans Nom';

  @override
  String get unknown => 'Inconnu';

  @override
  String get walkInSale => 'Vente Passant';

  @override
  String get salesAnalytics => 'Analytique des Ventes';

  @override
  String get last7DaysOverview => 'Aperçu des 7 Derniers Jours';

  @override
  String get totalRevenue => 'Revenus Totaux';

  @override
  String get totalSales => 'Ventes Totales';

  @override
  String get date => 'Date';

  @override
  String get day => 'Jour';

  @override
  String get salesCount => 'Nombre de Ventes';

  @override
  String get revenueTrend => 'Tendance des Revenus';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get dailyBreakdown => 'Répartition Quotidienne';

  @override
  String get salesByCategory => 'Ventes par Catégorie';

  @override
  String get topSellingProducts => 'Produits les Plus Vendus';

  @override
  String get topProductsSelectedCategory => 'Meilleurs Produits (Catégorie Sélectionnée)';

  @override
  String get uncategorized => 'Non Classé';

  @override
  String get noCategoryDataAvailable => 'Aucune donnée de catégorie disponible';

  @override
  String get noSalesDataAvailable => 'Aucune donnée de vente disponible';

  @override
  String get unitsSold => 'unités vendues';

  @override
  String get salesSummaryReport => 'Rapport de Résumé des Ventes';

  @override
  String get last7DaysPerformance => 'Performance des 7 Derniers Jours';

  @override
  String get errorExportingExcel => 'Erreur lors de l\'exportation Excel';

  @override
  String get selectRange => 'Sélectionner une Plage';

  @override
  String get vs => 'vs';

  @override
  String get allSalesSynced => 'Toutes les ventes sont synchronisées';

  @override
  String get syncNow => 'Synchroniser Maintenant';

  @override
  String get syncAll => 'Tout Synchroniser';

  @override
  String get saleSyncedSuccessfully => 'Vente synchronisée avec succès';

  @override
  String syncFailedWithMessage(Object message) {
    return 'Synchronisation échouée : $message';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Erreur : $error';
  }

  @override
  String syncedCountOfTotal(Object count, Object total) {
    return '$count sur $total ventes synchronisées';
  }

  @override
  String get notAuthenticated => 'Non authentifié';

  @override
  String get financialOverview => 'Aperçu Financier';

  @override
  String get estProfit => 'Profit Est.';

  @override
  String get expenses => 'Dépenses';

  @override
  String get netIncome => 'Revenu Net';

  @override
  String get businessInventory => 'Entreprise & Inventaire';

  @override
  String get totalProducts => 'Total Produits';

  @override
  String get accountBalance => 'Solde du Compte';

  @override
  String get stockValueCost => 'Valeur du Stock (Coût)';

  @override
  String get todaysPerformanceByShop => 'Performance Aujourd\'hui par Boutique';

  @override
  String get allShops => 'Toutes les Boutiques';

  @override
  String get tenantName => 'Nom du Locataire';

  @override
  String get role => 'Rôle';

  @override
  String get joined => 'Rejoint';

  @override
  String get editProfile => 'Modifier le Profil';

  @override
  String get myShops => 'Mes Boutiques';

  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Paramètres';

  @override
  String get serverSync => 'Sync Serveur';

  @override
  String get todaySales => 'Ventes Aujourd\'hui';

  @override
  String get todayProfit => 'Profit Aujourd\'hui';

  @override
  String get shopSettings => 'Paramètres de la Boutique';

  @override
  String get viewFullReport => 'Voir le Rapport Complet';

  @override
  String get management => 'Gestion';

  @override
  String get performanceToday => 'Performance Aujourd\'hui';

  @override
  String get stockCount => 'Compte de Stock';

  @override
  String get created => 'Créé le';

  @override
  String get noShopActivity => 'Aucune activité de boutique enregistrée aujourd\'hui';

  @override
  String get retryConnection => 'Réessayer la Connexion';

  @override
  String get somethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String get selectLanguage => 'Choisir la Langue';

  @override
  String get inventory => 'Inventaire';

  @override
  String get refreshInventory => 'Actualiser l\'Inventaire';

  @override
  String get costPrice => 'Prix de Revient';

  @override
  String get sellingPrice => 'Prix de Vente';

  @override
  String get margin => 'MARGE';

  @override
  String get waitingForSync => 'En attente de synchro...';

  @override
  String get noLocalProductsFound => 'Aucun Produit Local Trouvé';

  @override
  String get addProductsOrSync => 'Ajoutez des produits ou synchronisez depuis le serveur';

  @override
  String get profitAndLoss => 'Pertes et Profits';

  @override
  String get manageOfficers => 'Gérer les Agents';

  @override
  String get productCategories => 'Catégories de Produits';

  @override
  String get transactionsReport => 'Rapport de Transactions';

  @override
  String get inventoryAndAging => 'Inventaire et Vieillissement';

  @override
  String get registerNewShop => 'Enregistrer une Nouvelle Boutique';

  @override
  String get featureComingSoon => 'Fonctionnalité à venir';
}
