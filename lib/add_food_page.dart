import 'package:flutter/material.dart';

import 'amount_sheet.dart';
import 'barcode_scan_page.dart';
import 'create_food_page.dart';
import 'food_avatar.dart';
import 'models.dart';
import 'theme.dart';

class AddFoodPage extends StatefulWidget {
  final List<CustomFood> foods;

  const AddFoodPage({super.key, required this.foods});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  String _query = '';
  late List<CustomFood> _foods;

  @override
  void initState() {
    super.initState();
    _foods = List.of(widget.foods);
  }

  List<CustomFood> get _filtered {
    if (_query.isEmpty) return _foods;
    final q = _query.toLowerCase();
    return _foods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _selectFood(CustomFood food) async {
    final grams = await AmountSheet.show(context, title: food.name, initialGrams: food.portionGrams);
    if (grams == null || !mounted) return;
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
                      onChanged: (v) => setState(() => _query = v),
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
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('No foods found', style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final food = _filtered[index];
                        return FoodListTile(food: food, onTap: () => _selectFood(food));
                      },
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
