import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

BottomNavigationBarThemeData bottomNavTheme = BottomNavigationBarThemeData(
  backgroundColor: AppColors.background,
  selectedItemColor: AppColors.primary,
  unselectedItemColor: AppColors.unselected,
  selectedLabelStyle: AppTextStyles.selectedLabel,
  unselectedLabelStyle: AppTextStyles.unselectedLabel,
  showUnselectedLabels: true,
  type: BottomNavigationBarType.fixed,
);
