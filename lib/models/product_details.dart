class ProductDetails {
  final BasicInfo basicInfo;
  final Pricing pricing;
  final Category category;
  final DukaInfo duka;
  final StockSummary stockSummary;
  final ProfitAnalysis profitAnalysis;
  final List<StockDetail> currentStockDetails;
  final List<ProductItem> productItems;
  final List<SaleRecord> salesHistory;
  final List<StockMovement> stockMovements;
  final List<StockTransfer> stockTransfers;

  ProductDetails({
    required this.basicInfo,
    required this.pricing,
    required this.category,
    required this.duka,
    required this.stockSummary,
    required this.profitAnalysis,
    required this.currentStockDetails,
    required this.productItems,
    required this.salesHistory,
    required this.stockMovements,
    required this.stockTransfers,
  });

  factory ProductDetails.fromJson(Map<String, dynamic> json) {
    return ProductDetails(
      basicInfo: BasicInfo.fromJson(json['basic_info']),
      pricing: Pricing.fromJson(json['pricing']),
      category: Category.fromJson(json['category']),
      duka: DukaInfo.fromJson(json['duka']),
      stockSummary: StockSummary.fromJson(json['stock_summary']),
      profitAnalysis: ProfitAnalysis.fromJson(json['profit_analysis']),
      currentStockDetails: (json['current_stock_details'] as List)
          .map((e) => StockDetail.fromJson(e))
          .toList(),
      productItems: (json['product_items'] as List)
          .map((e) => ProductItem.fromJson(e))
          .toList(),
      salesHistory: (json['sales_history'] as List)
          .map((e) => SaleRecord.fromJson(e))
          .toList(),
      stockMovements: (json['stock_movements'] as List)
          .map((e) => StockMovement.fromJson(e))
          .toList(),
      stockTransfers: (json['stock_transfers'] as List)
          .map((e) => StockTransfer.fromJson(e))
          .toList(),
    );
  }
}

