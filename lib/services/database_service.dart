import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const _databaseName = 'masangura.db';
  static const _databaseVersion = 36;

  // Sync Status Constants
  static const int statusSynced = 1;
  static const int statusPending = 0;
  final _uuid = const Uuid();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Auth Table
    await db.execute(
      'CREATE TABLE user_data (id INTEGER PRIMARY KEY, data TEXT)',
    );

    // 1. Officer Profile (Usually one record)
    await db.execute('''CREATE TABLE officer (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      name TEXT, email TEXT, profile_picture TEXT, profile_picture_url TEXT,
      role TEXT, status TEXT, created_at TEXT, updated_at TEXT,
      email_verified_at TEXT, tenant_id INTEGER,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 2. Dukas
    await db.execute('''CREATE TABLE dukas (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, name TEXT, location TEXT, manager_name TEXT,
      latitude REAL, longitude REAL, status TEXT, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 3. Products
    await db.execute('''CREATE TABLE products (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, duka_id INTEGER, category_id INTEGER,
      sku TEXT, name TEXT, description TEXT, unit TEXT, base_price REAL,
      selling_price REAL, is_active INTEGER, image TEXT, image_url TEXT,
      barcode TEXT, created_at TEXT, updated_at TEXT, deleted_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 4. Stocks
    await db.execute('''CREATE TABLE stocks (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      product_id INTEGER, duka_id INTEGER, quantity INTEGER,
      last_updated_by INTEGER, created_at TEXT, updated_at TEXT,
      batch_number TEXT, expiry_date TEXT, notes TEXT, deleted_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 5. Sales
    await db.execute('''CREATE TABLE sales (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, duka_id INTEGER, customer_id INTEGER,
      total_amount REAL, discount_amount REAL, profit_loss REAL, is_loan INTEGER,
      due_date TEXT, payment_status TEXT, total_payments REAL, remaining_balance REAL,
      discount_reason TEXT, invoice_number TEXT, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 6. Categoriesb
    await db.execute('''CREATE TABLE categories (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, name TEXT, description TEXT, parent_id INTEGER,
      status TEXT, created_by INTEGER, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 7. Product Items
    await db.execute('''CREATE TABLE product_items (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      product_id INTEGER, qr_code TEXT, status TEXT,
      sold_at TEXT, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 8. Customers
    await db.execute('''CREATE TABLE customers (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, duka_id INTEGER, name TEXT,
      email TEXT, phone TEXT, address TEXT, status TEXT, created_by INTEGER,
      created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 9. Tenant Account
    await db.execute('''CREATE TABLE tenant_account (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      tenant_id INTEGER, company_name TEXT, logo TEXT, phone TEXT,
      email TEXT, address TEXT, currency TEXT, timezone TEXT,
      website TEXT, description TEXT, logo_url TEXT, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 10. Permissions
    await db.execute('''CREATE TABLE permissions (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      officer_id INTEGER, permission TEXT, created_at TEXT, updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 13. Stock Movements
    await db.execute('''CREATE TABLE stock_movements (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      stock_id INTEGER,
      product_id INTEGER,
      duka_id INTEGER,
      user_id INTEGER,
      quantity INTEGER,
      type TEXT,
      reason TEXT,
      quantity_change INTEGER,
      quantity_remaining INTEGER,
      previous_quantity INTEGER,
      new_quantity INTEGER,
      unit_cost REAL,
      unit_price REAL,
      created_at TEXT,
      updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 14. Loan Payments
    await db.execute('''CREATE TABLE loan_payments (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      sale_server_id INTEGER,
      amount REAL,
      payment_date TEXT,
      notes TEXT,
      user_id INTEGER,
      created_at TEXT,
      updated_at TEXT,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    await db.execute('''
  CREATE TABLE tenantsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER, -- Server ID
    name TEXT,
    slug TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    user_id INTEGER,
    status TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE tenant_accountsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    company_name TEXT,
    logo TEXT,
    currency TEXT,
    timezone TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE dukasinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    name TEXT,
    location TEXT,
    manager_name TEXT,
    latitude REAL,
    longitude REAL,
    status TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE tenant_officersinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    duka_id INTEGER,
    officer_id INTEGER,
    role TEXT,
    status INTEGER,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE product_categoriesinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    name TEXT,
    description TEXT,
    parent_id INTEGER,
    status TEXT,
    created_by INTEGER,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE productsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    duka_id INTEGER,
    category_id INTEGER,
    sku TEXT,
    name TEXT,
    description TEXT,
    unit TEXT,
    base_price REAL,
    selling_price REAL,
    is_active INTEGER,
    image TEXT,
    image_url TEXT,
    barcode TEXT,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE stocksinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    duka_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    last_updated_by INTEGER,
    batch_number TEXT,
    expiry_date TEXT,
    notes TEXT,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE product_itemsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    product_id INTEGER,
    qr_code TEXT,
    status TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE customersinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    duka_id INTEGER,
    name TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    status TEXT,
    created_by INTEGER,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE salesinfo (
    local_id TEXT PRIMARY KEY, -- Inatumika kuunganisha na sale_items hapa hapa simuni
    id INTEGER,
    tenant_id INTEGER,
    duka_id INTEGER,
    customer_id INTEGER,
    total_amount REAL,
    discount_amount REAL,
    profit_loss REAL,
    is_loan INTEGER,
    due_date TEXT,
    payment_status TEXT,
    total_payments REAL,
    remaining_balance REAL,
    discount_reason TEXT,
    invoice_number TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 0 -- Default ni 0 kwa mauzo mapya
  )
''');

    await db.execute('''
  CREATE TABLE sale_itemsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    sale_id INTEGER,
    local_sale_id TEXT, -- Inatafuta local_id ya salesinfo
    product_id INTEGER,
    product_item_id INTEGER,
    quantity INTEGER,
    unit_price REAL,
    discount_amount REAL,
    total REAL,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE loan_paymentsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    sale_id INTEGER,
    local_sale_id TEXT,
    amount REAL,
    payment_date TEXT,
    notes TEXT,
    user_id INTEGER,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE transactionsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    duka_id INTEGER,
    user_id INTEGER,
    type TEXT, -- income/expense
    amount REAL,
    category TEXT,
    status TEXT,
    payment_method TEXT,
    reference_id TEXT,
    description TEXT,
    transaction_date TEXT,
    created_at TEXT,
    updated_at TEXT,
    deleted_at TEXT,
    is_synced INTEGER DEFAULT 0
  )
''');

    await db.execute('''
  CREATE TABLE stock_movementsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    stock_id INTEGER,
    user_id INTEGER,
    product_item_id INTEGER,
    type TEXT,
    quantity_change INTEGER,
    quantity_remaining INTEGER,
    previous_quantity INTEGER,
    new_quantity INTEGER,
    unit_cost REAL,
    total_cost REAL,
    unit_price REAL,
    total_value REAL,
    batch_number TEXT,
    expiry_date TEXT,
    notes TEXT,
    reason TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE messagesinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    subject TEXT,
    body TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute('''
  CREATE TABLE duka_subscriptionsinfo (
    local_id TEXT PRIMARY KEY,
    id INTEGER,
    tenant_id INTEGER,
    duka_id INTEGER,
    plan_id INTEGER,
    plan_name TEXT,
    amount REAL,
    start_date TEXT,
    end_date TEXT,
    status TEXT,
    payment_method TEXT,
    transaction_id TEXT,
    created_at TEXT,
    updated_at TEXT,
    is_synced INTEGER DEFAULT 1
  )
''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_server_sync ON products(server_id, sync_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_duka_id ON products(duka_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocks_product_id ON stocks(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_items_product_id ON product_items(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_items_qr_code ON product_items(qr_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_sync_status ON sales(sync_status)',
    );

    // 11. Sale Items (Added in v4)
    await db.execute('''CREATE TABLE sale_items (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER UNIQUE,
      sale_local_id INTEGER,
      product_local_id INTEGER,
      product_item_local_id INTEGER,
      quantity INTEGER,
      unit_price REAL,
      discount_amount REAL,
      subtotal REAL,
      sync_status INTEGER DEFAULT $statusSynced
    )''');

    // 12. Cart Drafts
    await db.execute('''CREATE TABLE cart_drafts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_data TEXT,
      items_data TEXT,
      total_amount REAL,
      note TEXT,
      created_at TEXT
    )''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop all tables and recreate
      await db.execute('DROP TABLE IF EXISTS user_data');
      await db.execute('DROP TABLE IF EXISTS officer');
      await db.execute('DROP TABLE IF EXISTS dukas');
      await db.execute('DROP TABLE IF EXISTS products');
      await db.execute('DROP TABLE IF EXISTS stocks');
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS categories');
      await db.execute('DROP TABLE IF EXISTS product_items');
      await db.execute('DROP TABLE IF EXISTS customers');
      await db.execute('DROP TABLE IF EXISTS tenant_account');
      await db.execute('DROP TABLE IF EXISTS permissions');
      await _onCreate(db, newVersion);
    }
    if (oldVersion < 4) {
      await db.execute('''CREATE TABLE sale_items (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_local_id INTEGER,
        product_local_id INTEGER,
        quantity INTEGER,
        unit_price REAL,
        subtotal REAL
      )''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN server_id INTEGER UNIQUE',
        );
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN sync_status INTEGER DEFAULT $statusSynced',
        );
      } catch (e) {
        debugPrint('Error upgrading sale_items to v5: $e');
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN discount_amount REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE sale_items ADD COLUMN product_item_local_id INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading sale_items to v6: $e');
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN invoice_number TEXT');
      } catch (e) {
        debugPrint('Error adding invoice_number to sales table: $e');
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''CREATE TABLE cart_drafts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_data TEXT,
          items_data TEXT,
          total_amount REAL,
          note TEXT,
          created_at TEXT
        )''');
      } catch (e) {
        debugPrint('Error upgrading to v8: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute('''CREATE TABLE stock_movements (
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER UNIQUE,
          product_id INTEGER,
          duka_id INTEGER,
          quantity INTEGER,
          type TEXT,
          reason TEXT,
          created_at TEXT,
          updated_at TEXT,
          sync_status INTEGER DEFAULT $statusSynced
        )''');
      } catch (e) {
        debugPrint('Error upgrading to v9: $e');
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('''CREATE TABLE loan_payments (
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER UNIQUE,
          sale_server_id INTEGER,
          amount REAL,
          payment_date TEXT,
          notes TEXT,
          user_id INTEGER,
          created_at TEXT,
          updated_at TEXT,
          sync_status INTEGER DEFAULT $statusSynced
        )''');
      } catch (e) {
        debugPrint('Error upgrading to v10: $e');
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE tenantsinfo ADD COLUMN user_id INTEGER');
      } catch (e) {
        debugPrint('Error upgrading tenantsinfo to v11: $e');
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE dukasinfo ADD COLUMN manager_name TEXT');
        await db.execute('ALTER TABLE dukasinfo ADD COLUMN latitude REAL');
        await db.execute('ALTER TABLE dukasinfo ADD COLUMN longitude REAL');
      } catch (e) {
        debugPrint('Error upgrading dukasinfo to v12: $e');
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
          'ALTER TABLE product_categoriesinfo ADD COLUMN parent_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE product_categoriesinfo ADD COLUMN description TEXT',
        );
        await db.execute(
          'ALTER TABLE product_categoriesinfo ADD COLUMN created_by INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading product_categoriesinfo to v13: $e');
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE productsinfo ADD COLUMN duka_id INTEGER');
        await db.execute(
          'ALTER TABLE productsinfo ADD COLUMN description TEXT',
        );
        await db.execute('ALTER TABLE productsinfo ADD COLUMN unit TEXT');
        await db.execute('ALTER TABLE productsinfo ADD COLUMN image TEXT');
      } catch (e) {
        debugPrint('Error upgrading productsinfo to v14: $e');
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE productsinfo ADD COLUMN deleted_at TEXT');
        await db.execute('ALTER TABLE productsinfo ADD COLUMN image_url TEXT');
      } catch (e) {
        debugPrint('Error upgrading productsinfo to v15: $e');
      }
    }
    if (oldVersion < 16) {
      try {
        await db.execute(
          'ALTER TABLE stocksinfo ADD COLUMN last_updated_by INTEGER',
        );
        await db.execute('ALTER TABLE stocksinfo ADD COLUMN batch_number TEXT');
        await db.execute('ALTER TABLE stocksinfo ADD COLUMN expiry_date TEXT');
        await db.execute('ALTER TABLE stocksinfo ADD COLUMN notes TEXT');
        await db.execute('ALTER TABLE stocksinfo ADD COLUMN deleted_at TEXT');
      } catch (e) {
        debugPrint('Error upgrading stocksinfo to v16: $e');
      }
    }
    if (oldVersion < 17) {
      try {
        await db.execute(
          'ALTER TABLE customersinfo ADD COLUMN duka_id INTEGER',
        );
        await db.execute('ALTER TABLE customersinfo ADD COLUMN email TEXT');
        await db.execute('ALTER TABLE customersinfo ADD COLUMN address TEXT');
        await db.execute('ALTER TABLE customersinfo ADD COLUMN status TEXT');
        await db.execute(
          'ALTER TABLE customersinfo ADD COLUMN created_by INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading customersinfo to v17: $e');
      }
    }
    if (oldVersion < 18) {
      try {
        await db.execute(
          'ALTER TABLE salesinfo ADD COLUMN discount_amount REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE salesinfo ADD COLUMN profit_loss REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE salesinfo ADD COLUMN total_payments REAL DEFAULT 0',
        );
        await db.execute('ALTER TABLE salesinfo ADD COLUMN due_date TEXT');
        await db.execute(
          'ALTER TABLE salesinfo ADD COLUMN discount_reason TEXT',
        );
        await db.execute(
          'ALTER TABLE salesinfo ADD COLUMN invoice_number TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading salesinfo to v18: $e');
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute(
          'ALTER TABLE sale_itemsinfo ADD COLUMN sale_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE sale_itemsinfo ADD COLUMN discount_amount REAL',
        );
        await db.execute(
          'ALTER TABLE sale_itemsinfo ADD COLUMN product_item_id INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading sale_itemsinfo to v19: $e');
      }
    }
    if (oldVersion < 20) {
      try {
        await db.execute(
          'ALTER TABLE loan_paymentsinfo ADD COLUMN sale_id INTEGER',
        );
        await db.execute('ALTER TABLE loan_paymentsinfo ADD COLUMN notes TEXT');
        await db.execute(
          'ALTER TABLE loan_paymentsinfo ADD COLUMN user_id INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading loan_paymentsinfo to v20: $e');
      }
    }
    if (oldVersion < 21) {
      try {
        await db.execute(
          'ALTER TABLE transactionsinfo ADD COLUMN user_id INTEGER',
        );
        await db.execute('ALTER TABLE transactionsinfo ADD COLUMN status TEXT');
        await db.execute(
          'ALTER TABLE transactionsinfo ADD COLUMN payment_method TEXT',
        );
        await db.execute(
          'ALTER TABLE transactionsinfo ADD COLUMN reference_id TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading transactionsinfo to v21: $e');
      }
    }
    if (oldVersion < 22) {
      try {
        await db.execute(
          'ALTER TABLE transactionsinfo ADD COLUMN deleted_at TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading transactionsinfo to v22: $e');
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN user_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN product_item_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN quantity_remaining INTEGER',
        );
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN previous_quantity INTEGER',
        );
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN new_quantity INTEGER',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v23: $e');
      }
    }
    if (oldVersion < 24) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN unit_cost REAL',
        );
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN total_cost REAL',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v24: $e');
      }
    }
    if (oldVersion < 25) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN unit_price REAL',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v25: $e');
      }
    }
    if (oldVersion < 26) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN total_value REAL',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v26: $e');
      }
    }
    if (oldVersion < 27) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN batch_number TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v27: $e');
      }
    }
    if (oldVersion < 28) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN expiry_date TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v28: $e');
      }
    }
    if (oldVersion < 29) {
      try {
        await db.execute(
          'ALTER TABLE stock_movementsinfo ADD COLUMN notes TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading stock_movementsinfo to v29: $e');
      }
    }
    if (oldVersion < 30) {
      // Version 30 mainly implements the auto-cleanup logic in _cleanDataForSqlite
      // which handles any missing columns by pruning the sync data.
    }
    if (oldVersion < 31) {
      try {
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN duka_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN plan_id INTEGER',
        );
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN amount REAL',
        );
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN start_date TEXT',
        );
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN payment_method TEXT',
        );
        await db.execute(
          'ALTER TABLE duka_subscriptionsinfo ADD COLUMN transaction_id TEXT',
        );
      } catch (e) {
        debugPrint('Error upgrading duka_subscriptionsinfo to v31: $e');
      }
    }
    if (oldVersion < 32) {
      try {
        final List<Map<String, dynamic>> tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='duka_subscriptionsinfo'",
        );

        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE duka_subscriptionsinfo (
              local_id TEXT PRIMARY KEY,
              id INTEGER,
              tenant_id INTEGER,
              duka_id INTEGER,
              plan_id INTEGER,
              plan_name TEXT,
              amount REAL,
              start_date TEXT,
              end_date TEXT,
              status TEXT,
              payment_method TEXT,
              transaction_id TEXT,
              created_at TEXT,
              updated_at TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
        } else {
          // Robust check for missing columns
          final columns = await db.rawQuery(
            "PRAGMA table_info(duka_subscriptionsinfo)",
          );
          final columnNames = columns.map((c) => c['name'] as String).toSet();

          final requiredColumns = {
            'duka_id': 'INTEGER',
            'plan_id': 'INTEGER',
            'amount': 'REAL',
            'start_date': 'TEXT',
            'end_date': 'TEXT',
            'status': 'TEXT',
            'payment_method': 'TEXT',
            'transaction_id': 'TEXT',
          };

          for (var entry in requiredColumns.entries) {
            if (!columnNames.contains(entry.key)) {
              await db.execute(
                'ALTER TABLE duka_subscriptionsinfo ADD COLUMN ${entry.key} ${entry.value}',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error upgrading duka_subscriptionsinfo to v32: $e');
      }
    }

    if (oldVersion < 33) {
      try {
        await db.execute('DROP TABLE IF EXISTS stock_movements');
        await db.execute('''CREATE TABLE stock_movements (
          local_id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER UNIQUE,
          stock_id INTEGER,
          product_id INTEGER,
          duka_id INTEGER,
          user_id INTEGER,
          quantity INTEGER,
          type TEXT,
          reason TEXT,
          quantity_change INTEGER,
          quantity_remaining INTEGER,
          previous_quantity INTEGER,
          new_quantity INTEGER,
          unit_cost REAL,
          unit_price REAL,
          created_at TEXT,
          updated_at TEXT,
          sync_status INTEGER DEFAULT $statusSynced
        )''');
      } catch (e) {
        debugPrint('Error upgrading stock_movements to v33: $e');
      }
    }

    if (oldVersion < 34) {
      try {
        // Robust check for missing stock_id column
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          "PRAGMA table_info(stock_movements)",
        );
        final columnNames = columns.map((c) => c['name'] as String).toSet();

        if (!columnNames.contains('stock_id')) {
          await db.execute(
            'ALTER TABLE stock_movements ADD COLUMN stock_id INTEGER',
          );
        }
      } catch (e) {
        debugPrint('Error upgrading stock_movements to v34: $e');
      }
    }

    if (oldVersion < 36) {
      try {
        final List<Map<String, dynamic>> columns = await db.rawQuery(
          "PRAGMA table_info(stock_movements)",
        );
        final columnNames = columns.map((c) => c['name'] as String).toSet();

        final missingCols = {
          'user_id': 'INTEGER',
          'quantity_change': 'INTEGER',
          'quantity_remaining': 'INTEGER',
          'previous_quantity': 'INTEGER',
          'new_quantity': 'INTEGER',
          'unit_cost': 'REAL',
          'unit_price': 'REAL',
        };

        for (var entry in missingCols.entries) {
          if (!columnNames.contains(entry.key)) {
            await db.execute(
              'ALTER TABLE stock_movements ADD COLUMN ${entry.key} ${entry.value}',
            );
          }
        }
      } catch (e) {
        debugPrint('Error upgrading stock_movements to v36: $e');
      }
    }
  }

  Future<void> syncAllData(
    Map<String, dynamic> apiResponse, {
    Function(String label, int current, int total)? onProgress,
  }) async {
    final db = await database;
    final data = apiResponse['data'];
    if (data == null) return;

    await db.transaction((txn) async {
      final batch = txn.batch();

      // Ramani ya JSON Keys kwenda SQLite Tables
      final syncMap = {
        'tenants': 'tenantsinfo',
        'tenant_accounts': 'tenant_accountsinfo',
        'dukas': 'dukasinfo',
        'tenant_officers': 'tenant_officersinfo',
        'categories': 'product_categoriesinfo',
        'products': 'productsinfo',
        'stocks': 'stocksinfo',
        'product_items': 'product_itemsinfo',
        'customers': 'customersinfo',
        'sales': 'salesinfo',
        'sale_items': 'sale_itemsinfo',
        'loan_payments': 'loan_paymentsinfo',
        'transactions': 'transactionsinfo',
        'stock_movements': 'stock_movementsinfo',
        'messages': 'messagesinfo',
        'subscriptions': 'duka_subscriptionsinfo',
      };

      int index = 0;
      int totalSteps = syncMap.length;

      for (var entry in syncMap.entries) {
        index++;

        // Notify UI about progress
        if (onProgress != null) {
          onProgress(entry.key, index, totalSteps);
        }

        if (data[entry.key] != null && data[entry.key] is List) {
          for (var item in data[entry.key]) {
            Map<String, dynamic> record = Map<String, dynamic>.from(item);
            if (record.containsKey('id') && record['id'] != null) {
              record['local_id'] = 'server_${record['id']}';
            } else {
              record['local_id'] = _uuid.v4();
            }
            record['is_synced'] = 1;
            _cleanDataForSqlite(record, tableName: entry.value);

            batch.insert(
              entry.value,
              record,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      await batch.commit(noResult: true);
    });
  }

  void _cleanDataForSqlite(Map<String, dynamic> record, {String? tableName}) {
    record.forEach((key, value) {
      if (value is bool) {
        record[key] = value ? 1 : 0;
      }
    });
    // Ondoa fields ambazo ni List au Map (Nested JSON)
    record.removeWhere((key, value) => value is List || value is Map);

    // Prune unknown fields if we have a definition for the table
    if (tableName != null) {
      record.removeWhere(
        (key, value) => !_isValidField(key, record, tableName),
      );
    }

    // Special handling for legacy names if needed
    if (record.containsKey('id') && !record.containsKey('server_id')) {
      // This is handled in syncAllData but let's be safe
    }
  }

  Future<void> saveDashboardData(Map<String, dynamic> json) async {
    await _saveDashboardDataBackground(json);
  }

  // --- SAVE DASHBOARD DATA (Processing the API JSON) ---
  Future<void> _saveDashboardDataBackground(Map<String, dynamic> json) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        print('🔄 [BG] Starting dashboard background sync...');

        if (json['officer'] != null) {
          await _smartUpsert(txn, 'officer', json['officer'], 'server_id');
        }
        if (json.containsKey('dukas') && json['dukas'] is List) {
          await _bulkSmartUpsert(
            txn,
            'dukas',
            json['dukas'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'dukas',
            json['dukas'] as List<dynamic>,
          );
        }
        if (json.containsKey('products') && json['products'] is List) {
          final productsList = json['products'] as List<dynamic>;

          await _bulkSmartUpsert(txn, 'products', productsList, 'server_id');

          // --- PRUNING LOGIC ---
          // Determine which products are on the server (Incoming)
          final incomingServerIds =
              productsList
                  .map((p) => (p as Map<String, dynamic>)['id'])
                  .where((id) => id != null)
                  .map((id) => int.parse(id.toString()))
                  .toSet();

          // Determine which products we have locally that are synced
          final localSynced = await txn.query(
            'products',
            columns: ['server_id'],
            where: 'server_id IS NOT NULL',
          );

          final localServerIds =
              localSynced.map((row) => row['server_id'] as int).toSet();

          // Find IDs that exist locally but are missing from the server response
          final idsToRemove =
              localServerIds.difference(incomingServerIds).toList();

          if (idsToRemove.isNotEmpty) {
            print('🧹 [BG] Pruning ${idsToRemove.length} obsolete products...');
            await _processDeletedProducts(txn, idsToRemove);
          }
        }
        if (json.containsKey('deleted_product_ids') &&
            json['deleted_product_ids'] is List) {
          await _processDeletedProducts(
            txn,
            json['deleted_product_ids'] as List<dynamic>,
          );
        }
        if (json.containsKey('stocks') && json['stocks'] is List) {
          await _bulkSmartUpsert(
            txn,
            'stocks',
            json['stocks'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'stocks',
            json['stocks'] as List<dynamic>,
          );
        }

        
        if (json.containsKey('sales') && json['sales'] is List) {
          // Use individual _smartUpsert for sales to handle schema differences
          for (var sale in json['sales'] as List) {
            await _smartUpsert(
              txn,
              'sales',
              sale as Map<String, dynamic>,
              'server_id',
            );
          }
          await _pruneLocalRecords(
            txn,
            'sales',
            json['sales'] as List<dynamic>,
          );
        }
        if (json.containsKey('categories') && json['categories'] is List) {
          await _bulkSmartUpsert(
            txn,
            'categories',
            json['categories'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'categories',
            json['categories'] as List<dynamic>,
          );
        }
        if (json.containsKey('productItems') && json['productItems'] is List) {
          await _bulkSmartUpsert(
            txn,
            'product_items',
            json['productItems'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'product_items',
            json['productItems'] as List<dynamic>,
          );
        }
        if (json.containsKey('customers') && json['customers'] is List) {
          await _bulkSmartUpsert(
            txn,
            'customers',
            json['customers'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'customers',
            json['customers'] as List<dynamic>,
          );
        }
        if (json.containsKey('saleItems') && json['saleItems'] is List) {
          await _saveSaleItems(txn, json['saleItems'] as List<dynamic>);
        }
        if (json['tenantAccount'] != null) {
          await _smartUpsert(
            txn,
            'tenant_account',
            json['tenantAccount'],
            'server_id',
          );
        }
        if (json.containsKey('loanPayments') && json['loanPayments'] is Map) {
          await _saveLoanPayments(
            txn,
            json['loanPayments'] as Map<String, dynamic>,
          );
        }
        if (json.containsKey('stockMovements') &&
            json['stockMovements'] is List) {
          await _bulkSmartUpsert(
            txn,
            'stock_movements',
            json['stockMovements'] as List<dynamic>,
            'server_id',
          );
          await _pruneLocalRecords(
            txn,
            'stock_movements',
            json['stockMovements'] as List<dynamic>,
          );
        }

        print('✅ [BG] Dashboard background sync completed');
      });
    } catch (e, stack) {
      print('💥 [BG] Dashboard sync failed: $e\n$stack');
    }
  }

  Future<Map<String, dynamic>?> getProductItemByQr(String qrCode) async {
    final db = await database;

    final result = await db.query(
      'product_items',
      where: 'qr_code = ? AND status != ?',
      whereArgs: [qrCode, 'deleted'],
      limit: 1,
    );

    return result.isNotEmpty ? result.first : null;
  }

  Future<void> deleteLocalSale(int serverId) async {
    final db = await database;

    // 1. Get local_id of the sale to delete associated items
    final saleRes = await db.query(
      'sales',
      columns: ['local_id'],
      where: 'server_id = ?',
      whereArgs: [serverId],
    );

    int? saleLocalId;
    if (saleRes.isNotEmpty) {
      saleLocalId = saleRes.first['local_id'] as int;
    }

    // 2. Delete from sales table
    await db.delete('sales', where: 'server_id = ?', whereArgs: [serverId]);

    // 3. Delete from sale_items
    if (saleLocalId != null) {
      await db.delete(
        'sale_items',
        where: 'sale_local_id = ?',
        whereArgs: [saleLocalId],
      );
    }
  }

  Future<void> _processDeletedProducts(
    Transaction txn,
    List<dynamic> deletedIds,
  ) async {
    final serverIds =
        deletedIds
            .map((id) => int.tryParse(id.toString().trim()))
            .whereType<int>()
            .toList();

    if (serverIds.isEmpty) return;

    // Process in batches to avoid SQLite limit (999 variables)
    const batchSize = 400;
    for (var i = 0; i < serverIds.length; i += batchSize) {
      final end =
          (i + batchSize < serverIds.length) ? i + batchSize : serverIds.length;
      final batchServerIds = serverIds.sublist(i, end);

      if (batchServerIds.isEmpty) continue;

      final serverPlaceholders = List.filled(
        batchServerIds.length,
        '?',
      ).join(',');

      // 1. Find local_ids for these server_ids
      final List<Map<String, Object?>> results = await txn.query(
        'products',
        columns: ['local_id'],
        where: 'server_id IN ($serverPlaceholders)',
        whereArgs: batchServerIds,
      );

      final localIds = results.map((r) => r['local_id'] as int).toList();

      // 2. Delete related data (Stocks & Items)
      // Construct WHERE clause for stocks (server_id OR local_id)
      String stockWhere = 'product_id IN ($serverPlaceholders)';
      List<Object?> stockArgs = [...batchServerIds];

      if (localIds.isNotEmpty) {
        final localPlaceholders = List.filled(localIds.length, '?').join(',');

        stockWhere += ' OR product_id IN ($localPlaceholders)';
        stockArgs.addAll(localIds);

        // Delete product items (referencing local_id)
        await txn.delete(
          'product_items',
          where: 'product_id IN ($localPlaceholders)',
          whereArgs: localIds,
        );
      }

      await txn.delete('stocks', where: stockWhere, whereArgs: stockArgs);

      // 3. Delete products
      // Delete by local_id (if found) OR server_id (fallback/completeness)
      String productWhere = 'server_id IN ($serverPlaceholders)';
      List<Object?> productArgs = [...batchServerIds];

      if (localIds.isNotEmpty) {
        final localPlaceholders = List.filled(localIds.length, '?').join(',');
        productWhere += ' OR local_id IN ($localPlaceholders)';
        productArgs.addAll(localIds);
      }

      await txn.delete('products', where: productWhere, whereArgs: productArgs);

      print(
        '🗑️ Soft Delete: Processed batch of ${batchServerIds.length} products',
      );
    }
  }

  Future<void> _saveSaleItems(Transaction txn, List<dynamic> items) async {
    for (var item in items) {
      final map = item as Map<String, dynamic>;
      if (map['sale_id'] == null || map['product_id'] == null) continue;

      // Resolve Sale Local ID
      final saleRes = await txn.query(
        'sales',
        columns: ['local_id'],
        where: 'server_id = ?',
        whereArgs: [map['sale_id']],
      );
      if (saleRes.isEmpty) continue;
      final saleLocalId = saleRes.first['local_id'];

      // Resolve Product Local ID
      final prodRes = await txn.query(
        'products',
        columns: ['local_id'],
        where: 'server_id = ?',
        whereArgs: [map['product_id']],
      );
      if (prodRes.isEmpty) continue;
      final prodLocalId = prodRes.first['local_id'];

      int? productItemLocalId;
      if (map['product_item_id'] != null) {
        final piRes = await txn.query(
          'product_items',
          columns: ['local_id'],
          where: 'server_id = ?',
          whereArgs: [map['product_item_id']],
        );
        if (piRes.isNotEmpty) {
          productItemLocalId = piRes.first['local_id'] as int;
        }
      }

      final record = {
        'server_id': map['id'],
        'sale_local_id': saleLocalId,
        'product_local_id': prodLocalId,
        'product_item_local_id': productItemLocalId,
        'quantity': map['quantity'],
        'unit_price': map['unit_price'],
        'discount_amount': map['discount_amount'] ?? 0.0,
        'subtotal': map['total'],
        'sync_status': statusSynced,
      };

      // Check for existing record with the same server_id
      final existingByServerId = await txn.query(
        'sale_items',
        where: 'server_id = ?',
        whereArgs: [map['id']],
      );

      if (existingByServerId.isNotEmpty) {
        await txn.update(
          'sale_items',
          record,
          where: 'server_id = ?',
          whereArgs: [map['id']],
        );
      } else {
        // Try to find a local record that hasn't been synced yet (matched by sale, product, and optionally item)
        String localWhere =
            'sale_local_id = ? AND product_local_id = ? AND server_id IS NULL';
        List<dynamic> localArgs = [saleLocalId, prodLocalId];

        if (productItemLocalId != null) {
          localWhere += ' AND product_item_local_id = ?';
          localArgs.add(productItemLocalId);
        } else {
          localWhere +=
              ' AND (product_item_local_id IS NULL OR product_item_local_id = 0)';
        }

        final localExisting = await txn.query(
          'sale_items',
          where: localWhere,
          whereArgs: localArgs,
          limit: 1,
        );

        if (localExisting.isNotEmpty) {
          await txn.update(
            'sale_items',
            record,
            where: 'local_id = ?',
            whereArgs: [localExisting.first['local_id']],
          );
        } else {
          await txn.insert(
            'sale_items',
            record,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }

  Future<void> _saveLoanPayments(
    Transaction txn,
    Map<String, dynamic> loanPaymentsMap,
  ) async {
    // loanPaymentsMap structure: {49: [], 50: [], 52: [], 53: [], ...}
    // Where keys are sale_server_id and values are arrays of payment records
    for (var entry in loanPaymentsMap.entries) {
      final saleServerId = int.tryParse(entry.key.toString());
      if (saleServerId == null) continue;

      final payments = entry.value as List<dynamic>;
      for (var payment in payments) {
        final paymentMap = payment as Map<String, dynamic>;

        final record = {
          'server_id': paymentMap['id'],
          'sale_server_id': saleServerId,
          'amount': paymentMap['amount'],
          'payment_date': paymentMap['payment_date'],
          'notes': paymentMap['notes'],
          'user_id': paymentMap['user_id'],
          'created_at':
              paymentMap['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at':
              paymentMap['updated_at'] ?? DateTime.now().toIso8601String(),
          'sync_status': statusSynced,
        };

        // Use smart upsert logic
        final existing = await txn.query(
          'loan_payments',
          where: 'server_id = ? AND sync_status = ?',
          whereArgs: [record['server_id'], statusSynced],
        );

        if (existing.isNotEmpty) {
          await txn.update(
            'loan_payments',
            record,
            where: 'server_id = ?',
            whereArgs: [record['server_id']],
          );
        } else {
          await txn.insert(
            'loan_payments',
            record,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    }
  }

  Future<void> _smartUpsert(
    dynamic txn,
    String table,
    Map<String, dynamic> data,
    String idField,
  ) async {
    Map<String, dynamic> record;
    if (table == 'sales') {
      record = _prepareSalesRecordForUpsert(data);
    } else {
      record = _prepareRecordForUpsert(data, table);
    }

    if (record['server_id'] == null) return;

    final existing = await txn.query(
      table,
      where: '$idField = ?',
      whereArgs: [record['server_id']],
    );

    if (existing.isNotEmpty) {
      // Preserve is_loan = 1 if it exists in the current record
      if (table == 'sales' && existing.first['is_loan'] == 1) {
        record['is_loan'] = 1;
      }
      await txn.update(
        table,
        record,
        where: '$idField = ?',
        whereArgs: [record['server_id']],
      );
    } else {
      await txn.insert(
        table,
        record,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _bulkSmartUpsert(
    dynamic txn,
    String table,
    List<dynamic> items,
    String idField,
  ) async {
    if (items.isEmpty) return;
    for (var item in items) {
      await _smartUpsert(txn, table, item as Map<String, dynamic>, idField);
    }
  }

  // --- GENERIC PRUNING HELPER ---
  Future<void> _pruneLocalRecords(
    Transaction txn,
    String table,
    List<dynamic> incomingList,
  ) async {
    try {
      if (incomingList.isEmpty) return;

      // 1. Get Incoming Server IDs
      final incomingIds =
          incomingList
              .map((item) => (item as Map<String, dynamic>)['id'])
              .where((id) => id != null)
              .map((id) => int.parse(id.toString()))
              .toSet();

      // 2. Get Local Synced Server IDs
      final localSynced = await txn.query(
        table,
        columns: ['server_id'],
        where: 'server_id IS NOT NULL',
      );

      final localIds =
          localSynced.map((row) => row['server_id'] as int).toSet();

      // 3. Find Orphans (Local but not in Incoming)
      final idsToRemove = localIds.difference(incomingIds).toList();

      if (idsToRemove.isNotEmpty) {
        print(
          '🧹 [BG] Pruning $table: removing ${idsToRemove.length} obsolete records...',
        );

        // Delete in batches
        const batchSize = 500;
        for (var i = 0; i < idsToRemove.length; i += batchSize) {
          final end =
              (i + batchSize < idsToRemove.length)
                  ? i + batchSize
                  : idsToRemove.length;
          final batch = idsToRemove.sublist(i, end);

          final placeholders = List.filled(batch.length, '?').join(',');
          await txn.delete(
            table,
            where: 'server_id IN ($placeholders)',
            whereArgs: batch,
          );
        }
      }
    } catch (e) {
      print('⚠️ Error pruning table $table: $e');
    }
  }

  Map<String, dynamic> _prepareRecordForUpsert(
    Map<String, dynamic> data, [
    String? tableName,
  ]) {
    final record = Map<String, dynamic>.from(data);
    if (record.containsKey('id')) {
      record['server_id'] = record['id'];
      record.remove('id');
    }
    record['sync_status'] = statusSynced;
    _convertBooleansToInts(record);

    // Remove fields that don't exist in the local schema to prevent errors
    record.removeWhere((key, value) => !_isValidField(key, record, tableName));

    record.removeWhere((key, value) => value == null);
    final now = DateTime.now().toIso8601String();
    record['updated_at'] = now;
    if (!record.containsKey('created_at')) record['created_at'] = now;
    return record;
  }

  // Special handling for sales data to prevent schema conflicts
  Map<String, dynamic> _prepareSalesRecordForUpsert(Map<String, dynamic> data) {
    final record = Map<String, dynamic>.from(data);

    // Rename API 'id' to 'server_id'
    if (record.containsKey('id')) {
      record['server_id'] = record['id'];
      record.remove('id');
    }

    // Handle nested customer object from API
    if (record['customer'] != null && record['customer'] is Map) {
      final customer = record['customer'] as Map<String, dynamic>;
      // Extract customer_id if available
      if (customer['id'] != null) {
        record['customer_id'] = customer['id'];
      }
      // Remove the nested customer object
      record.remove('customer');
    }

    // Remove API-specific fields that don't exist in local schema
    record.removeWhere(
      (key, value) => [
        'duka_name',
        'item_count',
        'customer',
        'items',
        'duka',
        'loan_payments',
      ].contains(key),
    );

    record['sync_status'] = statusSynced;
    _convertBooleansToInts(record);

    // Remove fields that don't exist in the sales table schema to prevent update errors
    record.removeWhere((key, value) => !_isValidField(key, record, 'sales'));

    record.removeWhere((key, value) => value == null);

    final now = DateTime.now().toIso8601String();
    record['updated_at'] = now;
    if (!record.containsKey('created_at')) record['created_at'] = now;

    return record;
  }

  bool _isValidField(
    String fieldName,
    Map<String, dynamic> record, [
    String? tableName,
  ]) {
    // Define valid fields for each table to prevent schema mismatches
    final validFields = {
      'sales': {
        'server_id',
        'local_id',
        'tenant_id',
        'duka_id',
        'customer_id',
        'total_amount',
        'discount_amount',
        'profit_loss',
        'is_loan',
        'due_date',
        'payment_status',
        'total_payments',
        'remaining_balance',
        'discount_reason',
        'created_at',
        'updated_at',
        'sync_status',
        'invoice_number',
      },
      'customers': {
        'server_id',
        'local_id',
        'tenant_id',
        'duka_id',
        'name',
        'email',
        'phone',
        'address',
        'status',
        'created_by',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'products': {
        'server_id',
        'local_id',
        'tenant_id',
        'duka_id',
        'category_id',
        'sku',
        'name',
        'description',
        'unit',
        'base_price',
        'selling_price',
        'is_active',
        'image',
        'image_url',
        'barcode',
        'created_at',
        'updated_at',
        'deleted_at',
        'sync_status',
      },
      'dukas': {
        'server_id',
        'local_id',
        'tenant_id',
        'name',
        'location',
        'manager_name',
        'latitude',
        'longitude',
        'status',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'categories': {
        'server_id',
        'local_id',
        'tenant_id',
        'name',
        'description',
        'parent_id',
        'status',
        'created_by',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'stocks': {
        'server_id',
        'local_id',
        'product_id',
        'duka_id',
        'quantity',
        'last_updated_by',
        'created_at',
        'updated_at',
        'batch_number',
        'expiry_date',
        'notes',
        'deleted_at',
        'sync_status',
      },
      'sale_items': {
        'server_id',
        'local_id',
        'sale_local_id',
        'product_local_id',
        'product_item_local_id',
        'quantity',
        'unit_price',
        'discount_amount',
        'subtotal',
        'sync_status',
      },
      'product_items': {
        'server_id',
        'local_id',
        'product_id',
        'qr_code',
        'status',
        'sold_at',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'tenant_account': {
        'server_id',
        'local_id',
        'tenant_id',
        'company_name',
        'logo',
        'phone',
        'email',
        'address',
        'currency',
        'timezone',
        'website',
        'description',
        'logo_url',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'officer': {
        'server_id',
        'local_id',
        'name',
        'email',
        'profile_picture',
        'profile_picture_url',
        'role',
        'status',
        'created_at',
        'updated_at',
        'email_verified_at',
        'tenant_id',
        'sync_status',
      },
      'permissions': {
        'server_id',
        'local_id',
        'officer_id',
        'permission',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'loan_payments': {
        'server_id',
        'local_id',
        'sale_server_id',
        'amount',
        'payment_date',
        'notes',
        'user_id',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'stock_movements': {
        'server_id',
        'local_id',
        'stock_id',
        'user_id',
        'type',
        'quantity_change',
        'quantity_remaining',
        'previous_quantity',
        'new_quantity',
        'unit_cost',
        'unit_price',
        'reason',
        'created_at',
        'updated_at',
        'sync_status',
      },
      'stock_movementsinfo': {
        'server_id',
        'local_id',
        'stock_id',
        'user_id',
        'product_item_id',
        'type',
        'quantity_change',
        'quantity_remaining',
        'previous_quantity',
        'new_quantity',
        'unit_cost',
        'total_cost',
        'unit_price',
        'total_value',
        'batch_number',
        'expiry_date',
        'notes',
        'reason',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'tenantsinfo': {
        'local_id',
        'id',
        'name',
        'slug',
        'email',
        'phone',
        'address',
        'user_id',
        'status',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'tenant_accountsinfo': {
        'local_id',
        'id',
        'tenant_id',
        'company_name',
        'logo',
        'currency',
        'timezone',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'dukasinfo': {
        'local_id',
        'id',
        'tenant_id',
        'name',
        'location',
        'manager_name',
        'latitude',
        'longitude',
        'status',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'tenant_officersinfo': {
        'local_id',
        'id',
        'tenant_id',
        'duka_id',
        'officer_id',
        'role',
        'status',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'product_categoriesinfo': {
        'local_id',
        'id',
        'tenant_id',
        'name',
        'description',
        'parent_id',
        'status',
        'created_by',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'productsinfo': {
        'local_id',
        'id',
        'tenant_id',
        'duka_id',
        'category_id',
        'sku',
        'name',
        'description',
        'unit',
        'base_price',
        'selling_price',
        'is_active',
        'image',
        'image_url',
        'barcode',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_synced',
      },
      'stocksinfo': {
        'local_id',
        'id',
        'duka_id',
        'product_id',
        'quantity',
        'last_updated_by',
        'batch_number',
        'expiry_date',
        'notes',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_synced',
      },
      'product_itemsinfo': {
        'local_id',
        'id',
        'product_id',
        'qr_code',
        'status',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'customersinfo': {
        'local_id',
        'id',
        'tenant_id',
        'duka_id',
        'name',
        'email',
        'phone',
        'address',
        'status',
        'created_by',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'salesinfo': {
        'local_id',
        'id',
        'tenant_id',
        'duka_id',
        'customer_id',
        'total_amount',
        'discount_amount',
        'profit_loss',
        'is_loan',
        'due_date',
        'payment_status',
        'total_payments',
        'remaining_balance',
        'discount_reason',
        'invoice_number',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'sale_itemsinfo': {
        'local_id',
        'id',
        'sale_id',
        'local_sale_id',
        'product_id',
        'product_item_id',
        'quantity',
        'unit_price',
        'discount_amount',
        'total',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'loan_paymentsinfo': {
        'local_id',
        'id',
        'sale_id',
        'local_sale_id',
        'amount',
        'payment_date',
        'notes',
        'user_id',
        'created_at',
        'updated_at',
        'is_synced',
      },
      'transactionsinfo': {
        'local_id',
        'id',
        'duka_id',
        'user_id',
        'type',
        'amount',
        'category',
        'status',
        'payment_method',
        'reference_id',
        'description',
        'transaction_date',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_synced',
      },
      'duka_subscriptionsinfo': {
        'local_id',
        'id',
        'tenant_id',
        'duka_id',
        'plan_id',
        'plan_name',
        'amount',
        'start_date',
        'end_date',
        'status',
        'payment_method',
        'transaction_id',
        'created_at',
        'updated_at',
        'is_synced',
      },
    };

    if (tableName != null && validFields.containsKey(tableName)) {
      return validFields[tableName]!.contains(fieldName);
    }

    if (record.containsKey('total_amount') ||
        record.containsKey('customer_id')) {
      return validFields['sales']!.contains(fieldName);
    }

    // Default: allow the field (safer approach for unknown tables)
    return true;
  }

  void _convertBooleansToInts(Map<String, dynamic> record) {
    final fields = ['is_active', 'is_loan', 'track_items', 'is_verified'];
    for (var field in fields) {
      if (record.containsKey(field)) {
        final value = record[field];
        // Robust conversion: handle boolean, int, and string "1"/"true"
        if (value == true || value == 1 || value == '1' || value == 'true') {
          record[field] = 1;
        } else {
          record[field] = 0;
        }
      }
    }
  }

  Future<int> createPendingProduct(Map<String, dynamic> productData) async {
    final db = await database;
    final record = Map<String, dynamic>.from(productData);
    record['server_id'] = null;
    record['sync_status'] = statusPending;
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();
    record['is_active'] = record['is_active'] == true ? 1 : 1;
    return await db.insert('products', record);
  }

  Future<List<Map<String, dynamic>>> getPendingProducts() async {
    final db = await database;
    return await db.query(
      'products',
      where: 'sync_status = ?',
      whereArgs: [statusPending],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateProductServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'products',
      {
        'server_id': serverId,
        'sync_status': statusSynced,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<int> getPendingProductsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusPending],
    );
    return result.first['count'] as int;
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final db = await database;
    final maps = await db.query('user_data');
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['data'] as String) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> deleteUserData() async {
    final db = await database;
    await db.delete('user_data');
  }

  Future<void> logout() async {
    final db = await database;
    await db.delete('user_data');
  }

  // This logic maps the API 'id' to the database 'server_id'
  Future<void> _mapAndInsert(
    dynamic dbOrTxn,
    String table,
    Map<String, dynamic> data,
  ) async {
    Map<String, dynamic> record = Map.from(data);

    // Core logic: Rename API ID to server_id
    if (record.containsKey('id')) {
      record['server_id'] = record['id'];
      record.remove(
        'id',
      ); // Remove original 'id' so local_id can auto-increment
    }

    record['sync_status'] = statusSynced;

    // Convert booleans for SQLite
    if (record.containsKey('is_active')) {
      final value = record['is_active'];
      record['is_active'] = (value == true || value == 1) ? 1 : 0;
    }
    if (record.containsKey('is_loan')) {
      final value = record['is_loan'];
      record['is_loan'] = (value == true || value == 1) ? 1 : 0;
    }

    await dbOrTxn.insert(
      table,
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _bulkMapAndInsert(
    dynamic dbOrTxn,
    String table,
    List<dynamic>? list,
  ) async {
    if (list == null) return;
    for (var item in list) {
      await _mapAndInsert(dbOrTxn, table, item as Map<String, dynamic>);
    }
  }

  // --- EXAMPLE: Creating a Sale Offline ---
  Future<int> createOfflineSale(Map<String, dynamic> sale) async {
    final db = await database;
    Map<String, dynamic> record = Map.from(sale);

    record['server_id'] = null; // Doesn't have a server ID yet
    record['sync_status'] = statusPending; // Needs to be uploaded

    // Returns the local_id
    return await db.insert('sales', record);
  }

  // --- QUERY EXAMPLES ---

  // Get products for a specific duka using server_id references
  Future<List<Map<String, dynamic>>> getProductsByDuka(int serverDukaId) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'duka_id = ?',
      whereArgs: [serverDukaId],
    );
  }

  // Get all sales that need to be sent to the server
  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'sync_status = ?',
      whereArgs: [statusPending],
    );
  }

  // --- AUTH HELPERS ---
  Future<void> saveUserData(Map<String, dynamic> data) async {
    final db = await database;
    await db.delete('user_data');
    await db.insert('user_data', {'data': jsonEncode(data)});
  }

  Future<void> clearLocalData() async {
    final db = await database;
    await db.delete('sales');
    await db.delete('sale_items');
    await db.delete('loan_payments');
    await db.delete('customers');
    await db.delete('customersinfo');
  }

  // Save categories and permissions separately for officer role
  Future<void> saveCategoriesAndPermissions(
    Map<String, dynamic> response,
  ) async {
    final db = await database;
    final userData = response['data']['user'];
    final officerId = userData['id'];

    await db.transaction((txn) async {
      // Clear existing data for this officer
      await txn.delete(
        'categories',
        where: 'created_by = ?',
        whereArgs: [officerId],
      );
      await txn.delete(
        'permissions',
        where: 'officer_id = ?',
        whereArgs: [officerId],
      );

      // Save categories
      final categories = userData['categories'] as List<dynamic>?;
      if (categories != null) {
        for (var category in categories) {
          final categoryData = Map<String, dynamic>.from(
            category as Map<String, dynamic>,
          );
          categoryData['server_id'] = categoryData['id'];
          categoryData.remove('id');
          categoryData['created_by'] = officerId;
          categoryData['sync_status'] = statusSynced;

          // Remove nested objects that shouldn't be stored in categories table
          categoryData.remove('parent');
          categoryData.remove('tenant');

          await txn.insert(
            'categories',
            categoryData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Save permissions
      final permissions = userData['permissions'] as List<dynamic>?;
      if (permissions != null) {
        for (var permission in permissions) {
          await txn.insert('permissions', {
            'officer_id': officerId,
            'permission': permission.toString(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': statusSynced,
          });
        }
      }
    });
  }

  // Get categories for officer
  Future<List<Map<String, dynamic>>> getCategoriesByOfficer(
    int officerId,
  ) async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'created_by = ?',
      whereArgs: [officerId],
    );
  }

  // Get permissions for officer
  Future<List<Map<String, dynamic>>> getPermissionsByOfficer(
    int officerId,
  ) async {
    final db = await database;
    return await db.query(
      'permissions',
      where: 'officer_id = ?',
      whereArgs: [officerId],
    );
  }

  // Get all permissions as strings for officer
  Future<List<String>> getPermissionNamesByOfficer(int officerId) async {
    final db = await database;
    final maps = await db.query(
      'permissions',
      where: 'officer_id = ?',
      whereArgs: [officerId],
    );
    return maps.map((map) => map['permission'] as String).toList();
  }

  /// Update permissions from API response
  Future<void> updateLocalPermissions(List<dynamic> permissions) async {
    final db = await database;

    // Get current officer to associate permissions
    final officerRes = await db.query('officer', limit: 1);
    if (officerRes.isEmpty) return;
    final officerId = officerRes.first['server_id'] as int;

    await db.transaction((txn) async {
      // Clear existing permissions for this officer
      await txn.delete(
        'permissions',
        where: 'officer_id = ?',
        whereArgs: [officerId],
      );

      for (var p in permissions) {
        final map = p as Map<String, dynamic>;
        if (map['permission'] != null) {
          await txn.insert('permissions', {
            'officer_id': officerId,
            'permission': map['permission'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': statusSynced,
          });
        }
      }
    });
  }

  // Add a product item
  Future<int> addProductItem(int productId, String qrCode) async {
    final db = await database;
    return await db.insert('product_items', {
      'product_id': productId,
      'qr_code': qrCode,
      'status': 'available',
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': statusPending,
    });
  }

  // --- PRODUCT SYNC METHODS ---

  /// Create a product locally with pending sync status

  /// Get sync status summary for products
  Future<Map<String, int>> getProductSyncSummary() async {
    final db = await database;

    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusPending],
    );

    final syncedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE sync_status = ?',
      [statusSynced],
    );

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products',
    );

    return {
      'pending': pendingResult.first['count'] as int,
      'synced': syncedResult.first['count'] as int,
      'total': totalResult.first['count'] as int,
    };
  }

  /// Create stock record for pending product
  Future<int> createPendingStock(Map<String, dynamic> stockData) async {
    final db = await database;

    final record = Map<String, dynamic>.from(stockData);
    record['server_id'] = null;
    record['sync_status'] = statusPending;
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert('stocks', record);
  }

  /// Create stock movement record for audit trail
  Future<int> createStockMovement(Map<String, dynamic> movementData) async {
    final db = await database;

    final record = Map<String, dynamic>.from(movementData);
    record['server_id'] = null;
    record['sync_status'] = statusPending;
    record['type'] = record['type'] ?? 'add';
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert('stock_movements', record);
  }

  /// Get pending stocks for a product
  Future<List<Map<String, dynamic>>> getPendingStocks(
    int productLocalId,
  ) async {
    final db = await database;
    return await db.query(
      'stocks',
      where: 'product_id = ? AND sync_status = ?',
      whereArgs: [productLocalId, statusPending],
    );
  }

  /// Get all pending stock records (not movements)
  Future<List<Map<String, dynamic>>> getAllPendingStocks() async {
    final db = await database;
    return await db.query(
      'stocks',
      where: 'sync_status = ?',
      whereArgs: [statusPending],
      orderBy: 'created_at ASC',
    );
  }

  /// Update stock server ID and sync status
  Future<void> updateStockServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'stocks',
      {
        'server_id': serverId,
        'sync_status': statusSynced,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // --- Category CRUD ---
  Future<int> createCategory(Map<String, dynamic> category) async {
    final db = await database;
    final record = Map<String, dynamic>.from(category);
    record['sync_status'] = statusPending;
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('categories', record);
  }

  Future<int> updateCategory(int localId, Map<String, dynamic> category) async {
    final db = await database;
    final record = Map<String, dynamic>.from(category);
    record['sync_status'] = statusPending;
    record['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'categories',
      record,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<int> deleteCategory(int localId) async {
    final db = await database;
    return await db.delete(
      'categories',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<void> updateCategoryServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'categories',
      {'server_id': serverId, 'sync_status': statusSynced},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // --- Category Product Stats ---
  Future<Map<int, int>> getCategoryProductCounts() async {
    final db = await database;
    final result = await db.rawQuery('''
     SELECT category_id, COUNT(*) as count 
     FROM products 
     WHERE category_id IS NOT NULL 
     GROUP BY category_id
   ''');

    return {
      for (var row in result)
        if (row['category_id'] != null)
          row['category_id'] as int: row['count'] as int,
    };
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(
    int categoryId,
  ) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
  }

  // --- Customer Management ---
  Future<int> createCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    final record = Map<String, dynamic>.from(customer);
    record['sync_status'] = statusPending;
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('customers', record);
  }

  Future<int> updateCustomer(int localId, Map<String, dynamic> customer) async {
    final db = await database;
    final record = Map<String, dynamic>.from(customer);
    record['sync_status'] = statusPending;
    record['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'customers',
      record,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final db = await database;
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<void> updateCustomerServerId(int localId, int serverId) async {
    final db = await database;
    await db.update(
      'customers',
      {'server_id': serverId, 'sync_status': statusSynced},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveCustomers(List<dynamic> customers) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var item in customers) {
        final data = item as Map<String, dynamic>;
        final record = _prepareRecordForUpsert(data, 'customers');

        final serverId = record['server_id'];
        if (serverId == null) continue;

        // 1. Try to find by server_id
        final existingByServerId = await txn.query(
          'customers',
          where: 'server_id = ?',
          whereArgs: [serverId],
        );

        if (existingByServerId.isNotEmpty) {
          // Update existing synced record
          await txn.update(
            'customers',
            record,
            where: 'server_id = ?',
            whereArgs: [serverId],
          );
        } else {
          // 2. Try to find local duplicate (server_id IS NULL)
          List<Map<String, dynamic>> potentialMatches = [];

          // Match Priority: Phone > Email > Name
          final String? phone = record['phone'];
          final String? email = record['email'];
          final String? name = record['name'];

          if (phone != null && phone.toString().trim().isNotEmpty) {
            potentialMatches = await txn.query(
              'customers',
              where: 'phone = ? AND server_id IS NULL',
              whereArgs: [phone],
            );
          }

          if (potentialMatches.isEmpty &&
              email != null &&
              email.toString().trim().isNotEmpty) {
            potentialMatches = await txn.query(
              'customers',
              where: 'email = ? AND server_id IS NULL',
              whereArgs: [email],
            );
          }

          // Fallback: Match by Name to prevent duplicates for quick entries
          if (potentialMatches.isEmpty &&
              name != null &&
              name.toString().trim().isNotEmpty) {
            potentialMatches = await txn.query(
              'customers',
              where: 'name LIKE ? AND server_id IS NULL',
              whereArgs: [name],
            );
          }

          if (potentialMatches.isNotEmpty) {
            final localId = potentialMatches.first['local_id'];
            await txn.update(
              'customers',
              record,
              where: 'local_id = ?',
              whereArgs: [localId],
            );
          } else {
            // 3. Insert new record
            await txn.insert(
              'customers',
              record,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });
  }

  Future<void> saveSyncedProductItems(
    List<dynamic> items,
    int productLocalId,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var item in items) {
        final map = item as Map<String, dynamic>;
        // Prepare record for smart upsert
        final record = {
          'server_id': map['id'],
          'product_id': productLocalId, // Use the local product ID
          'qr_code': map['qr_code'],
          'status': map['status'],
          'sold_at': map['sold_at'],
          'sync_status': statusSynced,
          'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Upsert logic
        final existing = await txn.query(
          'product_items',
          where: 'server_id = ?',
          whereArgs: [record['server_id']],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          await txn.update(
            'product_items',
            record,
            where: 'server_id = ?',
            whereArgs: [record['server_id']],
          );
        } else {
          await txn.insert(
            'product_items',
            record,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  // --- Sales Management ---
  Future<int> createSale(Map<String, dynamic> sale) async {
    final db = await database;
    return await db.transaction((txn) async {
      final record = Map<String, dynamic>.from(sale);
      final items = record['items'] as List<dynamic>?;
      record.remove('items'); // Remove items from header record

      record['sync_status'] = statusPending;
      if (!record.containsKey('created_at')) {
        record['created_at'] = DateTime.now().toIso8601String();
      }
      record['updated_at'] = DateTime.now().toIso8601String();

      final saleId = await txn.insert('sales', record);

      if (items != null) {
        for (var item in items) {
          final itemMap = Map<String, dynamic>.from(item);
          itemMap['sale_local_id'] = saleId;
          itemMap['subtotal'] =
              (itemMap['quantity'] as num) * (itemMap['unit_price'] as num);

          if (itemMap.containsKey('product_local_id')) {
            final productLocalId = itemMap['product_local_id'] as int;
            final quantity = itemMap['quantity'] as int;
            final productItemLocalId = itemMap['product_item_local_id'] as int?;

            // Insert sale item record
            await txn.insert('sale_items', {
              'sale_local_id': saleId,
              'product_local_id': productLocalId,
              'product_item_local_id': productItemLocalId,
              'quantity': quantity,
              'unit_price': itemMap['unit_price'],
              'subtotal': itemMap['subtotal'],
              'sync_status': statusPending,
            });

            // --- STOCK AND ITEM STATUS UPDATE LOGIC ---
            if (productItemLocalId != null) {
              // This was a sale of a specific, serialized item. Mark it as 'sold'.
              await txn.update(
                'product_items',
                {
                  'status': 'sold',
                  'sold_at': DateTime.now().toIso8601String(),
                  'sync_status': statusPending,
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where:
                    'local_id = ? AND status = ?', // Make sure we only sell available items
                whereArgs: [productItemLocalId, 'available'],
              );
            } else {
              // This was a sale of a bulk product. Reduce quantity from the 'stocks' table.

              // First, get the server_id for the given product_local_id, as 'stocks' table
              // is often related via server_id.
              final productRes = await txn.query(
                'products',
                columns: ['server_id'],
                where: 'local_id = ?',
                whereArgs: [productLocalId],
              );

              int? productServerId;
              if (productRes.isNotEmpty) {
                productServerId = productRes.first['server_id'] as int?;
              }

              // Find the stock record. The 'product_id' in stocks can be either a
              // product's server_id or, for offline products, its local_id.
              List<Map<String, dynamic>> stocks = [];
              if (productServerId != null) {
                stocks = await txn.query(
                  'stocks',
                  where: 'product_id = ?',
                  whereArgs: [productServerId],
                );
              }
              if (stocks.isEmpty) {
                // Fallback for offline-created products or inconsistent data.
                stocks = await txn.query(
                  'stocks',
                  where: 'product_id = ?',
                  whereArgs: [productLocalId],
                );
              }

              if (stocks.isNotEmpty) {
                final stock = stocks.first;
                final newQty = (stock['quantity'] as int) - quantity;

                await txn.update(
                  'stocks',
                  {
                    'quantity': newQty,
                    'sync_status': statusPending,
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'local_id = ?',
                  whereArgs: [stock['local_id']],
                );
              } else {
                // This case should be rare, but we log it by creating a negative stock record.
                // This indicates a sale was made for a product with no corresponding stock entry.
                await txn.insert('stocks', {
                  'product_id':
                      productServerId ??
                      productLocalId, // Use best available ID
                  'quantity': -quantity,
                  'duka_id': record['duka_id'],
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                  'notes':
                      'Stock record created automatically due to sale of product with no prior stock.',
                  'sync_status': statusPending,
                });
              }
            }
          }
        }
      }
      return saleId;
    });
  }

  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        s.*, 
        c.name as customer_name 
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.server_id OR s.customer_id = c.local_id
      ORDER BY s.created_at DESC
    ''');
    return results;
  }

  Future<void> updateSaleServerId(int localId, int serverId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'sales',
        {'server_id': serverId, 'sync_status': statusSynced},
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      await txn.update(
        'sale_items',
        {'sync_status': statusSynced},
        where: 'sale_local_id = ?',
        whereArgs: [localId],
      );
    });
  }

  Future<void> saveSales(List<dynamic> sales) async {
    final db = await database;
    await db.transaction((txn) async {
      await _bulkSmartUpsert(txn, 'sales', sales, 'server_id');
    });
  }

  Future<List<Map<String, dynamic>>> getSalesByCategory(
    DateTimeRange? range,
  ) async {
    final db = await database;
    String dateFilter = '';
    List<dynamic> args = [];

    if (range != null) {
      // Add one day to end date to include the full day
      final end = range.end
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      dateFilter = 'AND s.created_at BETWEEN ? AND ?';
      args.add(range.start.toIso8601String());
      args.add(end.toIso8601String());
    }

    return await db.rawQuery('''
      SELECT c.name, p.category_id, SUM(si.subtotal) as total
      FROM sale_items si
      JOIN sales s ON si.sale_local_id = s.local_id
      JOIN products p ON si.product_local_id = p.local_id
      LEFT JOIN categories c ON p.category_id = c.server_id
      WHERE 1=1 $dateFilter
      GROUP BY p.category_id
      ORDER BY total DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts(
    DateTimeRange? range, {
    int limit = 5,
    int? categoryId,
  }) async {
    final db = await database;
    String dateFilter = '';
    List<dynamic> args = [];

    if (range != null) {
      final end = range.end
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      dateFilter = 'AND s.created_at BETWEEN ? AND ?';
      args.add(range.start.toIso8601String());
      args.add(end.toIso8601String());
    }

    if (categoryId != null) {
      dateFilter += ' AND p.category_id = ?';
      args.add(categoryId);
    }

    args.add(limit);

    return await db.rawQuery('''
      SELECT p.name, SUM(si.quantity) as total_qty, SUM(si.subtotal) as total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_local_id = s.local_id
      JOIN products p ON si.product_local_id = p.local_id
      WHERE 1=1 $dateFilter
      GROUP BY p.local_id
      ORDER BY total_qty DESC
      LIMIT ?
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getLastSevenDaysSales() async {
    final db = await database;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    // Format to match SQLite string comparison (YYYY-MM-DD)
    final sevenDaysAgoStr = sevenDaysAgo.toIso8601String().substring(0, 10);

    return await db.rawQuery(
      '''
      SELECT 
        substr(created_at, 1, 10) as sale_date,
        SUM(total_amount) as total_amount,
        COUNT(*) as count
      FROM sales
      WHERE substr(created_at, 1, 10) >= ?
      GROUP BY sale_date
      ORDER BY sale_date ASC
    ''',
      [sevenDaysAgoStr],
    );
  }

  Future<List<Map<String, dynamic>>> getSalesStatsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    return await db.rawQuery(
      '''
      SELECT 
        substr(created_at, 1, 10) as sale_date,
        SUM(total_amount) as total_amount,
        COUNT(*) as count
      FROM sales
      WHERE substr(created_at, 1, 10) >= ? AND substr(created_at, 1, 10) <= ?
      GROUP BY sale_date
      ORDER BY sale_date ASC
    ''',
      [startStr, endStr],
    );
  }

  // --- POS / Scanning Helper ---
  Future<Map<String, dynamic>?> findProductByBarcodeOrSku(String code) async {
    final db = await database;

    // 1. Prioritize QR Code from product_items table for specific item scanning.
    final items = await db.query(
      'product_items',
      where: 'qr_code = ?',
      whereArgs: [code],
      limit: 1,
    );

    if (items.isNotEmpty) {
      final item = items.first;
      final productId = item['product_id'] as int;

      // The product_id in items could be a local_id or a server_id.
      // We must find the parent product by checking both fields.
      final parentProducts = await db.query(
        'products',
        where: 'local_id = ? OR server_id = ?',
        whereArgs: [productId, productId],
        limit: 1,
      );

      if (parentProducts.isNotEmpty) {
        final product = Map<String, dynamic>.from(parentProducts.first);
        // Attach the specific item info for the sales process
        product['scanned_item_id'] = item['local_id'];
        product['scanned_item_server_id'] = item['server_id'];
        product['scanned_item_status'] = item['status'];
        product['is_specific_item'] =
            true; // Flag to indicate this is a specific scanned item
        return product;
      }
    }

    // 2. If no specific item found, check products table for a generic barcode or SKU.
    final products = await db.query(
      'products',
      where: 'barcode = ? OR sku = ?',
      whereArgs: [code, code],
      limit: 1,
    );

    if (products.isNotEmpty) {
      final product = Map<String, dynamic>.from(products.first);
      product['is_specific_item'] =
          false; // Flag to indicate this is a bulk product
      return product;
    }

    return null;
  }

  // --- TENANT ACCOUNT MANAGEMENT ---

  /// Get tenant account information
  Future<Map<String, dynamic>?> getTenantAccount() async {
    final db = await database;
    final results = await db.query('tenant_account', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  /// Update tenant account information
  Future<int> updateTenantAccount(Map<String, dynamic> tenantData) async {
    final db = await database;

    // Prepare the record for update
    final record = Map<String, dynamic>.from(tenantData);
    record['updated_at'] = DateTime.now().toIso8601String();

    // Set sync status based on whether this record has a server_id
    if (record.containsKey('server_id') && record['server_id'] != null) {
      record['sync_status'] = statusSynced;
    } else {
      record['sync_status'] = statusPending;
    }

    // Check if tenant account exists
    final existingResults = await db.query('tenant_account', limit: 1);

    if (existingResults.isNotEmpty) {
      // Update existing record
      final existingRecord = existingResults.first;
      final existingLocalId = existingRecord['local_id'] as int;

      return await db.update(
        'tenant_account',
        record,
        where: 'local_id = ?',
        whereArgs: [existingLocalId],
      );
    } else {
      // Create new record
      record['created_at'] = DateTime.now().toIso8601String();
      record['server_id'] = record['server_id'];

      return await db.insert('tenant_account', record);
    }
  }

  /// Create tenant account record
  Future<int> createTenantAccount(Map<String, dynamic> tenantData) async {
    final db = await database;

    final record = Map<String, dynamic>.from(tenantData);
    record['created_at'] = DateTime.now().toIso8601String();
    record['updated_at'] = DateTime.now().toIso8601String();
    record['sync_status'] = statusPending;

    return await db.insert('tenant_account', record);
  }

  /// Mark tenant account for sync with server
  Future<void> markTenantAccountForSync() async {
    final db = await database;
    await db.update(
      'tenant_account',
      {'sync_status': statusPending},
      where: 'sync_status = ?',
      whereArgs: [statusSynced],
    );
  }

  /// Get tenant account by local_id
  Future<Map<String, dynamic>?> getTenantAccountById(int localId) async {
    final db = await database;
    final results = await db.query(
      'tenant_account',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // --- PRODUCT SEARCH AND BROWSING ---

  /// Get all products with optional filtering
  Future<List<Map<String, dynamic>>> getAllProducts({
    String? searchQuery,
    int? categoryId,
    bool activeOnly = true,
  }) async {
    final db = await database;

    List<String> whereConditions = [];
    List<dynamic> whereArgs = [];

    if (activeOnly) {
      whereConditions.add('is_active = ?');
      whereArgs.add(1);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereConditions.add('(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm]);
    }

    if (categoryId != null) {
      whereConditions.add('category_id = ?');
      whereArgs.add(categoryId);
    }

    final whereClause =
        whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null;

    final products = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    // Attach stock information
    List<Map<String, dynamic>> results = [];
    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;

      // 1. Bulk Stock
      List<Map<String, dynamic>> stocks = [];
      if (serverId != null) {
        stocks = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }
      if (stocks.isEmpty) {
        stocks = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [localId],
        );
      }
      final int bulkQty =
          stocks.isNotEmpty ? (stocks.first['quantity'] as int? ?? 0) : 0;

      // 2. Item Stock
      String itemQuery =
          "SELECT COUNT(*) as count FROM product_items WHERE status = 'available' AND (product_id = ?";
      List<dynamic> args = [localId];
      if (serverId != null) {
        itemQuery += " OR product_id = ?";
        args.add(serverId);
      }
      itemQuery += ")";

      final itemRes = await db.rawQuery(itemQuery, args);
      final int itemQty = itemRes.first['count'] as int? ?? 0;

      results.add({...product, 'current_stock': bulkQty + itemQty});
    }

    return results;
  }

  /// Get all categories for product browsing
  Future<List<Map<String, dynamic>>> getCategoriesForBrowsing() async {
    final db = await database;
    return await db.query(
      'categories',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'name ASC',
    );
  }

  /// Get products by category
  Future<List<Map<String, dynamic>>> getProductsByCategoryId(
    int categoryId,
  ) async {
    final db = await database;
    return await db.query(
      'products',
      where: 'category_id = ? AND is_active = ?',
      whereArgs: [categoryId, 1],
      orderBy: 'name ASC',
    );
  }

  /// Search products with smart suggestions
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.isEmpty) {
      // Return popular products when no query
      return await getAllProducts(activeOnly: true);
    }

    return await getAllProducts(searchQuery: query, activeOnly: true);
  }

  /// Get recent/frequently sold products for quick access
  Future<List<Map<String, dynamic>>> getPopularProducts({
    int limit = 20,
  }) async {
    final db = await database;
    // This is a simplified version - in real app you'd track sales data
    return await db.query(
      'products',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
      limit: limit,
    );
  }

  // --- Cart Drafts ---
  Future<int> saveCartDraft(Map<String, dynamic> draft) async {
    final db = await database;
    return await db.insert('cart_drafts', draft);
  }

  Future<List<Map<String, dynamic>>> getCartDrafts() async {
    final db = await database;
    return await db.query('cart_drafts', orderBy: 'created_at DESC');
  }

  Future<int> deleteCartDraft(int id) async {
    final db = await database;
    return await db.delete('cart_drafts', where: 'id = ?', whereArgs: [id]);
  }

  // --- PROFORMA INVOICE MANAGEMENT ---

  /// Save proforma invoice as cart draft
  Future<int> saveProformaInvoice(Map<String, dynamic> proformaData) async {
    final db = await database;
    return await db.insert('cart_drafts', proformaData);
  }

  /// Get all proforma invoices (from cart drafts)
  Future<List<Map<String, dynamic>>> getAllProformaInvoices() async {
    final db = await database;
    return await db.query('cart_drafts', orderBy: 'created_at DESC');
  }

  /// Get proforma invoice by ID
  Future<Map<String, dynamic>?> getProformaInvoiceById(int id) async {
    final db = await database;
    final results = await db.query(
      'cart_drafts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Delete proforma invoice
  Future<int> deleteProformaInvoice(int id) async {
    final db = await database;
    return await db.delete('cart_drafts', where: 'id = ?', whereArgs: [id]);
  }

  // --- STOCK ADJUSTMENT ---
  Future<void> adjustStock(
    Map<String, dynamic> product,
    int quantityChange,
    String reason,
  ) async {
    final db = await database;
    final int localId = product['local_id'];
    final int? serverId = product['server_id'];
    final int dukaId = product['duka_id'] ?? 1;

    await db.transaction((txn) async {
      // 1. Find existing stock
      List<Map<String, dynamic>> stocks = [];
      if (serverId != null) {
        stocks = await txn.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }
      if (stocks.isEmpty) {
        stocks = await txn.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [localId],
        );
      }

      if (stocks.isNotEmpty) {
        final stock = stocks.first;
        final currentQty = stock['quantity'] as int;
        final newQty = currentQty + quantityChange;

        await txn.update(
          'stocks',
          {
            'quantity': newQty,
            'sync_status': statusPending,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'local_id = ?',
          whereArgs: [stock['local_id']],
        );
      } else {
        // Create new stock record if none exists
        final productIdForStock = serverId ?? localId;
        await txn.insert('stocks', {
          'product_id': productIdForStock,
          'duka_id': dukaId,
          'quantity': quantityChange,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': statusPending,
        });
      }

      // 2. Record Movement
      final productIdForMovement = serverId ?? localId;
      await txn.insert('stock_movements', {
        'product_id': productIdForMovement,
        'duka_id': dukaId,
        'quantity': quantityChange,
        'type': quantityChange > 0 ? 'adjustment_in' : 'adjustment_out',
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': statusPending,
      });
    });
  }

  // --- Low Stock Alert ---
  Future<List<Map<String, dynamic>>> getLowStockProducts({
    int threshold = 10,
  }) async {
    final db = await database;
    // Only check active products
    final products = await db.query('products', where: 'is_active = 1');
    List<Map<String, dynamic>> lowStockProducts = [];

    for (var product in products) {
      final localId = product['local_id'] as int;
      final serverId = product['server_id'] as int?;

      // 1. Bulk Stock
      List<Map<String, dynamic>> stocks = [];
      if (serverId != null) {
        stocks = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [serverId],
        );
      }
      if (stocks.isEmpty) {
        stocks = await db.query(
          'stocks',
          where: 'product_id = ?',
          whereArgs: [localId],
        );
      }
      final int bulkQty =
          stocks.isNotEmpty ? (stocks.first['quantity'] as int? ?? 0) : 0;

      // 2. Item Stock
      // Check both local_id and server_id for items to be safe
      String itemQuery =
          "SELECT COUNT(*) as count FROM product_items WHERE status = 'available' AND (product_id = ?";
      List<dynamic> args = [localId];
      if (serverId != null) {
        itemQuery += " OR product_id = ?";
        args.add(serverId);
      }
      itemQuery += ")";

      final itemRes = await db.rawQuery(itemQuery, args);
      final int itemQty = itemRes.first['count'] as int? ?? 0;

      final total = bulkQty + itemQty;

      if (total <= threshold) {
        lowStockProducts.add({...product, 'current_stock': total});
      }
    }
    return lowStockProducts;
  }

  // --- STOCK CALCULATION ---
  Future<int> calculateProductStock(int productId) async {
    final db = await database;

    // 1. Get bulk stock quantity from 'stocks' table
    // Check using server_id first (if productId is server_id)
    final bulkRes = await db.rawQuery(
      'SELECT SUM(quantity) as total FROM stocks WHERE product_id = ? OR product_id = (SELECT local_id FROM products WHERE server_id = ?)',
      [productId, productId],
    );
    final int bulkStock = (bulkRes.first['total'] as int?) ?? 0;

    // 2. Get individual item count from 'product_items' table (unsold items)
    final itemRes = await db.rawQuery(
      "SELECT COUNT(*) as count FROM product_items WHERE (product_id = ? OR product_id = (SELECT local_id FROM products WHERE server_id = ?)) AND status != 'sold'",
      [productId, productId],
    );
    final int itemStock = (itemRes.first['count'] as int?) ?? 0;

    return bulkStock + itemStock;
  }

  // --- BACKUP & RESTORE ---

  Future<String> getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _databaseName);
  }

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  // --- LOAN PAYMENTS QUERY METHODS ---

  /// Get all loan payments
  Future<List<Map<String, dynamic>>> getAllLoanPayments() async {
    final db = await database;
    return await db.query('loan_payments', orderBy: 'payment_date DESC');
  }

  /// Get loan payments by sale server ID
  Future<List<Map<String, dynamic>>> getLoanPaymentsBySaleServerId(
    int saleServerId,
  ) async {
    final db = await database;
    return await db.query(
      'loan_payments',
      where: 'sale_server_id = ?',
      whereArgs: [saleServerId],
      orderBy: 'payment_date DESC',
    );
  }

  /// Get loan payments by sale local ID
  Future<List<Map<String, dynamic>>> getLoanPaymentsBySaleLocalId(
    int saleLocalId,
  ) async {
    final db = await database;
    // First get the sale's server_id
    final saleResult = await db.query(
      'sales',
      columns: ['server_id'],
      where: 'local_id = ?',
      whereArgs: [saleLocalId],
    );

    if (saleResult.isEmpty) return [];

    final saleServerId = saleResult.first['server_id'] as int?;
    if (saleServerId == null) return [];

    return await getLoanPaymentsBySaleServerId(saleServerId);
  }

  /// Get total loan payments amount for a sale
  Future<double> getTotalLoanPaymentsForSale(int saleServerId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM loan_payments WHERE sale_server_id = ?',
      [saleServerId],
    );
    return (result.first['total'] as double?) ?? 0.0;
  }

  /// Debug method to print loan payments data
  Future<void> debugPrintLoanPayments() async {
    final db = await database;
    final payments = await db.query('loan_payments');

    print('\n🔍 LOAN PAYMENTS DEBUG INFO:');
    print('Total records: ${payments.length}');

    for (var payment in payments) {
      print(
        'Payment ID: ${payment['local_id']} (Server: ${payment['server_id']})',
      );
      print('  Sale Server ID: ${payment['sale_server_id']}');
      print('  Amount: ${payment['amount']}');
      print('  Date: ${payment['payment_date']}');
      print('  Notes: ${payment['notes']}');
      print('  User ID: ${payment['user_id']}');
      print('  Created: ${payment['created_at']}');
      print('  Updated: ${payment['updated_at']}');
      print('  Sync Status: ${payment['sync_status']}');
      print('---');
    }

    if (payments.isEmpty) {
      print('No loan payments found in database.');
    }
  }

  /// Get loan payments in the original API structure format
  /// Returns Map<int, List<Map<String, dynamic>>> like {49: [], 50: [], 57: [...]}
  Future<Map<int, List<Map<String, dynamic>>>>
  getLoanPaymentsMapStructure() async {
    final db = await database;
    final payments = await db.query(
      'loan_payments',
      orderBy: 'sale_server_id, payment_date DESC',
    );

    Map<int, List<Map<String, dynamic>>> result = {};

    for (var payment in payments) {
      final saleServerId = payment['sale_server_id'] as int;
      if (!result.containsKey(saleServerId)) {
        result[saleServerId] = [];
      }
      result[saleServerId]!.add(payment);
    }

    return result;
  }

  Future<bool> restoreDatabase(String backupPath) async {
    try {
      await closeDatabase();
      final dbPath = await getDatabasePath();
      final backupFile = File(backupPath);
      await backupFile.copy(dbPath);
      await database; // Re-open connection
      return true;
    } catch (e) {
      debugPrint('Error restoring database: $e');
      return false;
    }
  }

  /// Handles soft-deleted products by removing them and their related data from the local database.
  Future<void> processDeletedProducts(List<dynamic> deletedIds) async {
    final db = await database;

    await db.transaction((txn) async {
      await _processDeletedProducts(txn, deletedIds);
    });
  }

  // --- Customer Deletion ---
  Future<int> deleteCustomer(int localId) async {
    final db = await database;
    return await db.delete(
      'customers',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  // --- DASHBOARD SUMMARY FROM INFO TABLES ---
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final db = await database;

    final tenantRes = await db.query('tenantsinfo', limit: 1);
    final tenant = tenantRes.isNotEmpty ? tenantRes.first : null;

    final dukasRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM dukasinfo',
    );
    final productsRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM productsinfo',
    );
    final customersRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customersinfo',
    );
    final salesRes = await db.rawQuery('''
      SELECT 
        COUNT(*) as count, 
        SUM(total_amount) as total_revenue,
        SUM(discount_amount) as total_discount,
        SUM(profit_loss) as total_profit
      FROM salesinfo
    ''');

    final transactionsRes = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expense
      FROM transactionsinfo
    ''');

    final subsRes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM duka_subscriptionsinfo',
    );

    return {
      'tenant': tenant,
      'duka_count': dukasRes.first['count'] ?? 0,
      'product_count': productsRes.first['count'] ?? 0,
      'customer_count': customersRes.first['count'] ?? 0,
      'sales': {
        'count': salesRes.first['count'] ?? 0,
        'revenue': salesRes.first['total_revenue'] ?? 0.0,
        'discount': salesRes.first['total_discount'] ?? 0.0,
        'profit': salesRes.first['total_profit'] ?? 0.0,
      },
      'transactions': {
        'income': transactionsRes.first['total_income'] ?? 0.0,
        'expense': transactionsRes.first['total_expense'] ?? 0.0,
      },
      'subscription_count': subsRes.first['count'] ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getDukasInfo() async {
    final db = await database;
    return await db.query('dukasinfo');
  }
}
