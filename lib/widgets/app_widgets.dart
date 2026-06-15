import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/theme.dart';

/// A card-style Container with a border, rounded corners, and the standard
/// bg1 background colour.  Used in place of the repeated `BoxDecoration`
/// pattern that appears across Settings, Prayer, and Calendar screens.
class ThemedCard extends StatelessWidget {
  final AppTheme appTheme;
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const ThemedCard({
    super.key,
    required this.appTheme,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: appTheme.bg1,
        border: Border.all(color: appTheme.line),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

/// A small pill-shaped button with a border, used for labelled actions
/// such as "CHANGE", "USE GPS", "Back to Today", and "TODAY".
class BorderIconButton extends StatelessWidget {
  final AppTheme appTheme;
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final double letterSpacing;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const BorderIconButton({
    super.key,
    required this.appTheme,
    required this.label,
    this.onTap,
    this.fontSize = 10,
    this.letterSpacing = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: appTheme.accent),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: appTheme.accent,
            letterSpacing: letterSpacing,
          ),
        ),
      ),
    );
  }
}
