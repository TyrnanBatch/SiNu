import 'package:flutter/material.dart';

import 'add_food_page.dart';
import 'amount_sheet.dart';
import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'meal_templates_store.dart';
import 'models.dart';
import 'theme.dart';

/// Create/edit a saved meal template — a named, reusable set of food items.
/// When [existing] is set, edits that template (rename, add/remove foods,
/// change amounts) instead of creating a new one.
class MealTemplatePage extends StatefulWidget {
  final MealTemplate? existing;

  const MealTemplatePage({super.key, this.existing});

  @override
  State<MealTemplatePage> createState() => _MealTemplatePageState();
}

class _MealTemplatePageState extends State<MealTemplatePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late List<LoggedItem> _items;
  List<CustomFood> _foods = [];

  bool _saving = false;
  String? _submitError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _items = (widget.existing?.items ?? []).map((i) => i.copy()).toList();
    CustomFoodsStore().loadAll().then((foods) {
      if (!mounted) return;
      setState(() => _foods = foods);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addFood() async {
    final item = await Navigator.push<LoggedItem>(
      context,
      MaterialPageRoute(builder: (context) => AddFoodPage(foods: _foods)),
    );
    if (item == null || !mounted) return;
    setState(() => _items.add(item));
  }

  Future<void> _editItemAmount(LoggedItem item) async {
    CustomFood? food;
    for (final f in _foods) {
      if (f.id == item.foodId) {
        food = f;
        break;
      }
    }
    final grams = await AmountSheet.show(
      context,
      title: item.name,
      initialGrams: item.grams,
      submitLabel: 'Save',
      defaultPortionGrams: food?.defaultPortionGrams,
    );
    if (grams == null) return;
    setState(() => item.grams = grams);
  }

  void _removeItem(LoggedItem item) {
    setState(() => _items.remove(item));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _submitError = 'Add at least one food.');
      return;
    }

    setState(() {
      _saving = true;
      _submitError = null;
    });

    try {
      final store = MealTemplatesStore();
      final MealTemplate template;
      if (_isEditing) {
        template = await store.update(widget.existing!.id, name: _nameController.text.trim(), items: _items);
      } else {
        template = await store.create(name: _nameController.text.trim(), items: _items);
      }
      if (!mounted) return;
      Navigator.pop(context, template);
    } catch (e) {
      setState(() {
        _saving = false;
        _submitError = 'Could not save meal template.';
      });
    }
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(LoggedItem item) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const FoodAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _editItemAmount(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '${item.grams.round()}g · ${item.kcal.round()} kcal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white38),
            onPressed: () => _removeItem(item),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _items.fold(0.0, (s, i) => s + i.kcal);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Meal Template' : 'New Meal Template')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              style: const TextStyle(fontWeight: FontWeight.w600),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _sectionLabel(Icons.restaurant_menu, 'FOODS')),
                Text('${totalKcal.round()} kcal', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('No foods yet', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _itemTile(_items[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addFood,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Food'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
