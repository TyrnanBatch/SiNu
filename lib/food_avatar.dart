import 'package:flutter/material.dart';

import 'theme.dart';

/// Default placeholder shown for a food's image. For now every food gets the
/// same icon; a per-food custom emoji/icon picker can replace this later.
class FoodAvatar extends StatelessWidget {
  final double size;

  const FoodAvatar({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.restaurant, size: size * 0.5, color: AppColors.accent),
    );
  }
}
