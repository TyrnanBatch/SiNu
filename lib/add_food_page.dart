import 'dart:async';

import 'package:flutter/material.dart';

import 'amount_sheet.dart';
import 'barcode_scan_page.dart';
import 'create_food_page.dart';
import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'models.dart';
import 'theme.dart';
import 'usda_client.dart';

class AddFoodPage extends StatefulWidget {
  final List<CustomFood> foods;

  const AddFoodPage({super.key, required this.foods});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final CustomFoodsStore _store = CustomFoodsStore();
  final UsdaFoodsClient _usda = UsdaFoodsClient();

  String _query = '';
  late List<CustomFood> _foods;

  Timer? _usdaDebounce;
  List<UsdaFoodResult> _usdaResults = [];
  bool _usdaLoading = false;
  String? _usdaError;

  @override
  void initState() {
    super.initState();
    _foods = List.of(widget.foods);
  }

  @override
  void dispose() {
    _usdaDebounce?.cancel();
    super.dispose();
  }

  List<CustomFood> get _filtered {
    if (_query.isEmpty) return _foods;
    final q = _query.toLowerCase();
    return _foods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);

    _usdaDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
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
    final grams = await AmountSheet.show(context, title: food.name, initialGrams: food.portionGrams);
    if (grams == null || !mounted) return;
    Navigator.pop(context, LoggedItem.fromCustomFood(food, grams));
  }

  Future<void> _selectUsdaFood(UsdaFoodResult result) async {
    final grams = await AmountSheet.show(context, title: result.description, initialGrams: 100);
    if (grams == null || !mounted) return;

    final food = await _store.create(
      name: result.description,
      source: 'usda',
      portionGrams: 100,
      proteinG: result.proteinG,
      carbsG: result.carbsG,
      fatG: result.fatG,
      kcal: result.kcal,
    );
    if (!mounted) return;
    setState(() => _foods.add(food));
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildResults() {
    final query = _query.trim();

    if (query.isEmpty) {
      if (_filtered.isEmpty) {
        return const Center(child: Text('No foods found', style: TextStyle(color: Colors.white38)));
      }
      return ListView.separated(
        itemCount: _filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final food = _filtered[index];
          return FoodListTile(food: food, onTap: () => _selectFood(food));
        },
      );
    }

    return ListView(
      children: [
        if (_filtered.isNotEmpty) ...[
          _sectionLabel('YOUR FOODS'),
          for (final food in _filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FoodListTile(food: food, onTap: () => _selectFood(food)),
            ),
          const SizedBox(height: 16),
        ],
        _sectionLabel('COMMON FOODS (USDA)'),
        const SizedBox(height: 4),
        if (_usdaLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_usdaError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_usdaError!, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else if (_usdaResults.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No common foods found', style: TextStyle(color: Colors.white38, fontSize: 13)),
          )
        else
          for (final result in _usdaResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UsdaFoodListTile(result: result, onTap: () => _selectUsdaFood(result)),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Food')),
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
                  const Icon(Icons.search, size: 20, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      onChanged: _onQueryChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search foods...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
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
            const SizedBox(height: 16),
            Expanded(child: _buildResults()),
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
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                          child: const Text(
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
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
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
