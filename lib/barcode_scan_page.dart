import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'custom_foods_store.dart';
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
      final food = await _store.create(
        name: product.name,
        source: 'scanned',
        portionGrams: product.portionGrams,
        proteinG: product.proteinG,
        carbsG: product.carbsG,
        fatG: product.fatG,
        kcal: product.kcal,
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
                    Text(_error!, style: const TextStyle(color: Colors.white)),
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
