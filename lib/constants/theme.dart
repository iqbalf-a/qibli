import 'package:flutter/material.dart';

class AppTheme {
  final String key;
  final String name;
  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color textDim;
  final Color textMute;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color accentGlow;
  final Color shadow;
  final List<Color> swatches;
  final List<Color> cardGradient;
  final Color cardBorder;
  final double cardShadowOpacity;
  final double cardShadowRadius;
  final double cardShadowOffsetY;
  final int cardElevation;
  final Color rowActiveBg;
  final List<Color> compassGradient;
  final Color calendarCardBg;
  final Color navBtnBg;
  final Color toggleTrackBg;
  final Color toggleThumbBg;
  final Color rowIconBg;
  final bool isDark;

  const AppTheme({
    required this.key,
    required this.name,
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textDim,
    required this.textMute,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.accentGlow,
    required this.shadow,
    required this.swatches,
    required this.cardGradient,
    required this.cardBorder,
    required this.cardShadowOpacity,
    required this.cardShadowRadius,
    required this.cardShadowOffsetY,
    required this.cardElevation,
    required this.rowActiveBg,
    required this.compassGradient,
    required this.calendarCardBg,
    required this.navBtnBg,
    required this.toggleTrackBg,
    required this.toggleThumbBg,
    required this.rowIconBg,
    required this.isDark,
  });
}

const _cosmic = AppTheme(
  key: 'cosmic',
  name: 'Cosmic Indigo',
  isDark: true,
  bg0: Color(0xFF070514),
  bg1: Color(0xFF0E0A22),
  bg2: Color(0xFF171236),
  bg3: Color(0xFF221B4D),
  line: Color(0x12FFFFFF),
  lineStrong: Color(0x24FFFFFF),
  text: Color(0xFFEFEDFF),
  textDim: Color(0xA8EFEDFF),
  textMute: Color(0x66EFEDFF),
  accent: Color(0xFFA89BFF),
  accentSoft: Color(0xFFC9C0FF),
  accentDeep: Color(0xFF5A4DCC),
  accentGlow: Color(0x66A89BFF),
  shadow: Color(0xFFA89BFF),
  swatches: [
    Color(0xFF070514),
    Color(0xFF4D4080),
    Color(0xFFA89BFF),
    Color(0xFFC9C0FF)
  ],
  cardGradient: [Color(0xFF221B4D), Color(0xFF0E0A22), Color(0xFF070514)],
  cardBorder: Color(0x24FFFFFF),
  cardShadowOpacity: 0.25,
  cardShadowRadius: 24,
  cardShadowOffsetY: 0,
  cardElevation: 10,
  rowActiveBg: Color(0xFF221B4D),
  compassGradient: [
    Color(0xFF171236),
    Color(0xFF070514),
    Color(0xFF070514),
    Color(0xFF171236),
    Color(0xFF221B4D)
  ],
  calendarCardBg: Color(0xFF0E0A22),
  navBtnBg: Color(0xFF221B4D),
  toggleTrackBg: Color(0xFF171236),
  toggleThumbBg: Color(0xFF221B4D),
  rowIconBg: Color(0xFF221B4D),
);

const _midnight = AppTheme(
  key: 'midnight',
  name: 'Midnight Brass',
  isDark: true,
  bg0: Color(0xFF070A14),
  bg1: Color(0xFF0C1220),
  bg2: Color(0xFF141B2E),
  bg3: Color(0xFF1B2440),
  line: Color(0x12FFFFFF),
  lineStrong: Color(0x24FFFFFF),
  text: Color(0xFFF2F1EA),
  textDim: Color(0xA8F2F1EA),
  textMute: Color(0x6BF2F1EA),
  accent: Color(0xFFC9A24A),
  accentSoft: Color(0xFFE6C68C),
  accentDeep: Color(0xFF8B6E2A),
  accentGlow: Color(0x59C9A24A),
  shadow: Color(0xFFC9A24A),
  swatches: [
    Color(0xFF070A14),
    Color(0xFF1B2440),
    Color(0xFFC9A24A),
    Color(0xFFE6C68C)
  ],
  cardGradient: [Color(0xFF1B2440), Color(0xFF0C1220), Color(0xFF070A14)],
  cardBorder: Color(0x24FFFFFF),
  cardShadowOpacity: 0.25,
  cardShadowRadius: 24,
  cardShadowOffsetY: 0,
  cardElevation: 10,
  rowActiveBg: Color(0xFF1B2440),
  compassGradient: [
    Color(0xFF141B2E),
    Color(0xFF070A14),
    Color(0xFF070A14),
    Color(0xFF141B2E),
    Color(0xFF1B2440)
  ],
  calendarCardBg: Color(0xFF0C1220),
  navBtnBg: Color(0xFF1B2440),
  toggleTrackBg: Color(0xFF141B2E),
  toggleThumbBg: Color(0xFF1B2440),
  rowIconBg: Color(0xFF1B2440),
);

