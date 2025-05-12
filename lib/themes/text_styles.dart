import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  static const selectedLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const unselectedLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.unselected,
  );
}
