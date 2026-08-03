import 'package:flutter/material.dart';

import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'models.dart';
import 'nutrients.dart';
import 'theme.dart';
import 'user_targets.dart';

class CreateFoodPage extends StatefulWidget {
  /// When set, the page edits this food (PATCH) instead of creating a new one.
  final CustomFood? existing;

  const CreateFoodPage({super.key, this.existing});

  @override
  State<CreateFoodPage> createState() => _CreateFoodPageState();
}

class _CreateFoodPageState extends State<CreateFoodPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _portionController;
  late final TextEditingController _defaultPortionController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _kcalController;
  final Map<String, TextEditingController> _nutrientControllers = {};

  bool _saving = false;
  String? _submitError;
  bool _showMoreNutrients = false;
  UserTargets _targets = UserTargets.defaults;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    UserTargetsStore().load().then((t) {
      if (!mounted) return;
      setState(() => _targets = t);
    });
    final prefill = widget.existing;
    _nameController = TextEditingController(text: prefill?.name ?? '');
    _portionController = TextEditingController(text: (prefill?.portionGrams ?? 100).round().toString());
    _defaultPortionController = TextEditingController(
      text: prefill?.defaultPortionGrams != null ? _fmt(prefill!.defaultPortionGrams!) : '',
    );
    _proteinController = TextEditingController(text: prefill != null ? _fmt(prefill.proteinG) : '');
    _carbsController = TextEditingController(text: prefill != null ? _fmt(prefill.carbsG) : '');
    _fatController = TextEditingController(text: prefill != null ? _fmt(prefill.fatG) : '');
    _kcalController = TextEditingController(text: prefill != null ? _fmt(prefill.kcal) : '');

    for (final def in nutrientCatalog) {
      final value = prefill?.nutrients[def.key];
      _nutrientControllers[def.key] = TextEditingController(
        text: (value != null && value != 0) ? _fmt(value) : '',
      );
    }

    // Live-update the % of daily target bars as the user types.
    for (final controller in [
      _proteinController,
      _carbsController,
      _fatController,
      _kcalController,
      ..._nutrientControllers.values,
    ]) {
      controller.addListener(_onValueChanged);
    }

    // Existing food already has an explicit kcal value someone chose —
    // don't silently overwrite it just because they open it for editing.
    _kcalManuallyEdited = prefill != null;
    _proteinController.addListener(_maybeAutoFillKcal);
    _carbsController.addListener(_maybeAutoFillKcal);
    _fatController.addListener(_maybeAutoFillKcal);
    _kcalController.addListener(_markKcalManuallyEdited);
  }

  void _onValueChanged() => setState(() {});

  bool _kcalManuallyEdited = false;
  bool _settingKcalProgrammatically = false;

  void _markKcalManuallyEdited() {
    if (_settingKcalProgrammatically) return;
    _kcalManuallyEdited = true;
  }

  /// Fills in calories from protein/carbs/fat (4/4/9 kcal per gram) once all
  /// three are valid numbers — unless the user has typed their own kcal
  /// value, in which case their number wins until they clear it.
  void _maybeAutoFillKcal() {
    if (_kcalController.text.trim().isEmpty) _kcalManuallyEdited = false;
    if (_kcalManuallyEdited) return;

    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    if (protein == null || carbs == null || fat == null) return;

    _settingKcalProgrammatically = true;
    _kcalController.text = _fmt(protein * 4 + carbs * 4 + fat * 9);
    _settingKcalProgrammatically = false;
  }

  bool get _canRevertToUsda {
    final food = widget.existing;
    return food != null && food.source == 'usda' && food.originalKcal != null;
  }

  void _revertToUsda() {
    final food = widget.existing!;
    setState(() {
      _proteinController.text = _fmt(food.originalProteinG!);
      _carbsController.text = _fmt(food.originalCarbsG!);
      _fatController.text = _fmt(food.originalFatG!);
      _kcalController.text = _fmt(food.originalKcal!);
    });
  }

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

  double _read(TextEditingController controller) => double.tryParse(controller.text) ?? 0;

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _defaultPortionController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _kcalController.dispose();
    for (final controller in _nutrientControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _requiredNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final n = double.tryParse(value);
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  String? _optionalPositiveNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final n = double.tryParse(value);
    if (n == null || n <= 0) return 'Enter a valid number';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _submitError = null;
    });

    final nutrients = {
      for (final def in nutrientCatalog) def.key: _read(_nutrientControllers[def.key]!),
    };
    final defaultPortionGrams = double.tryParse(_defaultPortionController.text);

    try {
      final CustomFood food;
      final store = CustomFoodsStore();
      if (_isEditing) {
        food = await store.update(
          widget.existing!.id,
          name: _nameController.text.trim(),
          portionGrams: double.parse(_portionController.text),
          proteinG: double.parse(_proteinController.text),
          carbsG: double.parse(_carbsController.text),
          fatG: double.parse(_fatController.text),
          kcal: double.parse(_kcalController.text),
          nutrients: nutrients,
          defaultPortionGrams: defaultPortionGrams,
        );
      } else {
        food = await store.create(
          name: _nameController.text.trim(),
          source: 'custom',
          portionGrams: double.parse(_portionController.text),
          proteinG: double.parse(_proteinController.text),
          carbsG: double.parse(_carbsController.text),
          fatG: double.parse(_fatController.text),
          kcal: double.parse(_kcalController.text),
          nutrients: nutrients,
          defaultPortionGrams: defaultPortionGrams,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, food);
    } catch (e) {
      setState(() {
        _saving = false;
        _submitError = 'Could not save custom food.';
      });
    }
  }

  InputDecoration _fieldDecoration(String label, {Widget? prefixIcon, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 9),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
  }

  Widget _dot(Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }

  Widget _sectionLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 5),
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

  Widget _card(List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            fields[i],
          ],
        ],
      ),
    );
  }

  static const _numberStyle = TextStyle(fontSize: 13);

  /// Thin horizontal bar showing [value] as a percentage of [target],
  /// capped at 999%.
  Widget _percentBar(double value, double target, Color color) {
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0, 1).toDouble();
    final rawPct = target <= 0 ? 0 : (value / target * 100).round();
    final pctLabel = '${rawPct > 999 ? 999 : rawPct}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              pctLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// A macro field (kcal/protein/carbs/fat) with its "% of daily target" bar
  /// underneath, so the target-based bars all share one look. The suffix
  /// reads as "typed value/target unit", e.g. "10/900mcg".
  Widget _macroFieldWithBar({
    required TextEditingController controller,
    required String label,
    required Widget prefixIcon,
    required String unit,
    required double target,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _numberStyle,
            decoration: _fieldDecoration(
              label,
              prefixIcon: prefixIcon,
              suffixText: '/${_fmt(target)}$unit',
            ),
            validator: _requiredNumber,
          ),
          _percentBar(_read(controller), target, color),
        ],
      ),
    );
  }

  static const _nutrientNumberStyle = TextStyle(fontSize: 12);

  InputDecoration _nutrientFieldDecoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
  }

  Widget _nutrientPercentBar(double value, double target) {
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0, 1).toDouble();
    final rawPct = target <= 0 ? 0 : (value / target * 100).round();
    final pctLabel = '${rawPct > 999 ? 999 : rawPct}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 3,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              pctLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutrientFieldWithBar(NutrientDef def) {
    final controller = _nutrientControllers[def.key]!;
    final rdi = def.rdi;
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _nutrientNumberStyle,
            decoration: _nutrientFieldDecoration(
              def.label,
              suffixText: rdi != null ? '/${_fmt(rdi)}${def.unit}' : def.unit,
            ),
          ),
          if (rdi != null) _nutrientPercentBar(_read(controller), rdi),
        ],
      ),
    );
  }

  Widget _nutrientSection(NutrientGroup group, IconData icon) {
    final defs = nutrientCatalog.where((d) => d.group == group).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(icon, nutrientGroupLabels[group]!),
          _card([for (final def in defs) _nutrientFieldWithBar(def)]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Custom Food' : 'Create Custom Food')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: FoodAvatar(size: 64)),
            const SizedBox(height: 16),
            _sectionLabel(Icons.info_outline, 'DETAILS'),
            _card([
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration('Name', prefixIcon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted)),
                style: const TextStyle(fontWeight: FontWeight.w600),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _portionController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: _numberStyle,
                decoration: _fieldDecoration(
                  'Reference portion',
                  prefixIcon: const Icon(Icons.scale_outlined, size: 18, color: AppColors.textMuted),
                  suffixText: 'g',
                ),
                validator: _requiredNumber,
              ),
              TextFormField(
                controller: _defaultPortionController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: _numberStyle,
                decoration: _fieldDecoration(
                  'Default portion (optional)',
                  prefixIcon: const Icon(Icons.local_dining_outlined, size: 18, color: AppColors.textMuted),
                  suffixText: 'g',
                ),
                validator: _optionalPositiveNumber,
              ),
            ]),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text(
                'e.g. "1 slice = 30g" — lets you log this food by number of portions instead of grams.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            if (_canRevertToUsda)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _revertToUsda,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Revert to USDA Data'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            _sectionLabel(Icons.pie_chart_outline_rounded, 'MACROS FOR THAT PORTION'),
            _card([
              _macroFieldWithBar(
                controller: _kcalController,
                label: 'Calories',
                prefixIcon: const Icon(Icons.local_fire_department, color: AppColors.accent, size: 20),
                unit: 'kcal',
                target: _targets.calories,
                color: AppColors.accent,
              ),
              _macroFieldWithBar(
                controller: _proteinController,
                label: 'Protein',
                prefixIcon: _dot(AppColors.protein),
                unit: 'g',
                target: _targets.proteinG,
                color: AppColors.protein,
              ),
              _macroFieldWithBar(
                controller: _carbsController,
                label: 'Carbs',
                prefixIcon: _dot(AppColors.carbs),
                unit: 'g',
                target: _targets.carbsG,
                color: AppColors.carbs,
              ),
              _macroFieldWithBar(
                controller: _fatController,
                label: 'Fat',
                prefixIcon: _dot(AppColors.fat),
                unit: 'g',
                target: _targets.fatG,
                color: AppColors.fat,
              ),
            ]),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _showMoreNutrients = !_showMoreNutrients),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showMoreNutrients ? 'Hide More Nutrients' : 'Show More Nutrients',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _showMoreNutrients ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showMoreNutrients) ...[
              _nutrientSection(NutrientGroup.vitamins, Icons.wb_sunny_outlined),
              _nutrientSection(NutrientGroup.minerals, Icons.diamond_outlined),
              _nutrientSection(NutrientGroup.aminoAcids, Icons.hexagon_outlined),
              _nutrientSection(NutrientGroup.fats, Icons.opacity_outlined),
              _nutrientSection(NutrientGroup.other, Icons.info_outline),
            ],
            if (_submitError != null) ...[
              const SizedBox(height: 16),
              Text(_submitError!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
