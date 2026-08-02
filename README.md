# SiNu (Simple Nutrition)

A dark-themed daily calorie, macro, and micronutrient tracker built in Flutter. Fully on-device — no account, no backend, no sync.

## What works today

- **Daily log** — an energy ring for calories eaten vs. target, vertical bars for protein/carbs/fat, and a list of meals you build up through the day.
- **Custom Foods library** — create foods by hand, scan barcodes, star favourites, browse by All / Favourites / Scanned.
- **Detailed nutrition per food** — beyond the core macros, foods support an optional breakdown of vitamins, minerals, fat types (incl. omega-3/6, DHA, EPA), fiber, and sugars, each shown against a daily recommended intake.
- **Nutrition targets** — set your own daily calorie/macro targets, or answer a few questions (height, weight, age, activity, goal) to get a suggested split.

## Logging methods

- **Barcode scan** — looked up via [OpenFoodFacts](https://world.openfoodfacts.org/).
- **Manual entry** — build a custom food with exact known values.
- **Free-text description** *(planned)* — describe what you ate in plain language and have it parsed automatically.

## AI plans

Two things we want an on-device model to help with, both shown with an accuracy/confidence range rather than presented as exact:

- **Estimating vitamins and minerals** for a food from its name and macros, asking a couple of clarifying questions when it helps narrow things down.
- **Estimating macros from a food description** for free-text logging.

Leaning towards a small quantized local model (candidate: **Qwen2.5, 0.5B–3B, running via llama.cpp**) so this works fully offline, in keeping with the rest of the app. Not yet implemented.

## Tech stack

- Flutter/Dart, Material 3, dark theme
- Local storage only — `SharedPreferences`, no server
- Barcode scanning via `mobile_scanner` + the OpenFoodFacts API

## Development

```bash
flutter pub get
flutter analyze lib
flutter test
```

Run on web for quick iteration:

```bash
flutter run -d chrome
```