const _ember = AppTheme(
  key: 'ember',
  name: 'Charcoal Ember',
  isDark: true,
  bg0: Color(0xFF0A0807),
  bg1: Color(0xFF14110F),
  bg2: Color(0xFF1F1A17),
  bg3: Color(0xFF2B2420),
  line: Color(0x0FFFFFFF),
  lineStrong: Color(0x1FFFFFFF),
  text: Color(0xFFF5EFE6),
  textDim: Color(0xA8F5EFE6),
  textMute: Color(0x66F5EFE6),
  accent: Color(0xFFE89A57),
  accentSoft: Color(0xFFF5C28F),
  accentDeep: Color(0xFFA05F2C),
  accentGlow: Color(0x59E89A57),
  shadow: Color(0xFFE89A57),
  swatches: [
    Color(0xFF0A0807),
    Color(0xFF2B2420),
    Color(0xFFE89A57),
    Color(0xFFF5C28F)
  ],
  cardGradient: [Color(0xFF2B2420), Color(0xFF14110F), Color(0xFF0A0807)],
  cardBorder: Color(0x1FFFFFFF),
  cardShadowOpacity: 0.25,
  cardShadowRadius: 24,
  cardShadowOffsetY: 0,
  cardElevation: 10,
  rowActiveBg: Color(0xFF2B2420),
  compassGradient: [
    Color(0xFF1F1A17),
    Color(0xFF0A0807),
    Color(0xFF0A0807),
    Color(0xFF1F1A17),
    Color(0xFF2B2420)
  ],
  calendarCardBg: Color(0xFF14110F),
  navBtnBg: Color(0xFF2B2420),
  toggleTrackBg: Color(0xFF1F1A17),
  toggleThumbBg: Color(0xFF2B2420),
  rowIconBg: Color(0xFF2B2420),
);

const _teal = AppTheme(
  key: 'teal',
  name: 'Inkstone Teal',
  isDark: true,
  bg0: Color(0xFF04090B),
  bg1: Color(0xFF0A1316),
  bg2: Color(0xFF102025),
  bg3: Color(0xFF162C33),
  line: Color(0x0FFFFFFF),
  lineStrong: Color(0x21FFFFFF),
  text: Color(0xFFEAF4F4),
  textDim: Color(0xA8EAF4F4),
  textMute: Color(0x66EAF4F4),
  accent: Color(0xFF5FB8B0),
  accentSoft: Color(0xFF9CD8D2),
  accentDeep: Color(0xFF2C6E68),
  accentGlow: Color(0x595FB8B0),
  shadow: Color(0xFF5FB8B0),
  swatches: [
    Color(0xFF04090B),
    Color(0xFF162C33),
    Color(0xFF5FB8B0),
    Color(0xFF9CD8D2)
  ],
  cardGradient: [Color(0xFF162C33), Color(0xFF0A1316), Color(0xFF04090B)],
  cardBorder: Color(0x21FFFFFF),
  cardShadowOpacity: 0.25,
  cardShadowRadius: 24,
  cardShadowOffsetY: 0,
  cardElevation: 10,
  rowActiveBg: Color(0xFF162C33),
  compassGradient: [
    Color(0xFF102025),
    Color(0xFF04090B),
    Color(0xFF04090B),
    Color(0xFF102025),
    Color(0xFF162C33)
  ],
  calendarCardBg: Color(0xFF0A1316),
  navBtnBg: Color(0xFF162C33),
  toggleTrackBg: Color(0xFF102025),
  toggleThumbBg: Color(0xFF162C33),
  rowIconBg: Color(0xFF162C33),
);

