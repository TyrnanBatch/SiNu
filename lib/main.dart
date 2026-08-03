import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'add_food_page.dart';
import 'amount_sheet.dart';
import 'app_drawer.dart';
import 'custom_foods_store.dart';
import 'food_avatar.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'user_targets.dart';

/// Lets [HomePage] know when it's been returned to (e.g. after editing
/// custom foods) so it can refresh, regardless of which drawer section
/// pushed the covering route.
final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

void main() {
  runApp(const SiNuApp());
}

class SiNuApp extends StatelessWidget {
  const SiNuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiNu',
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      // On a wide (desktop/laptop) window, letterbox the app to phone
      // dimensions instead of stretching it full-width. Real phones and
      // narrow windows are already phone-sized, so this is a no-op there.
      builder: (context, child) {
        const phoneWidth = 390.0;
        const phoneHeight = 844.0;
        final size = MediaQuery.sizeOf(context);
        if (size.width <= phoneWidth || child == null) return child ?? const SizedBox.shrink();

        final frameHeight = phoneHeight > size.height ? size.height : phoneHeight;
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: phoneWidth,
              height: frameHeight,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(phoneWidth, frameHeight)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
      home: const HomePage(),
    );
  }
}

// --- UI ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final CustomFoodsStore _foodsStore = CustomFoodsStore();
  final MealsStorage _storage = MealsStorage();
  final UserTargetsStore _targetsStore = UserTargetsStore();
  late final DateTime _todayDate;
  late DateTime _selectedDate;
  List<MealData> _meals = [MealData(number: 1)];

  List<CustomFood> _customFoods = [];
  bool _loadingFoods = true;
  UserTargets _targets = UserTargets.defaults;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _todayDate;
    _loadFoods();
    _loadTargets();
    _loadMealsForSelectedDate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when a route pushed on top of this page (e.g. Custom Foods or
  /// Nutrition) is popped and Today becomes visible again — refresh in case
  /// foods or targets changed.
  @override
  void didPopNext() {
    _loadFoods();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final targets = await _targetsStore.load();
    if (!mounted) return;
    setState(() => _targets = targets);
  }

  Future<void> _loadMealsForSelectedDate() async {
    final saved = await _storage.loadMeals(_selectedDate);
    if (!mounted) return;
    setState(() => _meals = (saved != null && saved.isNotEmpty) ? saved : [MealData(number: 1)]);
    _syncMealsWithFoods(_customFoods);
  }

  void _changeDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _loadMealsForSelectedDate();
  }

  void _persistMeals() {
    unawaited(_storage.saveMeals(_selectedDate, _meals));
  }

  Future<void> _loadFoods() async {
    setState(() => _loadingFoods = true);
    final foods = await _foodsStore.loadAll();
    if (!mounted) return;
    setState(() {
      _customFoods = foods;
      _loadingFoods = false;
    });
    _syncMealsWithFoods(foods);
  }

  /// Keeps already-logged items in sync with edits made to their source
  /// custom food (e.g. correcting a macro value updates today's totals too).
  void _syncMealsWithFoods(List<CustomFood> foods) {
    final foodsById = {for (final f in foods) f.id: f};
    var changed = false;
    for (final meal in _meals) {
      for (final item in meal.items) {
        final food = item.foodId == null ? null : foodsById[item.foodId];
        if (food != null && item.updateRatesFrom(food)) {
          changed = true;
        }
      }
    }
    if (changed) {
      setState(() {});
      _persistMeals();
    }
  }

  void _addMeal() {
    setState(() {
      _meals.add(MealData(number: _meals.length + 1));
    });
    _persistMeals();
  }

  Future<void> _addFoodToMeal(MealData meal) async {
    if (_loadingFoods) return;

    final item = await Navigator.push<LoggedItem>(
      context,
      MaterialPageRoute(builder: (context) => AddFoodPage(foods: _customFoods)),
    );
    if (item != null) {
      setState(() => meal.items.add(item));
      _persistMeals();
    }
    unawaited(_loadFoods());
  }

  Future<void> _editItemAmount(LoggedItem item) async {
    final grams = await AmountSheet.show(
      context,
      title: item.name,
      initialGrams: item.grams,
      submitLabel: 'Save',
    );
    if (grams == null) return;
    setState(() => item.grams = grams);
    _persistMeals();
  }

  void _deleteItem(MealData meal, LoggedItem item) {
    setState(() => meal.items.remove(item));
    _persistMeals();
  }

  void _deleteMeal(MealData meal) {
    setState(() => _meals.remove(meal));
    _persistMeals();
  }

  Future<void> _confirmDeleteMeal(MealData meal) async {
    if (meal.items.isEmpty) {
      _deleteMeal(meal);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(
          'This removes Meal ${meal.number} and its ${meal.items.length} '
          'item${meal.items.length == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteMeal(meal);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _todayDate.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
    _loadMealsForSelectedDate();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _meals.expand((m) => m.items);
    final eatenKcal = allItems.fold<double>(0, (sum, i) => sum + i.kcal);
    final eatenProtein = allItems.fold<double>(0, (sum, i) => sum + i.proteinG);
    final eatenCarbs = allItems.fold<double>(0, (sum, i) => sum + i.carbsG);
    final eatenFat = allItems.fold<double>(0, (sum, i) => sum + i.fatG);
    final daysDiff = _selectedDate.difference(_todayDate).inDays;
    final withinWeek = daysDiff.abs() <= 7;
    final appBarTitle = daysDiff == 0
        ? 'TODAY'
        : (withinWeek ? _weekdayName(_selectedDate).toUpperCase() : _formatDateWords(_selectedDate).toUpperCase());

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _pickDate),
        ],
      ),
      drawer: const AppDrawer(current: AppSection.today),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            DateHeader(
              selectedDate: _selectedDate,
              todayDate: _todayDate,
              onPrevious: () => _changeDay(-1),
              onNext: () => _changeDay(1),
            ),
            const SizedBox(height: 20),
            SummaryRow(
              eatenKcal: eatenKcal,
              eatenProtein: eatenProtein,
              eatenCarbs: eatenCarbs,
              eatenFat: eatenFat,
              targets: _targets,
            ),
            const SizedBox(height: 20),
            ..._meals.map(
              (meal) => MealSection(
                meal: meal,
                onAddFood: () => _addFoodToMeal(meal),
                onEditItem: _editItemAmount,
                onDeleteItem: (item) => _deleteItem(meal, item),
                onDeleteMeal: () => _confirmDeleteMeal(meal),
              ),
            ),
            AddMealButton(onPressed: _addMeal),
          ],
        ),
      ),
    );
  }
}

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _weekdayName(DateTime d) => _weekdayNames[d.weekday - 1];

