import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_drawer.dart';
import 'models.dart';
import 'photo_comparison_page.dart';
import 'photo_entry.dart';
import 'photos_store.dart';
import 'storage.dart';
import 'theme.dart';
import 'weight_store.dart';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Progress photo gallery. When [initialDate] is set (arriving from a tap
/// on the Trends weight graph), opens straight into that day's photo.
class PhotosPage extends StatefulWidget {
  final DateTime? initialDate;

  const PhotosPage({super.key, this.initialDate});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  final _store = PhotosStore();
  List<PhotoEntry> _photos = [];
  bool _loading = true;
  bool _adding = false;

  bool _comparing = false;
  final Set<DateTime> _selectedDates = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
    });
    final target = widget.initialDate;
    if (target != null) {
      final match = photos.where((p) => _sameDay(p.date, target));
      if (match.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openDetail(match.first);
        });
      }
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not access camera/gallery')));
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _adding = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Copy out of the OS's temp/cache location into app storage so it
      // isn't liable to be cleared out from under us later.
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/progress_photos');
      await photosDir.create(recursive: true);
      final destPath = '${photosDir.path}/${now.millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(destPath);

      final meals = await MealsStorage().loadMeals(today) ?? const <MealData>[];
      final kcalToday = meals.fold(0.0, (s, m) => s + m.kcalTotal);
      final weightToday = await WeightStore().loadWeight(today);

      final entry = PhotoEntry(
        date: today,
        imagePath: destPath,
        kcalAtLogging: kcalToday,
        weightKgAtLogging: weightToday,
      );
      await _store.save(entry);
      if (!mounted) return;
      await _load();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _openDetail(PhotoEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailPage(
          entry: entry,
          onDeleted: () => setState(() => _photos.removeWhere((p) => _sameDay(p.date, entry.date))),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _toggleComparing() {
    setState(() {
      _comparing = !_comparing;
      _selectedDates.clear();
    });
  }

  void _toggleSelected(PhotoEntry photo) {
    setState(() {
      if (_selectedDates.contains(photo.date)) {
        _selectedDates.remove(photo.date);
        return;
      }
      if (_selectedDates.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick 2 photos to compare')));
        return;
      }
      _selectedDates.add(photo.date);
    });
  }

  Future<void> _goToComparison() async {
    final selected = _photos.where((p) => _selectedDates.contains(p.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
    if (selected.length != 2) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PhotoComparisonPage(before: selected[0], after: selected[1])),
    );
    if (!mounted) return;
    _toggleComparing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _comparing ? IconButton(icon: const Icon(Icons.close), onPressed: _toggleComparing) : null,
        title: Text(_comparing ? 'Select 2 Photos' : 'Progress Photos'),
        actions: _comparing
            ? [
                TextButton(
                  onPressed: _selectedDates.length == 2 ? _goToComparison : null,
                  child: const Text('Compare'),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.compare_arrows),
                  tooltip: 'Compare two photos',
                  onPressed: _photos.length < 2 ? null : _toggleComparing,
                ),
                IconButton(
                  icon: _adding
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined),
                  onPressed: _adding ? null : _addPhoto,
                ),
              ],
      ),
      drawer: _comparing ? null : const AppDrawer(current: AppSection.photos),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? Center(
              child: Text('No progress photos yet — tap the camera icon to add one', style: TextStyle(color: AppColors.textMuted)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final selected = _selectedDates.contains(photo.date);
                return Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _comparing ? _toggleSelected(photo) : _openDetail(photo),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(photo.imagePath), fit: BoxFit.cover),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: Colors.black54,
                            child: Text(
                              _formatDate(photo.date),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ),
                        if (_comparing)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              selected ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: selected ? AppColors.accent : Colors.white,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PhotoDetailPage extends StatefulWidget {
  final PhotoEntry entry;
  final VoidCallback onDeleted;

  const PhotoDetailPage({super.key, required this.entry, required this.onDeleted});

  @override
  State<PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<PhotoDetailPage> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This permanently removes this progress photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    await PhotosStore().delete(widget.entry.date);
    if (!mounted) return;
    widget.onDeleted();
    Navigator.pop(context);
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _fmtWeight(double n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(entry.date)),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(child: Image.file(File(entry.imagePath))),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        entry.kcalAtLogging != null ? '${entry.kcalAtLogging!.round()} kcal' : '—',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('that day', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        entry.weightKgAtLogging != null ? '${_fmtWeight(entry.weightKgAtLogging!)} kg' : '—',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text('weight', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