const _daylight = AppTheme(
  key: 'daylight',
  name: 'Sage Mist',
  isDark: false,
  bg0: Color(0xFFEDECEA),
  bg1: Color(0xFFF8F7F4),
  bg2: Color(0xFFE2E1DE),
  bg3: Color(0xFFD3D2CE),
  line: Color(0x17000000),
  lineStrong: Color(0x2E000000),
  text: Color(0xFF1A1A18),
  textDim: Color(0xFF1A1A18),
  textMute: Color(0xFF3D3D3A),
  accent: Color(0xFF1B7A4E),
  accentSoft: Color(0xFF27AE76),
  accentDeep: Color(0xFFDFF0E8),
  accentGlow: Color(0x1A1B7A4E),
  shadow: Color(0xFF000000),
  swatches: [
    Color(0xFFEDECEA),
    Color(0xFFD3D2CE),
    Color(0xFF1B7A4E),
    Color(0xFFDFF0E8)
  ],
  cardGradient: [Color(0xFFFFFFFF), Color(0xFFDFF0E8)],
  cardBorder: Color(0x0F000000),
  cardShadowOpacity: 0.04,
  cardShadowRadius: 4,
  cardShadowOffsetY: 1,
  cardElevation: 1,
  rowActiveBg: Color(0xFFDFF0E8),
  compassGradient: [
    Color(0xFFFFFFFF),
    Color(0xFFF5FBF8),
    Color(0xFFF5FBF8),
    Color(0xFFEBF7F2),
    Color(0xFFDFF0E8)
  ],
  calendarCardBg: Color(0xFFF4F9F7),
  navBtnBg: Color(0xFFF2F1EE),
  toggleTrackBg: Color(0xFFF2F1EE),
  toggleThumbBg: Color(0xFFDFF0E8),
  rowIconBg: Color(0xFFDFF0E8),
);

const _sky = AppTheme(
  key: 'sky',
  name: 'Sky Frost',
  isDark: false,
  bg0: Color(0xFFE8ECF2),
  bg1: Color(0xFFF4F7FB),
  bg2: Color(0xFFDCE3EE),
  bg3: Color(0xFFC8D2E0),
  line: Color(0x17000000),
  lineStrong: Color(0x2E000000),
  text: Color(0xFF181C24),
  textDim: Color(0xFF181C24),
  textMute: Color(0xFF3D4558),
  accent: Color(0xFF2563EB),
  accentSoft: Color(0xFF60A5FA),
  accentDeep: Color(0xFFDBEAFE),
  accentGlow: Color(0x1A2563EB),
  shadow: Color(0xFF000000),
  swatches: [
    Color(0xFFE8ECF2),
    Color(0xFFC8D2E0),
    Color(0xFF2563EB),
    Color(0xFFDBEAFE)
  ],
  cardGradient: [Color(0xFFFFFFFF), Color(0xFFDBEAFE)],
  cardBorder: Color(0x0F000000),
  cardShadowOpacity: 0.04,
  cardShadowRadius: 4,
  cardShadowOffsetY: 1,
  cardElevation: 1,
  rowActiveBg: Color(0xFFDBEAFE),
  compassGradient: [
    Color(0xFFFFFFFF),
    Color(0xFFEEF4FF),
    Color(0xFFEEF4FF),
    Color(0xFFE4EDFE),
    Color(0xFFDBEAFE)
  ],
  calendarCardBg: Color(0xFFEEF4FF),
  navBtnBg: Color(0xFFEDF0F5),
  toggleTrackBg: Color(0xFFEDF0F5),
  toggleThumbBg: Color(0xFFDBEAFE),
  rowIconBg: Color(0xFFDBEAFE),
);

