import 'package:flutter/material.dart';

import 'add_food_page.dart';
import 'app_drawer.dart';
import 'barcode_scan_page.dart';
import 'create_food_page.dart';
import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'meal_template_page.dart';
import 'meal_templates_store.dart';
import 'models.dart';
import 'theme.dart';

class CustomFoodsPage extends StatefulWidget {
  const CustomFoodsPage({super.key});

  @override
  State<CustomFoodsPage> createState() => _CustomFoodsPageState();
}

class _CustomFoodsPageState extends State<CustomFoodsPage> with SingleTickerProviderStateMixin {
  final CustomFoodsStore _store = CustomFoodsStore();
  final MealTemplatesStore _templatesStore = MealTemplatesStore();
  late final TabController _tabController;
  List<CustomFood> _foods = [];
  List<MealTemplate> _templates = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final foods = await _store.loadAll();
      final templates = await _templatesStore.loadAll();
      setState(() {
        _foods = foods;
        _templates = templates;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load custom foods.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(CustomFood food) async {
    final updated = await _store.update(food.id, isFavorite: !food.isFavorite);
    if (!mounted) return;
    setState(() {
      final index = _foods.indexWhere((f) => f.id == food.id);
      if (index != -1) _foods[index] = updated;
    });
  }

  Future<void> _edit(CustomFood food) async {
    if (food.source == 'scanned') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit scanned item?'),
          content: Text(
            '"${food.name}" came from a barcode scan. Editing it will change the saved values away '
            'from what was on the label. If you want the original data back later, just re-scan the '
            'same barcode and choose "Reset to Scanned Data".',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Edit Anyway')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (food.source == 'usda') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit USDA food?'),
          content: Text(
            '"${food.name}" came from the USDA database. Editing it will change the saved values away '
            'from the USDA data. If you want the original data back later, open it for editing again and '
            'use "Revert to USDA Data".',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Edit Anyway')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final updated = await Navigator.push<CustomFood>(
      context,
      MaterialPageRoute(builder: (context) => CreateFoodPage(existing: food)),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final index = _foods.indexWhere((f) => f.id == updated.id);
      if (index != -1) _foods[index] = updated;
    });
  }

  Future<void> _create() async {
    final food = await Navigator.push<CustomFood>(
      context,
      MaterialPageRoute(builder: (context) => const CreateFoodPage()),
    );
    if (food == null || !mounted) return;
    setState(() => _foods.add(food));
  }

  Future<void> _scanBarcode() async {
    final food = await Navigator.push<CustomFood>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScanPage()),
    );
    if (food == null || !mounted) return;
    setState(() => _foods.add(food));
  }

  Future<void> _delete(CustomFood food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('This removes "${food.name}" from your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _store.delete(food.id);
      if (!mounted) return;
      setState(() => _foods.removeWhere((f) => f.id == food.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete food')),
      );
    }
  }

  Future<void> _createTemplate() async {
    final template = await Navigator.push<MealTemplate>(
      context,
      MaterialPageRoute(builder: (context) => const MealTemplatePage()),
    );
    if (template == null || !mounted) return;
    setState(() => _templates.add(template));
  }

  Future<void> _editTemplate(MealTemplate template) async {
    final updated = await Navigator.push<MealTemplate>(
      context,
      MaterialPageRoute(builder: (context) => MealTemplatePage(existing: template)),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final index = _templates.indexWhere((t) => t.id == updated.id);
      if (index != -1) _templates[index] = updated;
    });
  }

  Future<void> _deleteTemplate(MealTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal template?'),
        content: Text('This removes "${template.name}" from your saved meals.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _templatesStore.delete(template.id);
      if (!mounted) return;
      setState(() => _templates.removeWhere((t) => t.id == template.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete meal template')),
      );
    }
  }

  List<CustomFood> _matchingFoods(Iterable<CustomFood> foods) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return foods.toList();
    return foods.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  List<MealTemplate> _matchingTemplates(Iterable<MealTemplate> templates) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return templates.toList();
    return templates.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Foods'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Favourites'),
            Tab(text: 'Scanned'),
            Tab(text: 'Meals'),
          ],
        ),
      ),
      drawer: const AppDrawer(current: AppSection.customFoods),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ActionTile(icon: Icons.qr_code_scanner, label: 'Scan Barcode', onTap: _scanBarcode),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(icon: Icons.add, label: 'Create Food', onTap: _create),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionTile(icon: Icons.restaurant_menu, label: 'New Meal', onTap: _createTemplate),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search foods and meals...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBody(_matchingFoods(_foods), 'No custom foods yet'),
                  _buildBody(_matchingFoods(_foods.where((f) => f.isFavorite)), 'No favourites yet'),
                  _buildBody(_matchingFoods(_foods.where((f) => f.source == 'scanned')), 'No scanned foods yet'),
                  _buildTemplatesBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<CustomFood> foods, String emptyMessage) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (foods.isEmpty) {
      return Center(
        child: Text(
          _query.trim().isEmpty ? emptyMessage : 'No matches for "${_query.trim()}"',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: foods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final food = foods[index];
        return CustomFoodTile(
          food: food,
          onToggleFavorite: () => _toggleFavorite(food),
          onEdit: () => _edit(food),
          onDelete: () => _delete(food),
        );
      },
    );
  }

  Widget _buildTemplatesBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final templates = _matchingTemplates(_templates);
    if (templates.isEmpty) {
      return Center(
        child: Text(
          _query.trim().isEmpty ? 'No saved meals yet' : 'No matches for "${_query.trim()}"',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final template = templates[index];
        return MealTemplateTile(
          template: template,
          onEdit: () => _editTemplate(template),
          onDelete: () => _deleteTemplate(template),
        );
      },
    );
  }
}

class CustomFoodTile extends StatelessWidget {
  final CustomFood food;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomFoodTile({
    super.key,
    required this.food,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isScanned = food.source == 'scanned';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const FoodAvatar(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              food.isFavorite ? Icons.star : Icons.star_border,
              color: food.isFavorite ? Colors.amber : AppColors.textMuted,
            ),
            onPressed: onToggleFavorite,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isScanned) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.qr_code, size: 14, color: AppColors.textMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${food.kcal.round()} kcal / ${food.portionGrams.round()} · '
                  '${food.proteinG.round()}g P  ${food.carbsG.round()}g C  ${food.fatG.round()}g F',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
        ],
      ),
    );
  }
}

class MealTemplateTile extends StatelessWidget {
  final MealTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MealTemplateTile({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.meal,
            child: Icon(Icons.restaurant_menu, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${template.items.length} item${template.items.length == 1 ? '' : 's'} · '
                  '${template.kcalTotal.round()} kcal · '
                  '${template.proteinTotal.round()}g P  ${template.carbsTotal.round()}g C  ${template.fatTotal.round()}g F',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
        ],
      ),
    );
  }
}
