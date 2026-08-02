import 'package:flutter/material.dart';

import 'theme.dart';

/// Bottom sheet for entering a gram amount. Used both when adding a food
/// to a meal and when editing the amount of an already-logged item.
class AmountSheet extends StatefulWidget {
  final String title;
  final double initialGrams;
  final String submitLabel;

  const AmountSheet({
    super.key,
    required this.title,
    required this.initialGrams,
    this.submitLabel = 'Add',
  });

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required double initialGrams,
    String submitLabel = 'Add',
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
      ),
    );
  }

  @override
  State<AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<AmountSheet> {
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialGrams.round().toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final grams = double.tryParse(_amountController.text);
    if (grams == null || grams <= 0) {
      setState(() => _error = 'Enter a valid amount in grams');
      return;
    }
    Navigator.pop(context, grams);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            autofocus: true,
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
