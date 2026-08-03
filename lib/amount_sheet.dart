import 'package:flutter/material.dart';

import 'theme.dart';

/// Bottom sheet for entering a gram amount. Used both when adding a food
/// to a meal and when editing the amount of an already-logged item. When
/// [defaultPortionGrams] is set, also offers a "portions" entry mode (e.g.
/// "2 portions" of a food whose default portion is 30g = 60g).
class AmountSheet extends StatefulWidget {
  final String title;
  final double initialGrams;
  final String submitLabel;
  final double? defaultPortionGrams;

  const AmountSheet({
    super.key,
    required this.title,
    required this.initialGrams,
    this.submitLabel = 'Add',
    this.defaultPortionGrams,
  });

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required double initialGrams,
    String submitLabel = 'Add',
    double? defaultPortionGrams,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => AmountSheet(
        title: title,
        initialGrams: initialGrams,
        submitLabel: submitLabel,
        defaultPortionGrams: defaultPortionGrams,
      ),
    );
  }

  @override
  State<AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<AmountSheet> {
  late final TextEditingController _gramsController;
  late final TextEditingController _portionsController;
  bool _usePortions = false;
  String? _error;

  bool get _hasDefaultPortion => (widget.defaultPortionGrams ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _gramsController = TextEditingController(text: widget.initialGrams.round().toString());
    _portionsController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _portionsController.dispose();
    super.dispose();
  }

  String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

  void _submit() {
    double? grams;
    if (_usePortions) {
      final portions = double.tryParse(_portionsController.text);
      if (portions == null || portions <= 0) {
        setState(() => _error = 'Enter a valid number of portions');
        return;
      }
      grams = portions * widget.defaultPortionGrams!;
    } else {
      grams = double.tryParse(_gramsController.text);
      if (grams == null || grams <= 0) {
        setState(() => _error = 'Enter a valid amount in grams');
        return;
      }
    }
    Navigator.pop(context, grams);
  }

  @override
  Widget build(BuildContext context) {
    final portions = double.tryParse(_portionsController.text) ?? 0;
    final computedGrams = portions * (widget.defaultPortionGrams ?? 0);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_hasDefaultPortion) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Grams')),
                ButtonSegment(value: true, label: Text('Portions')),
              ],
              selected: {_usePortions},
              onSelectionChanged: (s) => setState(() {
                _usePortions = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
          ],
          if (_usePortions)
            TextField(
              controller: _portionsController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Portions',
                helperText: '1 portion = ${_fmt(widget.defaultPortionGrams!)}g  ·  total ${computedGrams.round()}g',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            )
          else
            TextField(
              controller: _gramsController,
              autofocus: !_hasDefaultPortion,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (g)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}