String _formatDateWords(DateTime d) => '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

class DateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime todayDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DateHeader({
    super.key,
    required this.selectedDate,
    required this.todayDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate.difference(todayDate).inDays == 0;
    final dateLine = isToday
        ? '${_weekdayName(selectedDate)}, ${_formatDateWords(selectedDate)}'
        : _formatDateWords(selectedDate);

    return Row(
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
        Expanded(
          child: Text(
            dateLine,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  final double eatenKcal;
  final double eatenProtein;
  final double eatenCarbs;
  final double eatenFat;
  final UserTargets targets;

  const SummaryRow({
    super.key,
    required this.eatenKcal,
    required this.eatenProtein,
    required this.eatenCarbs,
    required this.eatenFat,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    final eaten = eatenKcal.round();
    final left = targets.calories.round() - eaten;
    final progress = eatenKcal / targets.calories;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department, size: 16, color: AppColors.accent),
              SizedBox(width: 4),
              Text(
                'ENERGY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EnergyRing(progress: progress, eaten: eaten, left: left),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 140,
                  child: Row(
                    children: [
                      Expanded(
                        child: VerticalMacroBar(
                          label: 'Protein',
                          current: eatenProtein,
                          target: targets.proteinG,
                          color: AppColors.protein,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: VerticalMacroBar(
                          label: 'Carbs',
                          current: eatenCarbs,
                          target: targets.carbsG,
                          color: AppColors.carbs,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: VerticalMacroBar(
                          label: 'Fat',
                          current: eatenFat,
                          target: targets.fatG,
                          color: AppColors.fat,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyRing extends StatelessWidget {
  final double progress;
  final int eaten;
  final int left;

  const _EnergyRing({required this.progress, required this.eaten, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$eaten', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text(
                'EATEN',
                style: TextStyle(fontSize: 10, letterSpacing: 1.0, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Container(width: 22, height: 1, color: Colors.white24),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$left kcal Left',
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A macro's daily progress as a vertical bar: label + goal at the top, a
/// bar that fills top-down as more is eaten, then % and grams eaten at the
/// bottom. Sits beside the energy ring instead of the old horizontal bars.
class VerticalMacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;

  const VerticalMacroBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0, 1).toDouble();
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${target.round()}g',
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: SizedBox(
            width: 8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const ColoredBox(color: Colors.white12),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: progress,
                    widthFactor: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ColoredBox(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '${current.round()}g',
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class AddMealButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddMealButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('Add Meal'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class MealSection extends StatefulWidget {
  final MealData meal;
  final VoidCallback onAddFood;
  final ValueChanged<LoggedItem> onEditItem;
  final ValueChanged<LoggedItem> onDeleteItem;
  final VoidCallback onDeleteMeal;

  const MealSection({
    super.key,
    required this.meal,
    required this.onAddFood,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onDeleteMeal,
  });

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          initiallyExpanded: true,
          onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.meal,
            child: Icon(Icons.restaurant_menu, size: 18, color: Colors.white),
          ),
          title: Text('Meal ${meal.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${meal.proteinTotal.round()} P  ${meal.carbsTotal.round()} C  ${meal.fatTotal.round()} F',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${meal.kcalTotal.round()} kcal', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDeleteMeal,
              ),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            ],
          ),
          children: [
            if (meal.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No items yet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              )
            else
              ...meal.items.map(
                (item) => FoodItemTile(
                  key: ValueKey(item),
                  item: item,
                  onTap: () => widget.onEditItem(item),
                  onDelete: () => widget.onDeleteItem(item),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                onTap: widget.onAddFood,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: accent),
                      const SizedBox(width: 8),
                      Text('Add Food', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodItemTile extends StatefulWidget {
  final LoggedItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FoodItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<FoodItemTile> createState() => _FoodItemTileState();
}

class _FoodItemTileState extends State<FoodItemTile> {
  bool _nameExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Slidable(
      key: widget.key!,
      // Swipe left-to-right reveals Edit on the left.
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => widget.onTap(),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
          ),
        ],
      ),
      // Swipe right-to-left reveals Delete on the right.
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => widget.onDelete(),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _nameExpanded = !_nameExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FoodAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: _nameExpanded ? null : 1,
                        overflow: _nameExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        softWrap: _nameExpanded,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.grams.round()} · ${item.proteinG.round()} P  ${item.carbsG.round()} C  ${item.fatG.round()} F',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${item.kcal.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('kcal', style: TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
