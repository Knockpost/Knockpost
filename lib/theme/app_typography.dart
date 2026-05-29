import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Base provider
  static TextStyle _base(double size, FontWeight weight, {double? height, double? letterSpacing, Color? color}) {
    return GoogleFonts.roboto(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // ─── Brand & Titles ──────────────────────────────────────────────
  static TextStyle get appTitle => _base(21, FontWeight.w900, letterSpacing: -0.5);
  static TextStyle get screenTitle => _base(24, FontWeight.w700);
  
  // ─── Content ─────────────────────────────────────────────────────
  static TextStyle get userName => _base(14.5, FontWeight.w700);
  static TextStyle get postBody => _base(15, FontWeight.w400);
  static TextStyle get postBodyEmphasized => _base(15, FontWeight.w500);
  
  // ─── UI Elements ─────────────────────────────────────────────────
  static TextStyle get sectionHeader => _base(16, FontWeight.w700);
  static TextStyle get buttonLabel => _base(15.5, FontWeight.w700, letterSpacing: -0.3);
  static TextStyle get userHandle => _base(13, FontWeight.w500);
  
  // ─── Metadata ────────────────────────────────────────────────────
  static TextStyle get metadata => _base(12, FontWeight.w400);
  static TextStyle get caption => _base(10.5, FontWeight.w500);
}
