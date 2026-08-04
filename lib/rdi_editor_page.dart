import 'package:flutter/material.dart';

import 'nutrients.dart';
import 'rdi_overrides_store.dart';
import 'theme.dart';

/// Lets the user override the built-in reference daily intakes (used for
/// the "% of daily value" bars on the food editor and the Nutrient Gaps
/// page), and pick specific overridden values to reset back to default.
class RdiEditorPage extends StatefulWidget {
  const RdiEditorPage({super.key});

  @override
  State<RdiEditorPage> createState() => _RdiEditorPageState();
}

class _RdiEditorPageState extends State<RdiEditorPage> {
  final _store = RdiOverridesStore();
  final Map<String, TextEditingController> _controllers = {};

  bool _loading = true;
  bool _saving = false;

  List<NutrientDef> get _editableDefs => nutrientCatalog.where((d) => d.rdi != null).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final overrides = await _store.load();
    if (!mounted) return;
    setState(() {
      for (final def in _editableDefs) {
        final value = overrides[def.key] ?? def.rdi!;
        _controllers[def.key] = TextEditingController(text: _fmt(value))..addListener(_onChanged);
      }
      _loading = false;
    });
  }

  void _onChanged() => setState(() {});

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isChanged(NutrientDef def) {
    final current = double.tryParse(_controllers[def.key]!.text);
    return current != null && current != def.rdi;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final overrides = <String, double>{};
    for (final def in _editableDefs) {
      final value = double.tryParse(_controllers[def.key]!.text);
      if (value != null && value > 0 && value != def.rdi) {
        overrides[def.key] = value;
      }
    }
    await _store.save(overrides);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RDIs saved')));
  }

  Future<void> _showResetDialog() async {
    final changed = _editableDefs.where(_isChanged).toList();
    if (changed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No RDIs have been changed')));
      return;
    }

    final selected = {for (final def in changed) def.key};
    final toReset = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset to Default'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final def in changed)
                  CheckboxListTile(
                    value: selected.contains(def.key),
                    title: Text(def.label),
                    subtitle: Text(
                      '${_fmt(double.tryParse(_controllers[def.key]!.text) ?? 0)} → ${_fmt(def.rdi!)} ${def.unit}',
                    ),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selected.add(def.key);
                      } else {
                        selected.remove(def.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Reset Selected'),
            ),
          ],
        ),
      ),
    );
    if (toReset == null || toReset.isEmpty || !mounted) return;

    setState(() {
      for (final key in toReset) {
        final def = _editableDefs.firstWhere((d) => d.key == key);
        _controllers[key]!.text = _fmt(def.rdi!);
      }
    });
    await _save();
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(NutrientGroup group) {
    final defs = _editableDefs.where((d) => d.group == group).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            _fieldRow(defs[i]),
          ],
        ],
      ),
    );
  }

  Widget _fieldRow(NutrientDef def) {
    final changed = _isChanged(def);
    return TextFormField(
      controller: _controllers[def.key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: def.label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        suffixText: def.unit,
        suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: changed
            ? Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(Icons.fiber_manual_record, size: 8, color: AppColors.accent),
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  static const _groups = [
    NutrientGroup.vitamins,
    NutrientGroup.minerals,
    NutrientGroup.aminoAcids,
    NutrientGroup.fats,
    NutrientGroup.other,
  ];

  static const _groupIcons = {
    NutrientGroup.vitamins: Icons.wb_sunny_outlined,
    NutrientGroup.minerals: Icons.diamond_outlined,
    NutrientGroup.aminoAcids: Icons.hexagon_outlined,
    NutrientGroup.fats: Icons.opacity_outlined,
    NutrientGroup.other: Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final anyChanged = _loading ? false : _editableDefs.any(_isChanged);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit RDIs'),
        actions: [
          TextButton(
            onPressed: anyChanged ? _showResetDialog : null,
            child: const Text('Reset to Default'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'These reference daily intakes drive the "% of daily value" bars on the food editor '
                  'and the Nutrient Gaps page. Changing one only affects how it\'s displayed — it doesn\'t '
                  'change any food\'s logged values.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                for (final group in _groups) ...[
                  _sectionLabel(_groupIcons[group]!, nutrientGroupLabels[group]!),
                  _groupCard(group),
                  const SizedBox(height: 20),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
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
    );
  }
}
