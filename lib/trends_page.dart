import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_drawer.dart';
import 'health_service.dart';
import 'models.dart';
import 'nutrient_gaps_page.dart';
import 'storage.dart';
import 'theme.dart';
import 'user_targets.dart';
import 'weight_store.dart';

class _DayTotals {
  final DateTime date;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final bool hasData;
  final int? steps;
  final double? weightKg;

  const _DayTotals({
    required this.date,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.hasData,
    this.steps,
    this.weightKg,
  });
}

/// Historical view over logged meals — a day-by-day calorie chart plus
/// period averages for calories and macros, so trends are visible instead
/// of only ever seeing one day at a time.
class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  static const _periods = [7, 14, 28];

  int _periodDays = 14;
  bool _loading = true;
  UserTargets _targets = UserTargets.defaults;
  List<_DayTotals> _days = [];

  final HealthService _health = HealthService();
  bool _stepsChecked = false;
  bool _stepsAuthorized = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (HealthService.isSupported) _initSteps();
  }

  Future<void> _initSteps() async {
    final granted = await _health.requestStepsPermission();
    if (!mounted) return;
    setState(() {
      _stepsChecked = true;
      _stepsAuthorized = granted;
    });
    if (granted) await _load();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final targets = await UserTargetsStore().load();
    final storage = MealsStorage();
    final weightStore = WeightStore();
    final today = _today;

    final days = <_DayTotals>[];
    for (var i = _periodDays - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final meals = await storage.loadMeals(date) ?? const <MealData>[];
      final steps = _stepsAuthorized ? await _health.stepsForDay(date) : null;
      final weightKg = await weightStore.loadWeight(date);
      days.add(
        _DayTotals(
          date: date,
          kcal: meals.fold(0.0, (s, m) => s + m.kcalTotal),
          protein: meals.fold(0.0, (s, m) => s + m.proteinTotal),
          carbs: meals.fold(0.0, (s, m) => s + m.carbsTotal),
          fat: meals.fold(0.0, (s, m) => s + m.fatTotal),
          hasData: meals.isNotEmpty,
          steps: steps,
          weightKg: weightKg,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _targets = targets;
      _days = days;
      _loading = false;
    });
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

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  String _shortLabel(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _periodDays <= 7 ? names[d.weekday - 1] : '${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final daysWithData = _days.where((d) => d.hasData).toList();
    final avgKcal = daysWithData.isEmpty ? 0.0 : daysWithData.fold(0.0, (s, d) => s + d.kcal) / daysWithData.length;
    final avgProtein = daysWithData.isEmpty ? 0.0 : daysWithData.fold(0.0, (s, d) => s + d.protein) / daysWithData.length;
    final avgCarbs = daysWithData.isEmpty ? 0.0 : daysWithData.fold(0.0, (s, d) => s + d.carbs) / daysWithData.length;
    final avgFat = daysWithData.isEmpty ? 0.0 : daysWithData.fold(0.0, (s, d) => s + d.fat) / daysWithData.length;

    final daysWithSteps = _days.where((d) => d.steps != null).toList();
    final avgSteps = daysWithSteps.isEmpty ? 0.0 : daysWithSteps.fold(0.0, (s, d) => s + d.steps!) / daysWithSteps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      drawer: const AppDrawer(current: AppSection.trends),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: SegmentedButton<int>(
                      segments: _periods.map((p) => ButtonSegment(value: p, label: Text(p == 7 ? '1W' : p == 14 ? '2W' : '4W'))).toList(),
                      selected: {_periodDays},
                      onSelectionChanged: (s) {
                        setState(() => _periodDays = s.first);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel(Icons.local_fire_department, 'CALORIES'),
                  _card(
                    _BarChart(
                      dates: _days.map((d) => d.date).toList(),
                      values: _days.map((d) => d.kcal).toList(),
                      hasData: _days.map((d) => d.hasData).toList(),
                      target: _targets.calories,
                      targetLabel: 'Target: ${_targets.calories.round()} kcal',
                      color: AppColors.accent,
                      labelFor: _shortLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'Avg / day',
                          value: '${avgKcal.round()} kcal',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'vs target',
                          value: _targets.calories <= 0
                              ? '—'
                              : '${((avgKcal / _targets.calories) * 100).round()}%',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatChip(
                          label: 'Days logged',
                          value: '${daysWithData.length}/$_periodDays',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(Icons.pie_chart_outline_rounded, 'AVERAGE MACROS'),
                  _card(
                    Column(
                      children: [
                        _MacroAvgRow(label: 'Protein', grams: avgProtein, target: _targets.proteinG, color: AppColors.protein),
                        const SizedBox(height: 12),
                        _MacroAvgRow(label: 'Carbs', grams: avgCarbs, target: _targets.carbsG, color: AppColors.carbs),
                        const SizedBox(height: 12),
                        _MacroAvgRow(label: 'Fat', grams: avgFat, target: _targets.fatG, color: AppColors.fat),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel(Icons.directions_walk, 'STEPS'),
                  _card(_buildStepsSection(daysWithSteps: daysWithSteps, avgSteps: avgSteps)),
                  const SizedBox(height: 24),
                  _sectionLabel(Icons.monitor_weight_outlined, 'WEIGHT'),
                  _card(_buildWeightSection()),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NutrientGapsPage()),
                    ),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('View Nutrient Gaps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWeightSection() {
    final daysWithWeight = _days.where((d) => d.weightKg != null).toList();
    if (daysWithWeight.isEmpty) {
      return const Text(
        'No weight logged yet — log it from the Profile page to see the trend here.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }

    final current = daysWithWeight.last.weightKg!;
    final first = daysWithWeight.first.weightKg!;
    final change = current - first;
    final avg = daysWithWeight.fold(0.0, (s, d) => s + d.weightKg!) / daysWithWeight.length;

    return Column(
      children: [
        _WeightLineChart(
          dates: _days.map((d) => d.date).toList(),
          values: _days.map((d) => d.weightKg).toList(),
          labelFor: _shortLabel,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Current', value: '${_fmtWeight(current)} kg')),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'Change',
                value: '${change > 0 ? '+' : ''}${_fmtWeight(change)} kg',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Avg', value: '${_fmtWeight(avg)} kg')),
          ],
        ),
      ],
    );
  }

  String _fmtWeight(double n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

  Widget _buildStepsSection({required List<_DayTotals> daysWithSteps, required double avgSteps}) {
    if (!HealthService.isSupported) {
      return const Text(
        'Step tracking needs a phone — this reads from Health Connect (Android) or Apple Health (iOS), '
        'neither of which is available on this platform.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }
    if (!_stepsChecked) {
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    }
    if (!_stepsAuthorized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step tracking permission was not granted, so steps can\'t be shown here.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _initSteps,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
            child: const Text('Grant Access'),
          ),
        ],
      );
    }
    return Column(
      children: [
        _BarChart(
          dates: _days.map((d) => d.date).toList(),
          values: _days.map((d) => (d.steps ?? 0).toDouble()).toList(),
          hasData: _days.map((d) => d.steps != null).toList(),
          target: _targets.stepsGoal,
          targetLabel: 'Goal: ${_targets.stepsGoal.round()} steps',
          color: AppColors.steps,
          labelFor: _shortLabel,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Avg / day', value: '${avgSteps.round()}')),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChip(
                label: 'vs goal',
                value: _targets.stepsGoal <= 0 ? '—' : '${((avgSteps / _targets.stepsGoal) * 100).round()}%',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Days tracked', value: '${daysWithSteps.length}/$_periodDays')),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MacroAvgRow extends StatelessWidget {
  final String label;
  final double grams;
  final double target;
  final Color color;

  const _MacroAvgRow({required this.label, required this.grams, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target <= 0 ? 0.0 : (grams / target).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              '${grams.round()}g / ${target.round()}g',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Bar chart of a daily value (calories, steps, ...) with a dashed reference
/// line at the target. Days with no data are drawn as empty ghost slots.
class _BarChart extends StatelessWidget {
  final List<DateTime> dates;
  final List<double> values;
  final List<bool> hasData;
  final double target;
  final String targetLabel;
  final Color color;
  final String Function(DateTime) labelFor;

  const _BarChart({
    required this.dates,
    required this.values,
    required this.hasData,
    required this.target,
    required this.targetLabel,
    required this.color,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) {
      return const SizedBox(height: 160, child: Center(child: Text('No data', style: TextStyle(color: AppColors.textMuted))));
    }
    final maxVal = math.max(target, values.fold<double>(0, math.max)) * 1.15;
    const chartHeight = 160.0;
    final today = DateTime.now();
    final isToday = DateTime(today.year, today.month, today.day);
    final targetBottom = maxVal <= 0 ? 0.0 : (target / maxVal * chartHeight).clamp(0.0, chartHeight);

    // Show a label under roughly every 7th day, plus the last (most recent).
    final labelStep = math.max(1, (dates.length / 6).ceil());

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: targetBottom,
                child: _DashedLine(color: AppColors.textMuted),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < dates.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Container(
                            height: maxVal <= 0 ? 0 : (values[i] / maxVal * chartHeight).clamp(0.0, chartHeight),
                            decoration: BoxDecoration(
                              color: !hasData[i] ? Colors.white10 : (dates[i] == isToday ? color : color.withValues(alpha: 0.55)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < dates.length; i++)
              Expanded(
                child: (i % labelStep == 0 || i == dates.length - 1)
                    ? Text(
                        labelFor(dates[i]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 16, height: 2, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(targetLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

/// Line chart of daily weight. Days with no logged weight leave a gap in
/// the line rather than dropping to zero (unlike the bar charts, an
/// absolute weight value near zero would be meaningless).
class _WeightLineChart extends StatelessWidget {
  final List<DateTime> dates;
  final List<double?> values;
  final String Function(DateTime) labelFor;

  const _WeightLineChart({required this.dates, required this.values, required this.labelFor});

  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    const chartHeight = 160.0;
    if (present.isEmpty) {
      return const SizedBox(
        height: chartHeight,
        child: Center(child: Text('No data', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    final minVal = present.reduce(math.min);
    final maxVal = present.reduce(math.max);
    final range = (maxVal - minVal) < 1 ? 1.0 : (maxVal - minVal);

    final labelStep = math.max(1, (dates.length / 6).ceil());

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeightLinePainter(values: values, minVal: minVal, range: range),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < dates.length; i++)
              Expanded(
                child: (i % labelStep == 0 || i == dates.length - 1)
                    ? Text(
                        labelFor(dates[i]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  final List<double?> values;
  final double minVal;
  final double range;

  _WeightLinePainter({required this.values, required this.minVal, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const paddingFrac = 0.12;
    final usableHeight = size.height * (1 - 2 * paddingFrac);
    final stepX = size.width / (values.length - 1);

    double yFor(double v) {
      final t = (v - minVal) / range;
      return size.height * paddingFrac + usableHeight * (1 - t);
    }

    final linePaint = Paint()
      ..color = AppColors.weight
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppColors.weight;

    Offset? prev;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        prev = null;
        continue;
      }
      final point = Offset(i * stepX, yFor(v));
      if (prev != null) canvas.drawLine(prev, point, linePaint);
      canvas.drawCircle(point, 3, dotPaint);
      prev = point;
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.minVal != minVal || oldDelegate.range != range;
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Container(width: dashWidth, height: 1.5, color: color),
              if (i != count - 1) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}
