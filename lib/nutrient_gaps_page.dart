import 'package:flutter/material.dart';

import 'custom_foods_store.dart';
import 'nutrients.dart';
import 'rdi_overrides_store.dart';
import 'storage.dart';
import 'theme.dart';

/// Aggregates actual micronutrient intake from logged meal history and
/// flags what's chronically under its reference daily intake — the
/// per-food nutrient data (nutrients.dart) is captured on every custom
/// food but was otherwise never surfaced anywhere after the create/edit
/// form. Averages are computed only over days that were actually logged,
/// so unlogged days don't dilute the numbers.
class NutrientGapsPage extends StatefulWidget {
  const NutrientGapsPage({super.key});

  @override
  State<NutrientGapsPage> createState() => _NutrientGapsPageState();
}

class _NutrientGapsPageState extends State<NutrientGapsPage> {
  static const _periods = [7, 14, 28];
  int _periodDays = 7;
  bool _loading = true;

  Map<String, double> _avgIntake = {};
  Set<String> _trackedKeys = {};
  Map<String, double> _rdiOverrides = {};
  int _daysWithData = 0;

  @override
  void initState() {
    super.initState();
    RdiOverridesStore().load().then((overrides) {
      if (!mounted) return;
      setState(() => _rdiOverrides = overrides);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final foods = await CustomFoodsStore().loadAll();
    final foodsById = {for (final f in foods) f.id: f};
    final storage = MealsStorage();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final totals = <String, double>{};
    final tracked = <String>{};
    var daysWithData = 0;

    for (var i = 0; i < _periodDays; i++) {
      final date = today.subtract(Duration(days: i));
      final meals = await storage.loadMeals(date);
      if (meals == null || meals.isEmpty) continue;
      daysWithData++;

      for (final meal in meals) {
        for (final item in meal.items) {
          final food = item.foodId == null ? null : foodsById[item.foodId];
          if (food == null || food.portionGrams <= 0) continue;
          final scale = item.grams / food.portionGrams;
          for (final entry in food.nutrients.entries) {
            if (entry.value == 0) continue;
            tracked.add(entry.key);
            totals[entry.key] = (totals[entry.key] ?? 0) + entry.value * scale;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _avgIntake = {
        for (final key in totals.keys) key: totals[key]! / (daysWithData == 0 ? 1 : daysWithData),
      };
      _trackedKeys = tracked;
      _daysWithData = daysWithData;
      _loading = false;
    });
  }

  Widget _sectionLabel(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: color),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            children[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defs = nutrientCatalog.where((d) => effectiveRdi(d, _rdiOverrides) != null).toList();
    final needsAttention = <NutrientDef>[];
    final onTarget = <NutrientDef>[];
    final notTracked = <NutrientDef>[];

    for (final def in defs) {
      if (!_trackedKeys.contains(def.key)) {
        notTracked.add(def);
        continue;
      }
      final avg = _avgIntake[def.key] ?? 0;
      final pct = avg / effectiveRdi(def, _rdiOverrides)! * 100;
      (pct < 90 ? needsAttention : onTarget).add(def);
    }
    needsAttention.sort(
      (a, b) => (_avgIntake[a.key]! / effectiveRdi(a, _rdiOverrides)!).compareTo(_avgIntake[b.key]! / effectiveRdi(b, _rdiOverrides)!),
    );
    onTarget.sort(
      (a, b) => (_avgIntake[a.key]! / effectiveRdi(a, _rdiOverrides)!).compareTo(_avgIntake[b.key]! / effectiveRdi(b, _rdiOverrides)!),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrient Gaps')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: SegmentedButton<int>(
                    segments: _periods.map((p) => ButtonSegment(value: p, label: Text('${p}d'))).toList(),
                    selected: {_periodDays},
                    onSelectionChanged: (s) {
                      setState(() => _periodDays = s.first);
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Based on $_daysWithData logged day${_daysWithData == 1 ? '' : 's'} of the last $_periodDays',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                if (_daysWithData == 0)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('Log some meals to see nutrient gaps', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else ...[
                  if (needsAttention.isNotEmpty) ...[
                    _sectionLabel(Icons.warning_amber_rounded, 'NEEDS ATTENTION', Colors.amber),
                    _card([
                      for (final def in needsAttention)
                        _NutrientGapRow(def: def, avg: _avgIntake[def.key]!, rdi: effectiveRdi(def, _rdiOverrides)!),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  if (onTarget.isNotEmpty) ...[
                    _sectionLabel(Icons.check_circle_outline, 'ON TARGET', AppColors.accent),
                    _card([
                      for (final def in onTarget)
                        _NutrientGapRow(def: def, avg: _avgIntake[def.key]!, rdi: effectiveRdi(def, _rdiOverrides)!),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  if (notTracked.isNotEmpty) ...[
                    _sectionLabel(Icons.help_outline, 'NOT TRACKED', AppColors.textMuted),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, left: 4),
                      child: Text(
                        'None of your logged foods have data for these — fill them in on the food editor to see gaps here.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final def in notTracked)
                          Chip(
                            label: Text(def.label, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.card,
                            side: BorderSide(color: AppColors.border),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _NutrientGapRow extends StatelessWidget {
  final NutrientDef def;
  final double avg;
  final double rdi;

  const _NutrientGapRow({required this.def, required this.avg, required this.rdi});

  String _fmt(double n) => n >= 100 ? n.round().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final pct = (avg / rdi * 100).clamp(0, 999).toDouble();
    final color = pct >= 90
        ? AppColors.accent
        : (pct >= 50 ? Colors.amber : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(def.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text(
                '${_fmt(avg)}/${_fmt(rdi)} ${def.unit}',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  '${pct.round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
