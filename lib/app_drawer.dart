import 'package:flutter/material.dart';

import 'custom_foods_page.dart';
import 'nutrition_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'trends_page.dart';

/// Top-level sections reachable from the side drawer. Used both to know
/// which route to push and to highlight the current one in the drawer.
enum AppSection { today, customFoods, nutrition, trends, settings, profile }

/// Modern fold-out side nav, replacing the old bottom tab bar. Present on
/// every top-level page. Selecting a section always collapses the stack
/// back down to Today (the app root) before pushing the target page, so the
/// navigation stack never grows past two levels deep.
class AppDrawer extends StatelessWidget {
  final AppSection current;

  const AppDrawer({super.key, required this.current});

  void _go(BuildContext context, AppSection target) {
    Navigator.pop(context); // close the drawer
    if (target == current) return;

    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r.isFirst);
    switch (target) {
      case AppSection.today:
        break;
      case AppSection.customFoods:
        navigator.push(MaterialPageRoute(builder: (_) => const CustomFoodsPage()));
      case AppSection.nutrition:
        navigator.push(MaterialPageRoute(builder: (_) => const NutritionPage()));
      case AppSection.trends:
        navigator.push(MaterialPageRoute(builder: (_) => const TrendsPage()));
      case AppSection.settings:
        navigator.push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      case AppSection.profile:
        navigator.push(MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('SiNu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DrawerItem(
                icon: Icons.grid_view_rounded,
                label: 'Today',
                active: current == AppSection.today,
                onTap: () => _go(context, AppSection.today),
              ),
              _DrawerItem(
                icon: Icons.restaurant_menu,
                label: 'Custom Foods',
                active: current == AppSection.customFoods,
                onTap: () => _go(context, AppSection.customFoods),
              ),
              _DrawerItem(
                icon: Icons.pie_chart_outline_rounded,
                label: 'Nutrition & Steps',
                active: current == AppSection.nutrition,
                onTap: () => _go(context, AppSection.nutrition),
              ),
              _DrawerItem(
                icon: Icons.show_chart_rounded,
                label: 'Trends',
                active: current == AppSection.trends,
                onTap: () => _go(context, AppSection.trends),
              ),
              const Spacer(),
              Divider(color: AppColors.border, height: 24),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: current == AppSection.settings,
                onTap: () => _go(context, AppSection.settings),
              ),
              _DrawerItem(
                icon: Icons.person_outline,
                label: 'Profile',
                active: current == AppSection.profile,
                onTap: () => _go(context, AppSection.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: active ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

