import 'package:flutter/material.dart';

import 'app_drawer.dart';
import 'nutrition_calc.dart';
import 'theme.dart';
import 'user_profile.dart';
import 'weight_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserProfileStore _store = UserProfileStore();
  final WeightStore _weightStore = WeightStore();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _todayWeightController = TextEditingController();
  BiologicalSex _sex = BiologicalSex.male;

  bool _loading = true;
  bool _saving = false;
  bool _loggingWeight = false;

  @override
  void initState() {
    super.initState();
    _heightController.addListener(_onChanged);
    _weightController.addListener(_onChanged);
    _ageController.addListener(_onChanged);
    _load();
  }

  void _onChanged() => setState(() {});

  Future<void> _load() async {
    final profile = await _store.load();
    final todayWeight = await _weightStore.loadWeight(DateTime.now());
    if (!mounted) return;
    if (profile != null) {
      _sex = profile.sex;
      _heightController.text = _fmt(profile.heightCm);
      _weightController.text = _fmt(profile.weightKg);
      _ageController.text = '${profile.age}';
    }
    if (todayWeight != null) _todayWeightController.text = _fmt(todayWeight);
    setState(() => _loading = false);
  }

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();
  double? _readDouble(TextEditingController c) => double.tryParse(c.text);
  int? _readInt(TextEditingController c) => int.tryParse(c.text);

  Future<void> _logWeight() async {
    final value = _readDouble(_todayWeightController);
    if (value == null || value <= 0) return;
    setState(() => _loggingWeight = true);
    await _weightStore.saveWeight(DateTime.now(), value);
    if (!mounted) return;
    setState(() {
      _weightController.text = _fmt(value);
      _loggingWeight = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight logged')));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _todayWeightController.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _readDouble(_heightController) != null && _readDouble(_weightController) != null && _readInt(_ageController) != null;

  Future<void> _save() async {
    if (!_isComplete) return;
    setState(() => _saving = true);
    await _store.save(
      UserProfile(
        sex: _sex,
        heightCm: _readDouble(_heightController)!,
        weightKg: _readDouble(_weightController)!,
        age: _readInt(_ageController)!,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  InputDecoration _fieldDecoration(String label, {String? suffixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 9),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
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

  @override
  Widget build(BuildContext context) {
    final height = _readDouble(_heightController);
    final weight = _readDouble(_weightController);
    final age = _readInt(_ageController);
    final bmr = (height != null && weight != null && age != null)
        ? computeBmr(sex: _sex, heightCm: height, weightKg: weight, age: age)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      drawer: const AppDrawer(current: AppSection.profile),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionLabel(Icons.monitor_weight_outlined, "TODAY'S WEIGHT"),
                _card([
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _todayWeightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              suffixText: 'kg',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _loggingWeight ? null : _logWeight,
                          child: _loggingWeight
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Log'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Logged daily, shown as a trend on the Trends page.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel(Icons.person_outline, 'BODY STATS'),
                _card([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SegmentedButton<BiologicalSex>(
                      segments: const [
                        ButtonSegment(value: BiologicalSex.male, label: Text('Male')),
                        ButtonSegment(value: BiologicalSex.female, label: Text('Female')),
                      ],
                      selected: {_sex},
                      onSelectionChanged: (s) => setState(() => _sex = s.first),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  TextFormField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Height', suffixText: 'cm'),
                  ),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _fieldDecoration('Weight', suffixText: 'kg'),
                  ),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Age', suffixText: 'years'),
                  ),
                ]),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Used to prefill "Get Recommendations" on the Nutrition & Steps page.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 24),
                if (bmr != null) ...[
                  _sectionLabel(Icons.bolt_outlined, 'ESTIMATED BMR'),
                  _card([
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${bmr.round()} kcal/day', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text(
                            'Calories burned at rest (Mifflin-St Jeor)',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
                FilledButton(
                  onPressed: (_saving || !_isComplete) ? null : _save,
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
