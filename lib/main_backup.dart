class ExpenseTrackerHome extends StatefulWidget {
  const ExpenseTrackerHome({super.key, required this.title});

  final String title;

  @override
  State<ExpenseTrackerHome> createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome> {
  final List<Transaction> _transactions = [];
  final List<Category> _categories = [];
  final List<Account> _accounts = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _selectedAccountId = 'personal';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAccounts();
    await _loadCategories();
    await _loadTransactions();
    await _migrateExistingTransactions();
    setState(() {
      _isLoading = false;
    });
  }

  // FIXED: Spanish Categories with proper loading
  List<Category> _getDefaultCategories() {
    return [
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
        descriptions: ['Arriendo', 'Tc y Prestamos', 'Donaciones', 'Familia', 'Estudio Arriendo el Libertador'],
      ),
      Category(
        id: 'ocio',
        name: 'Ocio',
        icon: Icons.movie,
        color: Colors.purple,
        type: TransactionType.expense,
        descriptions: ['Restaurante', 'Cine', 'Helados', 'Streaming', 'Streaming, Wom y Tigo', 'Postobon'],
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
        descriptions: ['Wom', 'Tigo Hogar', 'Tigo Movil', 'Internet', 'Telefono'],
      ),
    ];
  }

  // Add all the loading, saving, and management methods here...
  // (I'll provide the key methods to fix the issues)

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getStringList('categories');
    
    _categories.clear();
    if (categoriesJson == null || categoriesJson.isEmpty) {
      // Force load Spanish categories
      _categories.addAll(_getDefaultCategories());
      await _saveCategories();
      print('✅ Spanish categories loaded successfully!');
    } else {
      for (String categoryString in categoriesJson) {
        try {
          final categoryMap = json.decode(categoryString);
          _categories.add(Category.fromJson(categoryMap));
        } catch (e) {
          print('Error loading category: $e');
        }
      }
      
      // Ensure we have the Spanish categories
      if (_categories.isEmpty) {
        _categories.addAll(_getDefaultCategories());
        await _saveCategories();
      }
    }
  }

  // ... (other methods remain the same)
}