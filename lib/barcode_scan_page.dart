import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'custom_foods_store.dart';
import 'models.dart';
import 'openfoodfacts_client.dart';
import 'theme.dart';

class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final OpenFoodFactsClient _off = OpenFoodFactsClient();
  final CustomFoodsStore _store = CustomFoodsStore();

  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _handling = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final product = await _off.fetchProduct(code);
      final existing = await _store.findByBarcode(code);

      if (existing != null) {
        if (!mounted) return;
        final food = await _resolveDuplicate(existing, product, code);
        if (!mounted) return;
        if (food == null) {
          // User cancelled — resume scanning instead of leaving the page.
          setState(() => _handling = false);
          await _controller.start();
          return;
        }
        Navigator.pop(context, food);
        return;
      }

      final food = await _store.create(
        name: product.name,
        source: 'scanned',
        portionGrams: product.portionGrams,
        proteinG: product.proteinG,
        carbsG: product.carbsG,
        fatG: product.fatG,
        kcal: product.kcal,
        barcode: code,
      );
      if (!mounted) return;
      Navigator.pop(context, food);
    } on ProductNotFoundException {
      _showError('No product found for that barcode.');
    } on ProductDataIncompleteException {
      _showError('Product found, but is missing nutrition data.');
    } catch (e) {
      _showError('Could not look up barcode — check your connection.');
    }
  }

  /// This barcode's already in the library. Ask whether to keep using that
  /// entry (as it currently stands, edits included) or reset it back to
  /// what was just scanned. Returns null if the user cancels.
  Future<CustomFood?> _resolveDuplicate(
    CustomFood existing,
    ProductLookupResult product,
    String code,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already scanned'),
        content: Text(
          '"${existing.name}" is already in your Custom Foods, from a previous scan of this barcode. '
          'Use the existing entry as it is now, or reset it back to the freshly scanned data?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'existing'),
            child: const Text('Use Existing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: const Text('Reset to Scanned Data'),
          ),
        ],
      ),
    );

    if (choice == 'existing') return existing;
    if (choice == 'reset') {
      return _store.update(
        existing.id,
        name: product.name,
        portionGrams: product.portionGrams,
        proteinG: product.proteinG,
        carbsG: product.carbsG,
        fatG: product.fatG,
        kcal: product.kcal,
        barcode: code,
      );
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _handling = false;
      _error = message;
    });
  }

  void _retry() {
    setState(() => _error = null);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_handling)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_error!, style: TextStyle(color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _retry, child: const Text('Try Again')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
