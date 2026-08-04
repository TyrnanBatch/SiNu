import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_drawer.dart';
import 'nutrition_calc.dart';
import 'theme.dart';
import 'user_profile.dart';
import 'user_targets.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  final UserTargetsStore _store = UserTargetsStore();
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _stepsController;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController()..addListener(_onChanged);
    _proteinController = TextEditingController()..addListener(_onChanged);
    _carbsController = TextEditingController()..addListener(_onChanged);
    _fatController = TextEditingController()..addListener(_onChanged);
    _stepsController = TextEditingController()..addListener(_onChanged);
    _load();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    final targets = await _store.load();
    if (!mounted) return;
    _applyTargets(targets);
    _stepsController.text = _fmt(targets.stepsGoal);
    setState(() => _loading = false);
  }

  void _applyTargets(UserTargets targets) {
    _caloriesController.text = _fmt(targets.calories);
    _proteinController.text = _fmt(targets.proteinG);
    _carbsController.text = _fmt(targets.carbsG);
    _fatController.text = _fmt(targets.fatG);
  }

  String _fmt(double n) => n.round().toString();

  double _read(TextEditingController controller) => double.tryParse(controller.text) ?? 0;

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _store.save(
      UserTargets(
        calories: _read(_caloriesController),
        proteinG: _read(_proteinController),
        carbsG: _read(_carbsController),
        fatG: _read(_fatController),
        stepsGoal: _read(_stepsController),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Targets saved')),
    );
  }

  Future<void> _getRecommendations() async {
    final profile = await UserProfileStore().load();
    if (!mounted) return;
    final result = await showModalBottomSheet<RecommendationInput>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RecommendationSheet(initialSteps: _read(_stepsController).round(), initialProfile: profile),
    );
    if (result == null || !mounted) return;
    _applyTargets(computeRecommendation(result));
    _stepsController.text = _fmt(result.dailySteps.toDouble());
    setState(() {});

    await UserProfileStore().save(
      UserProfile(sex: result.sex, heightCm: result.heightCm, weightKg: result.weightKg, age: result.age),
    );
  }

  InputDecoration _fieldDecoration(String label, {Widget? prefixIcon, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
            if (i > 0) Divider(height: 1, color: AppColors.border),
            fields[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final protein = _read(_proteinController);
    final carbs = _read(_carbsController);
    final fat = _read(_fatController);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition & Steps')),
      drawer: const AppDrawer(current: AppSection.nutrition),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card([
                  TextFormField(
                    controller: _caloriesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration(
                      'Calories',
                      prefixIcon: const Icon(Icons.local_fire_department, color: AppColors.accent, size: 20),
                      suffixText: 'kcal',
                    ),
                  ),
                  TextFormField(
                    controller: _proteinController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Protein', prefixIcon: _dot(AppColors.protein), suffixText: 'g'),
                  ),
                  TextFormField(
                    controller: _carbsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Carbs', prefixIcon: _dot(AppColors.carbs), suffixText: 'g'),
                  ),
                  TextFormField(
                    controller: _fatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Fat', prefixIcon: _dot(AppColors.fat), suffixText: 'g'),
                  ),
                ]),
                const SizedBox(height: 16),
                _card([
                  TextFormField(
                    controller: _stepsController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      'Daily Steps Goal',
                      prefixIcon: const Icon(Icons.directions_walk, color: AppColors.steps, size: 20),
                      suffixText: 'steps',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _getRecommendations,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Get Recommendations'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.donut_large_outlined, size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'CALORIES FROM MACROS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      MacroRing(protein: protein, carbs: carbs, fat: fat),
                      const SizedBox(height: 16),
                      _MacroLegendRow(label: 'Protein', grams: protein, kcalPerGram: 4, color: AppColors.protein),
                      const SizedBox(height: 8),
                      _MacroLegendRow(label: 'Carbs', grams: carbs, kcalPerGram: 4, color: AppColors.carbs),
                      const SizedBox(height: 8),
                      _MacroLegendRow(label: 'Fat', grams: fat, kcalPerGram: 9, color: AppColors.fat),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
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
              ],
            ),
    );
  }
}

class _MacroLegendRow extends StatelessWidget {
  final String label;
  final double grams;
  final double kcalPerGram;
  final Color color;

  const _MacroLegendRow({
    required this.label,
    required this.grams,
    required this.kcalPerGram,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = grams * kcalPerGram;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
        Text('${grams.round()}g', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            '${kcal.round()} kcal',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A ring (donut) chart showing how the day's calories split between
/// protein, carbs and fat.
class MacroRing extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const MacroRing({super.key, required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    final proteinKcal = protein * 4;
    final carbsKcal = carbs * 4;
    final fatKcal = fat * 9;
    final total = proteinKcal + carbsKcal + fatKcal;

    // Segment sizes are proportioned by grams, not calories, so fat (9
    // kcal/g) doesn't visually dominate despite usually having fewer grams.
    final gramsTotal = protein + carbs + fat;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _MacroRingPainter(
              segments: gramsTotal <= 0
                  ? []
                  : [
                      _RingSegment(protein / gramsTotal, AppColors.protein),
                      _RingSegment(carbs / gramsTotal, AppColors.carbs),
                      _RingSegment(fat / gramsTotal, AppColors.fat),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${total.round()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text('kcal/day', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingSegment {
  final double fraction;
  final Color color;
  const _RingSegment(this.fraction, this.color);
}

class _MacroRingPainter extends CustomPainter {
  final List<_RingSegment> segments;

  _MacroRingPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = 16.0;
    final inset = strokeWidth / 2;
    final arcRect = rect.deflate(inset);

    final track = Paint()
      ..color = AppColors.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);

    const gap = 0.035; // radians between segments
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = (segment.fraction * 2 * math.pi - gap).clamp(0, 2 * math.pi).toDouble();
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      start += segment.fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) => oldDelegate.segments != segments;
}

class _RecommendationSheet extends StatefulWidget {
  final int initialSteps;
  final UserProfile? initialProfile;

  const _RecommendationSheet({required this.initialSteps, this.initialProfile});

  @override
  State<_RecommendationSheet> createState() => _RecommendationSheetState();
}

class _RecommendationSheetState extends State<_RecommendationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _heightController = TextEditingController(
    text: widget.initialProfile != null ? _fmt(widget.initialProfile!.heightCm) : '',
  );
  late final _weightController = TextEditingController(
    text: widget.initialProfile != null ? _fmt(widget.initialProfile!.weightKg) : '',
  );
  late final _ageController = TextEditingController(
    text: widget.initialProfile != null ? '${widget.initialProfile!.age}' : '',
  );
  late final _stepsController = TextEditingController(text: '${widget.initialSteps}');
  late BiologicalSex _sex = widget.initialProfile?.sex ?? BiologicalSex.male;
  FitnessGoal _goal = FitnessGoal.maintain;

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  String? _requiredNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final n = double.tryParse(value);
    if (n == null || n <= 0) return 'Enter a valid number';
    return null;
  }

  String? _requiredSteps(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RecommendationInput(
        sex: _sex,
        heightCm: double.parse(_heightController.text),
        weightKg: double.parse(_weightController.text),
        age: int.parse(_ageController.text),
        dailySteps: int.parse(_stepsController.text),
        goal: _goal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Get Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<BiologicalSex>(
                segments: const [
                  ButtonSegment(value: BiologicalSex.male, label: Text('Male')),
                  ButtonSegment(value: BiologicalSex.female, label: Text('Female')),
                ],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm', border: OutlineInputBorder()),
                validator: _requiredNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg', border: OutlineInputBorder()),
                validator: _requiredNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age', suffixText: 'years', border: OutlineInputBorder()),
                validator: _requiredNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Average Daily Steps',
                  suffixText: 'steps',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredSteps,
              ),
              const SizedBox(height: 16),
              Text('Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              RadioGroup<FitnessGoal>(
                groupValue: _goal,
                onChanged: (v) => setState(() => _goal = v!),
                child: Column(
                  children: FitnessGoal.values
                      .map(
                        (g) => RadioListTile<FitnessGoal>(
                          value: g,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(g.label, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(g.description, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Calculate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
