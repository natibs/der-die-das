/// Translation target languages (codes as used by de.wiktionary's {{Ü|code|...}}).
/// English and German are deliberately absent: English is always shown, German is the source.
class Language {
  const Language(this.code, this.name, this.native, {this.rtl = false});
  final String code;
  final String name;
  final String native;
  final bool rtl;

  String get label => name == native ? name : '$name · $native';
}

const defaultLanguageCode = 'he';

const languages = <Language>[
  Language('he', 'Hebrew', 'עברית', rtl: true),
  Language('af', 'Afrikaans', 'Afrikaans'),
  Language('sq', 'Albanian', 'Shqip'),
  Language('ar', 'Arabic', 'العربية', rtl: true),
  Language('hy', 'Armenian', 'Հայերեն'),
  Language('az', 'Azerbaijani', 'Azərbaycanca'),
  Language('eu', 'Basque', 'Euskara'),
  Language('bn', 'Bengali', 'বাংলা'),
  Language('bs', 'Bosnian', 'Bosanski'),
  Language('bg', 'Bulgarian', 'Български'),
  Language('ca', 'Catalan', 'Català'),
  Language('zh', 'Chinese', '中文'),
  Language('hr', 'Croatian', 'Hrvatski'),
  Language('cs', 'Czech', 'Čeština'),
  Language('da', 'Danish', 'Dansk'),
  Language('nl', 'Dutch', 'Nederlands'),
  Language('eo', 'Esperanto', 'Esperanto'),
  Language('et', 'Estonian', 'Eesti'),
  Language('fi', 'Finnish', 'Suomi'),
  Language('fr', 'French', 'Français'),
  Language('gl', 'Galician', 'Galego'),
  Language('ka', 'Georgian', 'ქართული'),
  Language('el', 'Greek', 'Ελληνικά'),
  Language('hi', 'Hindi', 'हिन्दी'),
  Language('hu', 'Hungarian', 'Magyar'),
  Language('is', 'Icelandic', 'Íslenska'),
  Language('id', 'Indonesian', 'Bahasa Indonesia'),
  Language('ga', 'Irish', 'Gaeilge'),
  Language('it', 'Italian', 'Italiano'),
  Language('ja', 'Japanese', '日本語'),
  Language('kk', 'Kazakh', 'Қазақша'),
  Language('ko', 'Korean', '한국어'),
  Language('la', 'Latin', 'Latina'),
  Language('lv', 'Latvian', 'Latviešu'),
  Language('lt', 'Lithuanian', 'Lietuvių'),
  Language('lb', 'Luxembourgish', 'Lëtzebuergesch'),
  Language('mk', 'Macedonian', 'Македонски'),
  Language('ms', 'Malay', 'Bahasa Melayu'),
  Language('nb', 'Norwegian', 'Norsk bokmål'),
  Language('fa', 'Persian', 'فارسی', rtl: true),
  Language('pl', 'Polish', 'Polski'),
  Language('pt', 'Portuguese', 'Português'),
  Language('ro', 'Romanian', 'Română'),
  Language('ru', 'Russian', 'Русский'),
  Language('sr', 'Serbian', 'Српски'),
  Language('sk', 'Slovak', 'Slovenčina'),
  Language('sl', 'Slovenian', 'Slovenščina'),
  Language('es', 'Spanish', 'Español'),
  Language('sw', 'Swahili', 'Kiswahili'),
  Language('sv', 'Swedish', 'Svenska'),
  Language('tl', 'Tagalog', 'Tagalog'),
  Language('ta', 'Tamil', 'தமிழ்'),
  Language('th', 'Thai', 'ไทย'),
  Language('tr', 'Turkish', 'Türkçe'),
  Language('uk', 'Ukrainian', 'Українська'),
  Language('ur', 'Urdu', 'اردو', rtl: true),
  Language('vi', 'Vietnamese', 'Tiếng Việt'),
  Language('cy', 'Welsh', 'Cymraeg'),
  Language('yi', 'Yiddish', 'ייִדיש', rtl: true),
];

Language languageFor(String code) =>
    languages.firstWhere((l) => l.code == code, orElse: () => languages.first);
