import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_drawer.dart';
import 'backup_service.dart';
import 'health_service.dart';
import 'theme.dart';
import 'theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final HealthService _health = HealthService();
  final BackupService _backup = BackupService();

  bool _checkingSteps = true;
  bool _stepsAuthorized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkSteps();
  }

  Future<void> _checkSteps() async {
    setState(() => _checkingSteps = true);
    final granted = HealthService.isSupported ? await _health.requestStepsPermission() : false;
    if (!mounted) return;
    setState(() {
      _stepsAuthorized = granted;
      _checkingSteps = false;
    });
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final json = await _backup.exportAll();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup copied to clipboard — paste it somewhere safe')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a backup exported from SiNu. This overwrites your current foods, meal templates, '
              'logged history, and targets with whatever the backup contains.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste backup JSON here'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (json == null || json.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await _backup.importAll(json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup imported — restart the app to see it everywhere')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import — that doesn\'t look like a SiNu backup')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required Future<void> Function() action,
    required String doneMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(current: AppSection.settings),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(Icons.palette_outlined, 'APPEARANCE'),
          _card([
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    ThemeController.instance.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ThemeController.instance.isDark ? 'Dark Mode' : 'Light Mode',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: !ThemeController.instance.isDark,
                    onChanged: (light) => ThemeController.instance.setDark(!light),
                    activeThumbColor: AppColors.accent,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionLabel(Icons.directions_walk, 'STEP TRACKING'),
          _card([
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    !HealthService.isSupported
                        ? Icons.block
                        : (_stepsAuthorized ? Icons.check_circle : Icons.error_outline),
                    size: 20,
                    color: !HealthService.isSupported
                        ? AppColors.textMuted
                        : (_stepsAuthorized ? AppColors.accent : Colors.amber),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !HealthService.isSupported
                              ? 'Not available on this platform'
                              : (_checkingSteps
                                  ? 'Checking permission...'
                                  : (_stepsAuthorized ? 'Connected' : 'Permission not granted')),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          !HealthService.isSupported
                              ? 'Reads steps from Health Connect (Android) or Apple Health (iOS) — neither exists here.'
                              : 'Used by the Trends page to show your daily step count.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (HealthService.isSupported && !_checkingSteps && !_stepsAuthorized)
                    TextButton(onPressed: _checkSteps, child: const Text('Grant Access')),
                  if (HealthService.isSupported && !_checkingSteps && _stepsAuthorized)
                    IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _checkSteps),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionLabel(Icons.storage_outlined, 'DATA'),
          _card([
            _actionRow(
              icon: Icons.upload_outlined,
              label: 'Export Backup',
              subtitle: 'Copy all your data as JSON to the clipboard',
              onTap: _exportBackup,
            ),
            _actionRow(
              icon: Icons.download_outlined,
              label: 'Import Backup',
              subtitle: 'Paste a previously exported backup to restore it',
              onTap: _importBackup,
            ),
            _actionRow(
              icon: Icons.history,
              label: 'Clear Meal History',
              subtitle: 'Deletes every logged day — foods and templates are kept',
              color: Colors.redAccent,
              onTap: () => _confirmAndRun(
                title: 'Clear meal history?',
                content: 'This permanently deletes every day you\'ve logged. Custom foods and meal templates are not affected.',
                action: _backup.clearMealHistory,
                doneMessage: 'Meal history cleared',
              ),
            ),
            _actionRow(
              icon: Icons.restaurant_menu,
              label: 'Reset Custom Foods',
              subtitle: 'Deletes your whole custom foods library',
              color: Colors.redAccent,
              onTap: () => _confirmAndRun(
                title: 'Reset custom foods?',
                content: 'This permanently deletes every custom food, including scanned and USDA-imported ones.',
                action: _backup.resetCustomFoods,
                doneMessage: 'Custom foods reset',
              ),
            ),
            _actionRow(
              icon: Icons.bookmark_outline,
              label: 'Reset Meal Templates',
              subtitle: 'Deletes every saved meal template',
              color: Colors.redAccent,
              onTap: () => _confirmAndRun(
                title: 'Reset meal templates?',
                content: 'This permanently deletes every saved meal template.',
                action: _backup.resetMealTemplates,
                doneMessage: 'Meal templates reset',
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionLabel(Icons.info_outline, 'ABOUT'),
          _card([
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.eco_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SiNu', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
