import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import 'photo_entry.dart';
import 'storage.dart';
import 'theme.dart';

/// Renders a single shareable "then vs now" card from two user-picked
/// progress photos, overlaid with the weight change, days elapsed, and
/// average daily calories logged in between — then lets it be saved as a
/// PNG. [before]/[after] must already be ordered oldest-first.
class PhotoComparisonPage extends StatefulWidget {
  final PhotoEntry before;
  final PhotoEntry after;

  const PhotoComparisonPage({super.key, required this.before, required this.after});

  @override
  State<PhotoComparisonPage> createState() => _PhotoComparisonPageState();
}

class _PhotoComparisonPageState extends State<PhotoComparisonPage> {
  final _captureKey = GlobalKey();
  bool _loadingStats = true;
  bool _saving = false;
  double? _avgKcal;

  @override
  void initState() {
    super.initState();
    _loadAvgCalories();
  }

  Future<void> _loadAvgCalories() async {
    final storage = MealsStorage();
    var total = 0.0;
    var daysWithData = 0;
    final days = widget.after.date.difference(widget.before.date).inDays;

    for (var i = 0; i <= days; i++) {
      final date = widget.before.date.add(Duration(days: i));
      final meals = await storage.loadMeals(date);
      if (meals == null || meals.isEmpty) continue;
      total += meals.fold(0.0, (s, m) => s + m.kcalTotal);
      daysWithData++;
    }

    if (!mounted) return;
    setState(() {
      _avgKcal = daysWithData == 0 ? null : total / daysWithData;
      _loadingStats = false;
    });
  }

  Future<void> _saveImage() async {
    setState(() => _saving = true);
    try {
      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/comparisons');
      await outDir.create(recursive: true);
      final path = '${outDir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save image')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _fmtWeight(double n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final before = widget.before;
    final after = widget.after;
    final days = after.date.difference(before.date).inDays;
    final weightDelta = (before.weightKgAtLogging != null && after.weightKgAtLogging != null)
        ? after.weightKgAtLogging! - before.weightKgAtLogging!
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Photos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _PhotoColumn(entry: before, label: _formatDate(before.date))),
                      const SizedBox(width: 12),
                      Expanded(child: _PhotoColumn(entry: after, label: _formatDate(after.date))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatColumn(
                            label: 'Weight',
                            value: weightDelta == null
                                ? '—'
                                : '${weightDelta > 0 ? '+' : ''}${_fmtWeight(weightDelta)} kg',
                          ),
                        ),
                        Expanded(child: _StatColumn(label: 'Days', value: '$days')),
                        Expanded(
                          child: _StatColumn(
                            label: 'Avg kcal/day',
                            value: _loadingStats
                                ? '…'
                                : (_avgKcal == null ? '—' : '${_avgKcal!.round()}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _saveImage,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_outlined),
            label: const Text('Save Image'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoColumn extends StatelessWidget {
  final PhotoEntry entry;
  final String label;

  const _PhotoColumn({required this.entry, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.file(File(entry.imagePath), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
