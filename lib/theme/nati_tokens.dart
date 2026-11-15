import 'package:flutter/material.dart';

/// Raw palette, ported 1:1 from nati-ui-components `styles/tokens.scss`.
abstract final class NatiColors {
  static const basic50 = Color(0xFFF0F9FF);
  static const basic100 = Color(0xFFC6E8FF);
  static const basic200 = Color(0xFF72C6FF);
  static const basic300 = Color(0xFF1FA5FF);
  static const basic400 = Color(0xFF0079CA);
  static const basic500 = Color(0xFF004777);
  static const basic700 = Color(0xFF00365A);
  static const basic900 = Color(0xFF00253D);

  static const trinary500 = Color(0xFFF2F5EA);
  static const trinary600 = Color(0xFFC6D3A3);

  static const danger300 = Color(0xFFF19DB2);
  static const danger500 = Color(0xFFE75A7C);
  static const danger600 = Color(0xFFDF214F);

  static const success500 = Color(0xFF1F9D55);
  static const successDark = Color(0xFF3ECF8E);

  // neutral ramp (light) / inverted ramp (dark), see nati-ui-dark-theme mixin
  static const neutralLight = <int, Color>{
    0: Color(0xFFFFFFFF), 100: Color(0xFFF2F3F5), 300: Color(0xFFD0D4DB),
    400: Color(0xFF9AA1AC), 500: Color(0xFF6B7280), 700: Color(0xFF374151),
    900: Color(0xFF111827),
  };
  static const neutralDark = <int, Color>{
    0: Color(0xFF14161B), 100: Color(0xFF21252E), 300: Color(0xFF3A4150),
    400: Color(0xFF5B6472), 500: Color(0xFF8890A0), 700: Color(0xFFC7CCD6),
    900: Color(0xFFF5F6F8),
  };
}

/// Spacing / radius / control sizes from tokens.scss (rem -> logical px at 16px).
abstract final class NatiSize {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const radiusSm = 6.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;
  static const controlHeightMd = 44.0;
  static const controlPaddingXMd = 14.0;
  static const focusRingWidth = 3.0;
  static const fontXs = 12.0;
  static const fontSm = 13.0;
  static const fontMd = 15.0;
  static const fontLg = 17.0;
  static const quick = Duration(milliseconds: 120);
  static const maxContentWidth = 960.0;
}

/// Semantic, theme-dependent colors (nati tokens + the Deutsch-A1 app surface vars).
@immutable
class NatiTheme extends ThemeExtension<NatiTheme> {
  const NatiTheme({
    required this.isDark,
    required this.surface,
    required this.border,
    required this.inputBorder,
    required this.inputBorderHover,
    required this.text,
    required this.textMuted,
    required this.label,
    required this.placeholder,
    required this.glass,
    required this.primary,
    required this.onPrimary,
    required this.danger,
    required this.success,
    required this.der,
    required this.die,
    required this.das,
    required this.shadow,
  });

  final bool isDark;
  final Color surface;
  final Color border;
  final Color inputBorder;
  final Color inputBorderHover;
  final Color text;
  final Color textMuted;
  final Color label;
  final Color placeholder;
  final Color glass;
  final Color primary; // --nati-ui-color-basic-fill
  final Color onPrimary; // --nati-ui-color-basic-on-fill
  final Color danger;
  final Color success;
  final Color der;
  final Color die;
  final Color das;
  final List<BoxShadow> shadow;

  static NatiTheme of(BuildContext context) => Theme.of(context).extension<NatiTheme>()!;

  static final light = NatiTheme(
    isDark: false,
    surface: NatiColors.neutralLight[0]!,
    border: const Color(0xFFE1E5EE),
    inputBorder: NatiColors.neutralLight[300]!,
    inputBorderHover: NatiColors.neutralLight[400]!,
    text: NatiColors.neutralLight[900]!,
    textMuted: NatiColors.neutralLight[500]!,
    label: NatiColors.neutralLight[700]!,
    placeholder: NatiColors.neutralLight[400]!,
    glass: const Color(0xB8FFFFFF), // rgba(255,255,255,.72)
    primary: NatiColors.basic500,
    onPrimary: Colors.white,
    danger: NatiColors.danger600,
    success: NatiColors.success500,
    der: NatiColors.basic400,
    die: NatiColors.danger600,
    das: NatiColors.success500,
    shadow: const [
      BoxShadow(color: Color(0x14141828), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A141828), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  static final dark = NatiTheme(
    isDark: true,
    surface: const Color(0xFF1B1E29),
    border: const Color(0xFF2E3242),
    inputBorder: NatiColors.neutralDark[300]!,
    inputBorderHover: NatiColors.neutralDark[400]!,
    text: NatiColors.neutralDark[900]!,
    textMuted: const Color(0xFF9AA0B4),
    label: NatiColors.neutralDark[700]!,
    placeholder: NatiColors.neutralDark[400]!,
    glass: const Color(0xB812141C), // rgba(18,20,28,.72)
    primary: NatiColors.basic300,
    onPrimary: NatiColors.basic900,
    danger: NatiColors.danger300,
    success: NatiColors.successDark,
    der: NatiColors.basic200,
    die: NatiColors.danger300,
    das: NatiColors.successDark,
    shadow: const [
      BoxShadow(color: Color(0x73000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x4D000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  @override
  NatiTheme copyWith() => this;

  @override
  NatiTheme lerp(NatiTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return NatiTheme(
      isDark: t < 0.5 ? isDark : other.isDark,
      surface: c(surface, other.surface),
      border: c(border, other.border),
      inputBorder: c(inputBorder, other.inputBorder),
      inputBorderHover: c(inputBorderHover, other.inputBorderHover),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      label: c(label, other.label),
      placeholder: c(placeholder, other.placeholder),
      glass: c(glass, other.glass),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      der: c(der, other.der),
      die: c(die, other.die),
      das: c(das, other.das),
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}
