import 'dart:async';

import 'package:flutter/material.dart';

import 'amount_sheet.dart';
import 'barcode_scan_page.dart';
import 'create_food_page.dart';
import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'usda_client.dart';

class AddFoodPage extends StatefulWidget {
  final List<CustomFood> foods;

  const AddFoodPage({super.key, required this.foods});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> with SingleTickerProviderStateMixin {
  static const _allTab = 0;
  static const _customTab = 1;
  static const _favouritesTab = 2;
  static const _scannedTab = 3;
  static const _commonTab = 4;

  final CustomFoodsStore _store = CustomFoodsStore();
  final UsdaFoodsClient _usda = UsdaFoodsClient();
  late final TabController _tabController;

  String _query = '';
  late List<CustomFood> _foods;

  Timer? _usdaDebounce;
  List<UsdaFoodResult> _usdaResults = [];
  bool _usdaLoading = false;
  String? _usdaError;

  List<CustomFood> _recentFoods = [];

  @override
  void initState() {
    super.initState();
    _foods = List.of(widget.foods);
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRecentFoods();
  }

  /// Most-recently-logged distinct foods, newest first — scans the last two
  /// weeks of meal history since there's no separate "usage" tracking to
  /// maintain just for this.
  Future<void> _loadRecentFoods() async {
    final storage = MealsStorage();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final foodsById = {for (final f in _foods) f.id: f};
    final seen = <int>{};
    final recent = <CustomFood>[];

    for (var i = 0; i < 14 && recent.length < 8; i++) {
      final meals = await storage.loadMeals(today.subtract(Duration(days: i)));
      if (meals == null) continue;
      for (final meal in meals.reversed) {
        for (final item in meal.items.reversed) {
          final food = item.foodId == null ? null : foodsById[item.foodId];
          if (food == null || !seen.add(food.id)) continue;
          recent.add(food);
          if (recent.length >= 8) break;
        }
        if (recent.length >= 8) break;
      }
    }

    if (!mounted) return;
    setState(() => _recentFoods = recent);
  }

  @override
  void dispose() {
    _usdaDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Only the All and Common Foods tabs search USDA — Favourites/Scanned
  /// are local-only, so there's no reason to hit the network for them.
  bool get _usdaTabActive => _tabController.index == _allTab || _tabController.index == _commonTab;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final query = _query.trim();
    if (_usdaTabActive && query.isNotEmpty && _usdaResults.isEmpty && !_usdaLoading && _usdaError == null) {
      _searchUsda(query);
    }
    setState(() {});
  }

  List<CustomFood> _localFoodsFor(int tabIndex) {
    Iterable<CustomFood> source = _foods;
    if (tabIndex == _customTab) source = source.where((f) => f.source == 'custom');
    if (tabIndex == _favouritesTab) source = source.where((f) => f.isFavorite);
    if (tabIndex == _scannedTab) source = source.where((f) => f.source == 'scanned');
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) source = source.where((f) => f.name.toLowerCase().contains(q));
    return source.toList();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);

