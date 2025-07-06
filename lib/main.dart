import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;

void main() {
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9C77CF)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF9C77CF),
          foregroundColor: Colors.white,
        ),
      ),
      home: const ExpenseTrackerHome(),
    );
  }
}

enum TransactionType { expense, income }
enum ExportFormat { csv, json, excel }

class Transaction {
  final String id;
  final double amount;
  final String description;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String accountId;

  const Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    required this.categoryId,
    required this.accountId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'categoryId': categoryId,
      'accountId': accountId,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      amount: json['amount'].toDouble(),
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: json['type'] == 'TransactionType.expense' 
          ? TransactionType.expense 
          : TransactionType.income,
      categoryId: json['categoryId'] ?? 'default',
      accountId: json['accountId'] ?? 'personal',
    );
  }

  Transaction copyWith({
    String? id,
    double? amount,
    String? description,
    DateTime? date,
    TransactionType? type,
    String? categoryId,
    String? accountId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
    );
  }
}

class Account {
  final String id;
  final String name;
  final String description;
  final Color color;
  final IconData icon;

  const Account({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color.value,
      'icon': icon.codePoint,
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: Color(json['color']),
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    );
  }
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final TransactionType type;
  final List<String> descriptions;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.descriptions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'color': color.value,
      'type': type.toString(),
      'descriptions': descriptions,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      type: json['type'] == 'TransactionType.expense' 
          ? TransactionType.expense 
          : TransactionType.income,
      descriptions: List<String>.from(json['descriptions'] ?? []),
    );
  }
}