const _rose = AppTheme(
  key: 'rose',
  name: 'Rose Quartz',
  isDark: false,
  bg0: Color(0xFFEEE8E8),
  bg1: Color(0xFFFAF6F6),
  bg2: Color(0xFFE4DADA),
  bg3: Color(0xFFD4C8C8),
  line: Color(0x17000000),
  lineStrong: Color(0x2E000000),
  text: Color(0xFF1E1818),
  textDim: Color(0xFF1E1818),
  textMute: Color(0xFF524646),
  accent: Color(0xFFB85C72),
  accentSoft: Color(0xFFD4899A),
  accentDeep: Color(0xFFFAE8ED),
  accentGlow: Color(0x1AB85C72),
  shadow: Color(0xFF000000),
  swatches: [
    Color(0xFFEEE8E8),
    Color(0xFFD4C8C8),
    Color(0xFFB85C72),
    Color(0xFFFAE8ED)
  ],
  cardGradient: [Color(0xFFFFFFFF), Color(0xFFFAE8ED)],
  cardBorder: Color(0x0F000000),
  cardShadowOpacity: 0.04,
  cardShadowRadius: 4,
  cardShadowOffsetY: 1,
  cardElevation: 1,
  rowActiveBg: Color(0xFFFAE8ED),
  compassGradient: [
    Color(0xFFFFFFFF),
    Color(0xFFFDF1F4),
    Color(0xFFFDF1F4),
    Color(0xFFF8E4EA),
    Color(0xFFFAE8ED)
  ],
  calendarCardBg: Color(0xFFFDF1F4),
  navBtnBg: Color(0xFFEDE5E5),
  toggleTrackBg: Color(0xFFEDE5E5),
  toggleThumbBg: Color(0xFFFAE8ED),
  rowIconBg: Color(0xFFFAE8ED),
);

const _sand = AppTheme(
  key: 'sand',
  name: 'Sand Beige',
  isDark: false,
  bg0: Color(0xFFEDE7DF),
  bg1: Color(0xFFFAF7F2),
  bg2: Color(0xFFE3DBD1),
  bg3: Color(0xFFD0C6BB),
  line: Color(0x17000000),
  lineStrong: Color(0x2E000000),
  text: Color(0xFF1E1A15),
  textDim: Color(0xFF1E1A15),
  textMute: Color(0xFF524A3A),
  accent: Color(0xFF9C7A42),
  accentSoft: Color(0xFFC4A070),
  accentDeep: Color(0xFFF5EDDA),
  accentGlow: Color(0x1A9C7A42),
  shadow: Color(0xFF000000),
  swatches: [
    Color(0xFFEDE7DF),
    Color(0xFFD0C6BB),
    Color(0xFF9C7A42),
    Color(0xFFF5EDDA)
  ],
  cardGradient: [Color(0xFFFFFFFF), Color(0xFFF5EDDA)],
  cardBorder: Color(0x0F000000),
  cardShadowOpacity: 0.04,
  cardShadowRadius: 4,
  cardShadowOffsetY: 1,
  cardElevation: 1,
  rowActiveBg: Color(0xFFF5EDDA),
  compassGradient: [
    Color(0xFFFFFFFF),
    Color(0xFFFBF6EE),
    Color(0xFFFBF6EE),
    Color(0xFFF5EDE0),
    Color(0xFFF5EDDA)
  ],
  calendarCardBg: Color(0xFFFBF6EE),
  navBtnBg: Color(0xFFEAE3DB),
  toggleTrackBg: Color(0xFFEAE3DB),
  toggleThumbBg: Color(0xFFF5EDDA),
  rowIconBg: Color(0xFFF5EDDA),
);

const Map<String, AppTheme> themes = {
  'cosmic': _cosmic,
  'midnight': _midnight,
  'ember': _ember,
  'teal': _teal,
  'daylight': _daylight,
  'sky': _sky,
  'rose': _rose,
  'sand': _sand,
};

const String defaultThemeKey = 'teal';

const List<String> darkThemeKeys = ['cosmic', 'midnight', 'ember', 'teal'];
const List<String> lightThemeKeys = ['daylight', 'sky', 'rose', 'sand'];

AppTheme getTheme(String key) => themes[key] ?? _teal;

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