class BasicInfo {
  final int id;
  final String sku;
  final String name;
  final String? description;
  final String unit;
  final String? barcode;
  final String? imageUrl;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  BasicInfo({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.unit,
    required this.barcode,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BasicInfo.fromJson(Map<String, dynamic> json) {
    return BasicInfo(
      id: json['id'],
      sku: json['sku'],
      name: json['name'],
      description: json['description'],
      unit: json['unit'],
      barcode: json['barcode'],
      imageUrl: json['image_url'],
      isActive: json['is_active'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class Pricing {
  final double basePrice;
  final double sellingPrice;
  final double profitPerUnit;
  final double profitMargin;
  final String formattedBasePrice;
  final String formattedSellingPrice;

  Pricing({
    required this.basePrice,
    required this.sellingPrice,
    required this.profitPerUnit,
    required this.profitMargin,
    required this.formattedBasePrice,
    required this.formattedSellingPrice,
  });

  factory Pricing.fromJson(Map<String, dynamic> json) {
    return Pricing(
      basePrice: (json['base_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      profitPerUnit: (json['profit_per_unit'] as num).toDouble(),
      profitMargin: (json['profit_margin'] as num).toDouble(),
      formattedBasePrice: json['formatted_base_price'],
      formattedSellingPrice: json['formatted_selling_price'],
    );
  }
}

class Category {
  final int id;
  final String name;
  final String? description;

  Category({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }
}

class DukaInfo {
  final int id;
  final String name;
  final String? location;

  DukaInfo({
    required this.id,
    required this.name,
    required this.location,
  });

  factory DukaInfo.fromJson(Map<String, dynamic> json) {
    return DukaInfo(
      id: json['id'],
      name: json['name'],
      location: json['location'],
    );
  }
}

class StockSummary {
  final int currentStock;
  final double stockCostValue;
  final double stockSellingValue;
  final double totalProfitPotential;
  final String stockStatus;

  StockSummary({
    required this.currentStock,
    required this.stockCostValue,
    required this.stockSellingValue,
    required this.totalProfitPotential,
    required this.stockStatus,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      currentStock: json['current_stock'],
      stockCostValue: (json['stock_cost_value'] as num).toDouble(),
      stockSellingValue: (json['stock_selling_value'] as num).toDouble(),
      totalProfitPotential: (json['total_profit_potential'] as num).toDouble(),
      stockStatus: json['stock_status'],
    );
  }
}

class ProfitAnalysis {
  final int totalSold;
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double profitMargin;
  final double averageSellingPrice;

  ProfitAnalysis({
    required this.totalSold,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.profitMargin,
    required this.averageSellingPrice,
  });

  factory ProfitAnalysis.fromJson(Map<String, dynamic> json) {
    return ProfitAnalysis(
      totalSold: json['total_sold'],
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      totalProfit: (json['total_profit'] as num).toDouble(),
      profitMargin: (json['profit_margin'] as num).toDouble(),
      averageSellingPrice: (json['average_selling_price'] as num).toDouble(),
    );
  }
}

class StockDetail {
  final int id;
  final int quantity;
  final String batchNumber;
  final String? expiryDate;
  final String? notes;
  final String value;
  final String status;
  final String lastUpdatedBy;
  final String updatedAt;

  StockDetail({
    required this.id,
    required this.quantity,
    required this.batchNumber,
    required this.expiryDate,
    required this.notes,
    required this.value,
    required this.status,
    required this.lastUpdatedBy,
    required this.updatedAt,
  });

  factory StockDetail.fromJson(Map<String, dynamic> json) {
    return StockDetail(
      id: json['id'],
      quantity: json['quantity'],
      batchNumber: json['batch_number'],
      expiryDate: json['expiry_date'],
      notes: json['notes'],
      value: json['value'],
      status: json['status'],
      lastUpdatedBy: json['last_updated_by'],
      updatedAt: json['updated_at'],
    );
  }
}

class ProductItem {
  final int id;
  final String qrCode;
  final String status;
  final int stockAmount;
  final String? soldAt;
  final String createdAt;

  ProductItem({
    required this.id,
    required this.qrCode,
    required this.status,
    required this.stockAmount,
    required this.soldAt,
    required this.createdAt,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'],
      qrCode: json['qr_code'],
      status: json['status'],
      stockAmount: json['stock_amount'],
      soldAt: json['sold_at'],
      createdAt: json['created_at'],
    );
  }
}

class SaleRecord {
  final int saleId;
  final String saleDate;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final double profitPerUnit;
  final double totalProfit;
  final bool isLoan;
  final String paymentStatus;

  SaleRecord({
    required this.saleId,
    required this.saleDate,
    required this.customerName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.profitPerUnit,
    required this.totalProfit,
    required this.isLoan,
    required this.paymentStatus,
  });

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      saleId: json['sale_id'],
      saleDate: json['sale_date'],
      customerName: json['customer_name'],
      quantity: json['quantity'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      profitPerUnit: (json['profit_per_unit'] as num).toDouble(),
      totalProfit: (json['total_profit'] as num).toDouble(),
      isLoan: json['is_loan'],
      paymentStatus: json['payment_status'],
    );
  }
}

class StockMovement {
  final int id;
  final String type;
  final String quantityChange;
  final int previousQuantity;
  final int newQuantity;
  final String? batchNumber;
  final String? expiryDate;
  final String? notes;
  final String reason;
  final String userName;
  final String createdAt;

  StockMovement({
    required this.id,
    required this.type,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    required this.batchNumber,
    required this.expiryDate,
    required this.notes,
    required this.reason,
    required this.userName,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'],
      type: json['type'],
      quantityChange: json['quantity_change'],
      previousQuantity: json['previous_quantity'],
      newQuantity: json['new_quantity'],
      batchNumber: json['batch_number'],
      expiryDate: json['expiry_date'],
      notes: json['notes'],
      reason: json['reason'],
      userName: json['user_name'],
      createdAt: json['created_at'],
    );
  }
}

class StockTransfer {
  final int id;
  final int fromDukaId;
  final int toDukaId;
  final String status;
  final int quantity;
  final String createdAt;
  final String updatedAt;

  StockTransfer({
    required this.id,
    required this.fromDukaId,
    required this.toDukaId,
    required this.status,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'],
      fromDukaId: json['from_duka_id'],
      toDukaId: json['to_duka_id'],
      status: json['status'],
      quantity: json['quantity'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}