class ExportService {
  static String _getCurrentDateTime() {
    return '2025-07-06 06:36:36';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static void exportToJson({
    required List<Transaction> transactions,
    required List<Category> categories,
    required List<Account> accounts,
    required String currentUser,
    String? selectedAccountId,
  }) {
    final exportData = {
      'metadata': {
        'exported_by': currentUser,
        'exported_at_utc': _getCurrentDateTime(),
        'version': '1.0',
        'format': 'json',
        'account_filter': selectedAccountId,
        'total_transactions': transactions.length,
      },
      'summary': {
        'total_income': transactions
            .where((t) => t.type == TransactionType.income)
            .fold(0.0, (sum, t) => sum + t.amount),
        'total_expenses': transactions
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (sum, t) => sum + t.amount),
        'net_balance': transactions.fold(0.0, (sum, t) => 
            sum + (t.type == TransactionType.income ? t.amount : -t.amount)),
      },
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => {
        ...t.toJson(),
        'category_name': categories.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () => const Category(
            id: 'unknown', name: 'Unknown', icon: Icons.help,
            color: Colors.grey, type: TransactionType.expense, descriptions: [],
          ),
        ).name,
        'account_name': accounts.firstWhere(
          (a) => a.id == t.accountId,
          orElse: () => const Account(
            id: 'unknown', name: 'Unknown', description: '',
            color: Colors.grey, icon: Icons.help,
          ),
        ).name,
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    final fileName = 'expense_tracker_${currentUser}_${DateTime.now().millisecondsSinceEpoch}.json';
    
    _downloadFile(jsonString, fileName, 'application/json');
  }

  static void exportToCsv({
    required List<Transaction> transactions,
    required List<Category> categories,
    required List<Account> accounts,
    required String currentUser,
    String? selectedAccountId,
  }) {
    final csvRows = <String>[];
    
    csvRows.add('# Expense Tracker Export');
    csvRows.add('# Exported by: $currentUser');
    csvRows.add('# Exported at (UTC): ${_getCurrentDateTime()}');
    csvRows.add('# Account filter: ${selectedAccountId ?? "All accounts"}');
    csvRows.add('# Total transactions: ${transactions.length}');
    csvRows.add('');
    csvRows.add('ID,Date,Type,Amount,Description,Category,Account,Category_ID,Account_ID');
    
    for (final transaction in transactions) {
      final category = categories.firstWhere(
        (c) => c.id == transaction.categoryId,
        orElse: () => const Category(
          id: 'unknown', name: 'Unknown', icon: Icons.help,
          color: Colors.grey, type: TransactionType.expense, descriptions: [],
        ),
      );
      
      final account = accounts.firstWhere(
        (a) => a.id == transaction.accountId,
        orElse: () => const Account(
          id: 'unknown', name: 'Unknown', description: '',
          color: Colors.grey, icon: Icons.help,
        ),
      );
      
      final row = [
        transaction.id,
        _formatDate(transaction.date),
        transaction.type == TransactionType.income ? 'Income' : 'Expense',
        transaction.amount.toString(),
        '"${transaction.description.replaceAll('"', '""')}"',
        '"${category.name.replaceAll('"', '""')}"',
        '"${account.name.replaceAll('"', '""')}"',
        transaction.categoryId,
        transaction.accountId,
      ].join(',');
      
      csvRows.add(row);
    }
    
    final csvContent = csvRows.join('\n');
    final fileName = 'expense_tracker_${currentUser}_${DateTime.now().millisecondsSinceEpoch}.csv';
    
    _downloadFile(csvContent, fileName, 'text/csv');
  }

  static void exportToExcel({
    required List<Transaction> transactions,
    required List<Category> categories,
    required List<Account> accounts,
    required String currentUser,
    String? selectedAccountId,
  }) {
    final htmlRows = <String>[];
    
    htmlRows.add('<!DOCTYPE html>');
    htmlRows.add('<html>');
    htmlRows.add('<head>');
    htmlRows.add('<meta charset="UTF-8">');
    htmlRows.add('<title>Expense Tracker Export - $currentUser</title>');
    htmlRows.add('<style>');
    htmlRows.add('table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; }');
    htmlRows.add('th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }');
    htmlRows.add('th { background-color: #9C77CF; color: white; font-weight: bold; }');
    htmlRows.add('.expense { color: #d32f2f; }');
    htmlRows.add('.income { color: #388e3c; }');
    htmlRows.add('.header-info { margin-bottom: 20px; background-color: #f5f5f5; padding: 10px; border-radius: 5px; }');
    htmlRows.add('</style>');
    htmlRows.add('</head>');
    htmlRows.add('<body>');
    
    htmlRows.add('<div class="header-info">');
    htmlRows.add('<h1>💰 Expense Tracker Export</h1>');
    htmlRows.add('<p><strong>User:</strong> $currentUser</p>');
    htmlRows.add('<p><strong>Exported at (UTC):</strong> ${_getCurrentDateTime()}</p>');
    htmlRows.add('<p><strong>Account filter:</strong> ${selectedAccountId ?? "All accounts"}</p>');
    htmlRows.add('<p><strong>Total transactions:</strong> ${transactions.length}</p>');
    
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final netBalance = totalIncome - totalExpenses;
    
    htmlRows.add('<p><strong>Total Income:</strong> \$${totalIncome.toStringAsFixed(2)}</p>');
    htmlRows.add('<p><strong>Total Expenses:</strong> \$${totalExpenses.toStringAsFixed(2)}</p>');
    htmlRows.add('<p><strong>Net Balance:</strong> <span style="color: ${netBalance >= 0 ? '#388e3c' : '#d32f2f'}">\$${netBalance.toStringAsFixed(2)}</span></p>');
    htmlRows.add('</div>');
    
    htmlRows.add('<table>');
    htmlRows.add('<thead>');
    htmlRows.add('<tr>');
    htmlRows.add('<th>Date</th>');
    htmlRows.add('<th>Type</th>');
    htmlRows.add('<th>Amount</th>');
    htmlRows.add('<th>Description</th>');
    htmlRows.add('<th>Category</th>');
    htmlRows.add('<th>Account</th>');
    htmlRows.add('<th>ID</th>');
    htmlRows.add('</tr>');
    htmlRows.add('</thead>');
    htmlRows.add('<tbody>');
    
    for (final transaction in transactions.reversed) {
      final category = categories.firstWhere(
        (c) => c.id == transaction.categoryId,
        orElse: () => const Category(
          id: 'unknown', name: 'Unknown', icon: Icons.help,
          color: Colors.grey, type: TransactionType.expense, descriptions: [],
        ),
      );
      
      final account = accounts.firstWhere(
        (a) => a.id == transaction.accountId,
        orElse: () => const Account(
          id: 'unknown', name: 'Unknown', description: '',
          color: Colors.grey, icon: Icons.help,
        ),
      );
      
      final typeClass = transaction.type == TransactionType.income ? 'income' : 'expense';
      final typeSign = transaction.type == TransactionType.income ? '+' : '-';
      
      htmlRows.add('<tr>');
      htmlRows.add('<td>${_formatDate(transaction.date)}</td>');
      htmlRows.add('<td class="$typeClass">${transaction.type == TransactionType.income ? 'Income' : 'Expense'}</td>');
      htmlRows.add('<td class="$typeClass">$typeSign\$${transaction.amount.toStringAsFixed(2)}</td>');
      htmlRows.add('<td>${transaction.description}</td>');
      htmlRows.add('<td>${category.name}</td>');
      htmlRows.add('<td>${account.name}</td>');
      htmlRows.add('<td style="font-family: monospace; font-size: 10px;">${transaction.id}</td>');
      htmlRows.add('</tr>');
    }
    
    htmlRows.add('</tbody>');
    htmlRows.add('</table>');
    htmlRows.add('</body>');
    htmlRows.add('</html>');
    
    final htmlContent = htmlRows.join('\n');
    final fileName = 'expense_tracker_${currentUser}_${DateTime.now().millisecondsSinceEpoch}.xls';
    
    _downloadFile(htmlContent, fileName, 'application/vnd.ms-excel');
  }

  static void _downloadFile(String content, String fileName, String mimeType) {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}

class ExpenseTrackerHome extends StatefulWidget {
  const ExpenseTrackerHome({super.key});

  @override
  State<ExpenseTrackerHome> createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome> {
  final List<Transaction> _transactions = [];
  final List<Category> _categories = [];
  final List<Account> _accounts = [];
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _selectedAccountId = 'personal';
  String _searchQuery = '';
  
  final String currentUser = 'angra8410';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAccounts();
    await _loadCategories();
    await _loadTransactions();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList('accounts');
    
    if (accountsJson == null || accountsJson.isEmpty) {
      _accounts.addAll(_getDefaultAccounts());
      await _saveAccounts();
    } else {
      _accounts.clear();
      for (String accountString in accountsJson) {
        try {
          final accountMap = json.decode(accountString);
          _accounts.add(Account.fromJson(accountMap));
        } catch (e) {
          print('Error loading account: $e');
        }
      }
    }
  }

  List<Account> _getDefaultAccounts() {
    return const [
      Account(
        id: 'personal',
        name: 'Personal',
        description: 'Personal expenses and income',
        color: Colors.blue,
        icon: Icons.person,
      ),
      Account(
        id: 'business',
        name: 'Business',
        description: 'Business expenses and income',
        color: Colors.green,
        icon: Icons.business,
      ),
      Account(
        id: 'savings',
        name: 'Savings',
        description: 'Savings and investments',
        color: Colors.orange,
        icon: Icons.savings,
      ),
    ];
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = _accounts
        .map((account) => json.encode(account.toJson()))
        .toList();
    await prefs.setStringList('accounts', accountsJson);
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList('categories');
    
    if (categoriesJson == null || categoriesJson.isEmpty) {
      _categories.addAll(_getDefaultCategories());
      await _saveCategories();
    } else {
      _categories.clear();
      for (String categoryString in categoriesJson) {
        try {
          final categoryMap = json.decode(categoryString);
          _categories.add(Category.fromJson(categoryMap));
        } catch (e) {
          print('Error loading category: $e');
        }
      }
    }
  }

  List<Category> _getDefaultCategories() {
    return const [
      Category(
        id: 'ingreso',
        name: 'Ingreso',
        icon: Icons.work,
        color: Colors.green,
        type: TransactionType.income,
        descriptions: ['Salario', 'Sueldo', 'Pago'],
      ),
      Category(
        id: 'ingreso_extra',
        name: 'Ingreso Extra',
        icon: Icons.attach_money,
        color: Colors.lightGreen,
        type: TransactionType.income,
        descriptions: ['Otros', 'Bonus', 'Extra'],
      ),
      Category(
        id: 'transporte',
        name: 'Transporte',
        icon: Icons.train,
        color: Colors.blue,
        type: TransactionType.expense,
        descriptions: ['Metro', 'Bus', 'Taxi', 'Uber'],
      ),
      Category(
        id: 'alimentacion',
        name: 'Alimentación',
        icon: Icons.restaurant,
        color: Colors.orange,
        type: TransactionType.expense,
        descriptions: ['Mercado', 'Supermercado', 'Comida'],
      ),
      Category(
        id: 'otros_gastos',
        name: 'Otros Gastos',
        icon: Icons.home,
        color: Colors.brown,
        type: TransactionType.expense,
        descriptions: ['Arriendo', 'Tc y Prestamos', 'Donaciones', 'Familia'],
      ),
      Category(
        id: 'ocio',
        name: 'Ocio',
        icon: Icons.movie,
        color: Colors.purple,
        type: TransactionType.expense,
        descriptions: ['Restaurante', 'Cine', 'Helados', 'Streaming'],
      ),
      Category(
        id: 'mascotas',
        name: 'Mascotas',
        icon: Icons.pets,
        color: Colors.pink,
        type: TransactionType.expense,
        descriptions: ['Lobitos', 'Veterinario', 'Comida mascota'],
      ),
      Category(
        id: 'servicios',
        name: 'Servicios',
        icon: Icons.wifi,
        color: Colors.indigo,
        type: TransactionType.expense,
        descriptions: ['Wom', 'Tigo Hogar', 'Tigo Movil', 'Internet'],
      ),
    ];
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = _categories
        .map((category) => json.encode(category.toJson()))
        .toList();
    await prefs.setStringList('categories', categoriesJson);
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getStringList('transactions') ?? [];
    
    _transactions.clear();
    for (String transactionString in transactionsJson) {
      try {
        final transactionMap = json.decode(transactionString);
        _transactions.add(Transaction.fromJson(transactionMap));
      } catch (e) {
        print('Error loading transaction: $e');
      }
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = _transactions
        .map((transaction) => json.encode(transaction.toJson()))
        .toList();
    await prefs.setStringList('transactions', transactionsJson);
  }

  double get _totalIncome {
    return _filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _totalExpenses {
    return _filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _balance => _totalIncome - _totalExpenses;

  List<Transaction> get _filteredTransactions {
    var filtered = _transactions.where((t) => t.accountId == _selectedAccountId).toList();
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final category = _categories.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () => const Category(
            id: '', name: '', icon: Icons.help, color: Colors.grey,
            type: TransactionType.expense, descriptions: [],
          ),
        );
        return t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               category.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return filtered;
  }

  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return '${now.month}/${now.year}';
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Color(0xFF9C77CF)),
            SizedBox(width: 8),
            Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export your expense data in different formats:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Current account: ${_accounts.firstWhere((a) => a.id == _selectedAccountId).name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Transactions to export: ${_filteredTransactions.length}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            
            Card(
              child: ListTile(
                leading: const Icon(Icons.code, color: Colors.blue),
                title: const Text('JSON Format'),
                subtitle: const Text('Complete data with metadata\nBest for backups and imports'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  ExportService.exportToJson(
                    transactions: _filteredTransactions,
                    categories: _categories,
                    accounts: _accounts,
                    currentUser: currentUser,
                    selectedAccountId: _selectedAccountId,
                  );
                  _showExportSuccessSnackBar('JSON');
                },
              ),
            ),
            
            Card(
              child: ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('CSV Format'),
                subtitle: const Text('Spreadsheet compatible\nGreat for Excel and analysis'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  ExportService.exportToCsv(
                    transactions: _filteredTransactions,
                    categories: _categories,
                    accounts: _accounts,
                    currentUser: currentUser,
                    selectedAccountId: _selectedAccountId,
                  );
                  _showExportSuccessSnackBar('CSV');
                },
              ),
            ),
            
            Card(
              child: ListTile(
                leading: const Icon(Icons.grid_on, color: Colors.orange),
                title: const Text('Excel Format'),
                subtitle: const Text('Rich formatting with colors\nOpens directly in Excel'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  ExportService.exportToExcel(
                    transactions: _filteredTransactions,
                    categories: _categories,
                    accounts: _accounts,
                    currentUser: currentUser,
                    selectedAccountId: _selectedAccountId,
                  );
                  _showExportSuccessSnackBar('Excel');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showExportSuccessSnackBar(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('$format export downloaded successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Expense Tracker'),
          backgroundColor: const Color(0xFF9C77CF),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando expense tracker...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        backgroundColor: const Color(0xFF9C77CF),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportDialog,
            tooltip: 'Export Data',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_balance_wallet),
            onSelected: (accountId) {
              setState(() {
                _selectedAccountId = accountId;
              });
            },
            itemBuilder: (context) => _accounts.map((account) {
              return PopupMenuItem(
                value: account.id,
                child: Row(
                  children: [
                    Icon(account.icon, color: account.color),
                    const SizedBox(width: 8),
                    Text(account.name),
                    if (account.id == _selectedAccountId)
                      const Icon(Icons.check, color: Colors.green),
                  ],
                ),
              );
            }).toList(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '\$${_balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _selectedIndex == 0 
          ? _buildHomeTab()
          : _selectedIndex == 1
              ? _buildAnalyticsTab()
              : _buildAccountsTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Accounts',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 
          ? FloatingActionButton(
              onPressed: _showAddTransactionDialog,
              backgroundColor: const Color(0xFF9C77CF),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF9C77CF),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentUser,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9C77CF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: Color(0xFF9C77CF)),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Summary - ${_getCurrentMonthYear()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C77CF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'angra8410 | UTC: 2025-07-06 06:36:36',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.green, size: 32),
                          const SizedBox(height: 8),
                          const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '\$${_totalIncome.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.trending_down, color: Colors.red, size: 32),
                          const SizedBox(height: 8),
                          const Text('Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '\$${_totalExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: _balance >= 0 ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text('Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '\$${_balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _balance >= 0 ? Colors.green : Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _filteredTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions yet!',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first transaction',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'User: $currentUser | Ready to track expenses!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _filteredTransactions[_filteredTransactions.length - 1 - index];
                    final category = _categories.firstWhere(
                      (c) => c.id == transaction.categoryId,
                      orElse: () => const Category(
                        id: 'default',
                        name: 'Unknown',
                        icon: Icons.help,
                        color: Colors.grey,
                        type: TransactionType.expense,
                        descriptions: [],
                      ),
                    );
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: category.color.withOpacity(0.2),
                          child: Icon(category.icon, color: category.color),
                        ),
                        title: Text(transaction.description),
                        subtitle: Text(
                          '${category.name} • ${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${transaction.type == TransactionType.expense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: transaction.type == TransactionType.expense
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditTransactionDialog(transaction);
                                } else if (value == 'delete') {
                                  _deleteTransaction(transaction.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    final expensesByCategory = <String, double>{};
    final incomeByCategory = <String, double>{};
    
    for (final transaction in _filteredTransactions) {
      final category = _categories.firstWhere(
        (c) => c.id == transaction.categoryId,
        orElse: () => const Category(
          id: 'unknown', name: 'Unknown', icon: Icons.help,
          color: Colors.grey, type: TransactionType.expense, descriptions: [],
        ),
      );
      
      if (transaction.type == TransactionType.expense) {
        expensesByCategory[category.name] = 
            (expensesByCategory[category.name] ?? 0) + transaction.amount;
      } else {
        incomeByCategory[category.name] = 
            (incomeByCategory[category.name] ?? 0) + transaction.amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF9C77CF)),
              title: const Text('Export Data'),
              subtitle: const Text('Download your expense data in various formats'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showExportDialog,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.bar_chart, size: 32, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(
                          '${_filteredTransactions.length}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Total Transactions'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.category, size: 32, color: Colors.orange),
                        const SizedBox(height: 8),
                        Text(
                          '${expensesByCategory.length}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Categories Used'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            '💰 Expenses by Category',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...expensesByCategory.entries.map((entry) {
            final category = _categories.firstWhere(
              (c) => c.name == entry.key,
              orElse: () => const Category(
                id: 'unknown', name: 'Unknown', icon: Icons.help,
                color: Colors.grey, type: TransactionType.expense, descriptions: [],
              ),
            );
            final percentage = (_totalExpenses > 0) ? (entry.value / _totalExpenses * 100) : 0;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.color.withOpacity(0.2),
                  child: Icon(category.icon, color: category.color),
                ),
                title: Text(entry.key),
                subtitle: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[300],
                  color: category.color,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          if (incomeByCategory.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '💚 Income by Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...incomeByCategory.entries.map((entry) {
              final category = _categories.firstWhere(
                (c) => c.name == entry.key,
                orElse: () => const Category(
                  id: 'unknown', name: 'Unknown', icon: Icons.help,
                  color: Colors.grey, type: TransactionType.income, descriptions: [],
                ),
              );
              final percentage = (_totalIncome > 0) ? (entry.value / _totalIncome * 100) : 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.color.withOpacity(0.2),
                    child: Icon(category.icon, color: category.color),
                  ),
                  title: Text(entry.key),
                  subtitle: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[300],
                    color: category.color,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${entry.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💼 Account Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your different accounts and export data',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF9C77CF)),
              title: const Text('Export All Data'),
              subtitle: const Text('Download complete expense data across all accounts'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showExportDialog,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _accounts.firstWhere((a) => a.id == _selectedAccountId).color.withOpacity(0.2),
                        child: Icon(
                          _accounts.firstWhere((a) => a.id == _selectedAccountId).icon,
                          color: _accounts.firstWhere((a) => a.id == _selectedAccountId).color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _accounts.firstWhere((a) => a.id == _selectedAccountId).name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _accounts.firstWhere((a) => a.id == _selectedAccountId).description,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'All Accounts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                final accountTransactions = _transactions.where((t) => t.accountId == account.id).toList();
                final accountBalance = accountTransactions.fold<double>(
                  0.0,
                  (sum, t) => sum + (t.type == TransactionType.income ? t.amount : -t.amount),
                );
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: account.color.withOpacity(0.2),
                      child: Icon(account.icon, color: account.color),
                    ),
                    title: Text(account.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.description),
                        const SizedBox(height: 4),
                        Text(
                          '${accountTransactions.length} transactions',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${accountBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: accountBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        if (account.id == _selectedAccountId)
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedAccountId = account.id;
                        _selectedIndex = 0;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTransactionSheet(
        categories: _categories,
        accounts: _accounts,
        selectedAccountId: _selectedAccountId,
        onAddTransaction: _addTransaction,
      ),
    );
  }

  void _showEditTransactionDialog(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditTransactionSheet(
        transaction: transaction,
        categories: _categories,
        accounts: _accounts,
        onUpdateTransaction: _updateTransaction,
      ),
    );
  }

  void _addTransaction(Transaction transaction) {
    setState(() {
      _transactions.add(transaction);
    });
    _saveTransactions();
  }

  void _updateTransaction(Transaction updatedTransaction) {
    setState(() {
      final index = _transactions.indexWhere((t) => t.id == updatedTransaction.id);
      if (index != -1) {
        _transactions[index] = updatedTransaction;
      }
    });
    _saveTransactions();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveTransactions();
  }
}

class AddTransactionSheet extends StatefulWidget {
  final List<Category> categories;
  final List<Account> accounts;
  final String selectedAccountId;
  final Function(Transaction) onAddTransaction;

  const AddTransactionSheet({
    super.key,
    required this.categories,
    required this.accounts,
    required this.selectedAccountId,
    required this.onAddTransaction,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.selectedAccountId;
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C77CF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.categories.where((c) => c.type == _selectedType).toList();
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.add_circle, color: Color(0xFF9C77CF)),
                        const SizedBox(width: 8),
                        const Text(
                          'Add Transaction',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (Set<TransactionType> selection) {
                        setState(() {
                          _selectedType = selection.first;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF9C77CF)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transaction Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDisplayDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                        helperText: 'Enter the transaction amount',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        helperText: 'What was this transaction for?',
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        if (value.length < 3) {
                          return 'Description must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        helperText: 'Select transaction category',
                      ),
                      items: filteredCategories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(category.icon, color: category.color),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                                            onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                        helperText: 'Select account for this transaction',
                      ),
                      items: widget.accounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Row(
                            children: [
                              Icon(account.icon, color: account.color),
                              const SizedBox(width: 8),
                              Text(account.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountId = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C77CF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9C77CF).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📝 Transaction Preview',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9C77CF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _selectedType == TransactionType.expense ? Icons.remove_circle : Icons.add_circle,
                                color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedType == TransactionType.expense ? 'Expense' : 'Income',
                                style: TextStyle(
                                  color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedType == TransactionType.expense ? '-' : '+'}\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${_formatDisplayDate(_selectedDate)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C77CF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '💾 Add Transaction',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addTransaction() {
    if (_formKey.currentState!.validate()) {
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        date: _selectedDate,
        type: _selectedType,
        categoryId: _selectedCategoryId!,
        accountId: _selectedAccountId!,
      );
      
      widget.onAddTransaction(transaction);
      Navigator.pop(context);
    }
  }
}

class EditTransactionSheet extends StatefulWidget {
  final Transaction transaction;
  final List<Category> categories;
  final List<Account> accounts;
  final Function(Transaction) onUpdateTransaction;

  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.categories,
    required this.accounts,
    required this.onUpdateTransaction,
  });

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  
  late TransactionType _selectedType;
  late String _selectedCategoryId;
  late String _selectedAccountId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.transaction.amount.toString());
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _selectedType = widget.transaction.type;
    _selectedCategoryId = widget.transaction.categoryId;
    _selectedAccountId = widget.transaction.accountId;
    _selectedDate = widget.transaction.date;
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C77CF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = widget.categories.where((c) => c.type == _selectedType).toList();
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit, color: Color(0xFF9C77CF)),
                        const SizedBox(width: 8),
                        const Text(
                          'Edit Transaction',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                      selected: {_selectedType},
                      onSelectionChanged: (Set<TransactionType> selection) {
                        setState(() {
                          _selectedType = selection.first;
                          final newFilteredCategories = widget.categories.where((c) => c.type == _selectedType).toList();
                          if (!newFilteredCategories.any((c) => c.id == _selectedCategoryId)) {
                            _selectedCategoryId = newFilteredCategories.isNotEmpty ? newFilteredCategories.first.id : '';
                          }
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF9C77CF)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transaction Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDisplayDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        if (value.length < 3) {
                          return 'Description must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: filteredCategories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: filteredCategories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(category.icon, color: category.color),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.accounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Row(
                            children: [
                              Icon(account.icon, color: account.color),
                              const SizedBox(width: 8),
                              Text(account.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountId = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C77CF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9C77CF).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '✏️ Transaction Preview',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9C77CF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _selectedType == TransactionType.expense ? Icons.remove_circle : Icons.add_circle,
                                color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedType == TransactionType.expense ? 'Expense' : 'Income',
                                style: TextStyle(
                                  color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedType == TransactionType.expense ? '-' : '+'}\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedType == TransactionType.expense ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Date: ${_formatDisplayDate(_selectedDate)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C77CF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '💾 Update Transaction',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateTransaction() {
    if (_formKey.currentState!.validate()) {
      final updatedTransaction = widget.transaction.copyWith(
        amount: double.parse(_amountController.text),
        description: _descriptionController.text,
        type: _selectedType,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
        date: _selectedDate,
      );
      
      widget.onUpdateTransaction(updatedTransaction);
      Navigator.pop(context);
    }
  }
}