    _usdaDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty || !_usdaTabActive) {
      setState(() {
        _usdaResults = [];
        _usdaLoading = false;
        _usdaError = null;
      });
      return;
    }

    setState(() => _usdaLoading = true);
    _usdaDebounce = Timer(const Duration(milliseconds: 400), () => _searchUsda(query));
  }

  Future<void> _searchUsda(String query) async {
    setState(() => _usdaLoading = true);
    try {
      final results = await _usda.search(query);
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _usdaResults = results;
        _usdaLoading = false;
        _usdaError = null;
      });
    } catch (e) {
      if (!mounted || query != _query.trim()) return;
      setState(() {
        _usdaLoading = false;
        _usdaError = 'Could not search common foods — check your connection.';
      });
    }
  }

  Future<void> _selectFood(CustomFood food) async {
    final grams = await AmountSheet.show(
      context,
      title: food.name,
      initialGrams: food.portionGrams,
      defaultPortionGrams: food.defaultPortionGrams,
    );
    if (grams == null || !mounted) return;
    Navigator.pop(context, LoggedItem.fromCustomFood(food, grams));
  }

  Future<void> _selectUsdaFood(UsdaFoodResult result) async {
    final grams = await AmountSheet.show(context, title: result.description, initialGrams: 100);
    if (grams == null || !mounted) return;

    // Re-picking the same USDA result shouldn't spawn a new library entry
    // every time — reuse the one already created for it, edits and all.
    CustomFood? food;
    for (final f in _foods) {
      if (f.source == 'usda' && f.name == result.description) {
        food = f;
        break;
      }
    }

    if (food == null) {
      food = await _store.create(
        name: result.description,
        source: 'usda',
        portionGrams: 100,
        proteinG: result.proteinG,
        carbsG: result.carbsG,
        fatG: result.fatG,
        kcal: result.kcal,
        originalProteinG: result.proteinG,
        originalCarbsG: result.carbsG,
        originalFatG: result.fatG,
        originalKcal: result.kcal,
      );
      if (!mounted) return;
      setState(() => _foods.add(food!));
    }
    Navigator.pop(context, LoggedItem.fromCustomFood(food, grams));
  }

  Future<void> _createFood() async {
    final food = await Navigator.push<CustomFood>(
      context,
      MaterialPageRoute(builder: (context) => const CreateFoodPage()),
    );
    if (food == null || !mounted) return;
    setState(() => _foods.add(food));
    await _selectFood(food);
  }

  Future<void> _scanBarcode() async {
    final food = await Navigator.push<CustomFood>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScanPage()),
    );
    if (food == null || !mounted) return;
    setState(() => _foods.add(food));
    await _selectFood(food);
  }

  /// Loading/error/empty/results states for a USDA results block — reused
  /// by both the All tab (appended after local matches) and the Common
  /// Foods tab (shown on its own).
  List<Widget> _usdaSectionChildren() {
    if (_usdaLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_usdaError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_usdaError!, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      ];
    }
    if (_usdaResults.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('No common foods found', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      ];
    }
    return [
      for (final result in _usdaResults)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: UsdaFoodListTile(result: result, onTap: () => _selectUsdaFood(result)),
        ),
    ];
  }

  /// All tab: local matches (any source) plus, while actively searching, a
  /// USDA section underneath.
  Widget _buildAllTab() {
    final foods = _localFoodsFor(_allTab);
    final query = _query.trim();

    if (query.isEmpty) {
      if (foods.isEmpty) {
        return Center(child: Text('No foods found', style: TextStyle(color: AppColors.textMuted)));
      }
      return ListView.separated(
        itemCount: foods.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => FoodListTile(food: foods[index], onTap: () => _selectFood(foods[index])),
      );
    }

    return ListView(
      children: [
        if (foods.isNotEmpty) ...[
          _sectionLabel('YOUR FOODS'),
          for (final food in foods)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FoodListTile(food: food, onTap: () => _selectFood(food)),
            ),
          const SizedBox(height: 16),
        ],
        _sectionLabel('COMMON FOODS (USDA)'),
        const SizedBox(height: 4),
        ..._usdaSectionChildren(),
      ],
    );
  }

  /// Favourites/Scanned tabs: local-only, no USDA section ever.
  Widget _buildLocalTab(int tabIndex, String emptyMessage) {
    final foods = _localFoodsFor(tabIndex);
    if (foods.isEmpty) {
      return Center(child: Text(emptyMessage, style: TextStyle(color: AppColors.textMuted)));
    }
    return ListView.separated(
      itemCount: foods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => FoodListTile(food: foods[index], onTap: () => _selectFood(foods[index])),
    );
  }

  /// Common Foods tab: USDA only, needs a query to search against.
  Widget _buildCommonFoodsTab() {
    if (_query.trim().isEmpty) {
      return Center(
        child: Text('Type to search common foods', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView(children: _usdaSectionChildren());
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Custom'),
            Tab(text: 'Favourites'),
            Tab(text: 'Scanned'),
            Tab(text: 'Common Foods'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search foods...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ActionTile(icon: Icons.qr_code_scanner, label: 'Scan Barcode', onTap: _scanBarcode),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(icon: Icons.add, label: 'Create Food', onTap: _createFood),
                ),
              ],
            ),
            if (_query.trim().isEmpty && _recentFoods.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionLabel('RECENTLY LOGGED'),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentFoods.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final food = _recentFoods[index];
                    return RecentFoodChip(food: food, onTap: () => _selectFood(food));
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(),
                  _buildLocalTab(_customTab, 'No custom foods yet'),
                  _buildLocalTab(_favouritesTab, 'No favourites yet'),
                  _buildLocalTab(_scannedTab, 'No scanned foods yet'),
                  _buildCommonFoodsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionTile({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.accent),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentFoodChip extends StatelessWidget {
  final CustomFood food;
  final VoidCallback onTap;

  const RecentFoodChip({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  food.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodListTile extends StatelessWidget {
  final CustomFood food;
  final VoidCallback onTap;

  const FoodListTile({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const FoodAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${food.kcal.round()} kcal / ${food.portionGrams.round()} · '
                      '${food.proteinG.round()}g P  ${food.carbsG.round()}g C  ${food.fatG.round()}g F',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class UsdaFoodListTile extends StatelessWidget {
  final UsdaFoodResult result;
  final VoidCallback onTap;

  const UsdaFoodListTile({super.key, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const FoodAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            result.description,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            'USDA',
                            style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.kcal.round()} kcal / 100 · '
                      '${result.proteinG.round()}g P  ${result.carbsG.round()}g C  ${result.fatG.round()}g F',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
