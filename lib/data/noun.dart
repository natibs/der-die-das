enum Gender {
  masculine('der', 'masculine', 'זכר'),
  feminine('die', 'feminine', 'נקבה'),
  neuter('das', 'neuter', 'סתמי');

  const Gender(this.article, this.label, this.labelHe);
  final String article;
  final String label;
  final String labelHe;

  static Gender? fromCode(String? code) => switch (code?.trim()) {
        'm' => Gender.masculine,
        'f' => Gender.feminine,
        'n' => Gender.neuter,
        _ => null,
      };

  static Gender? fromArticle(String article) => switch (article) {
        'der' => Gender.masculine,
        'die' => Gender.feminine,
        'das' => Gender.neuter,
        _ => null,
      };
}

enum NounSource {
  a1Vocabulary, // curated, bundled
  offlineList, // bundled, built from Wiktionary (tool/build_common_nouns.py)
  wiktionary, // fetched live
  saved, // fetched earlier, now stored on this device
}

class NounEntry {
  const NounEntry({
    required this.word,
    required this.genders,
    required this.plurals,
    required this.english,
    required this.translations,
    required this.source,
    this.pluralOnly = false,
    this.complete = false,
    this.machine = const {},
    this.typedPlural,
  });

  /// Set when the user looked the word up by its plural ("Hunde" -> Hund):
  /// the typed form. The card shows the singular and says so. Not persisted.
  final String? typedPlural;

  /// Same entry, marked as found through its plural [typed].
  NounEntry asPluralMatch(String typed) => _copy(typedPlural: typed);

  /// Language code -> translator name, for translations that came from a
  /// machine translator (MyMemory/LibreTranslate) rather than Wiktionary.
  final Map<String, String> machine;

  /// True when [translations] already holds everything Wiktionary has, so a
  /// missing language means "no translation exists" - no point going online.
  final bool complete;

  final String word;
  final List<Gender> genders;

  /// Empty = no plural (singulare tantum).
  final List<String> plurals;
  final bool pluralOnly;
  final List<String> english;

  /// Translations by de.wiktionary language code ('he', 'fr', ...).
  final Map<String, List<String>> translations;
  final NounSource source;

  List<String> translationsFor(String code) => translations[code] ?? const [];

  NounEntry withTranslations(Map<String, List<String>> extra, {bool? complete}) => NounEntry(
        word: word,
        genders: genders,
        plurals: plurals,
        pluralOnly: pluralOnly,
        english: english.isNotEmpty ? english : (extra['en'] ?? const []),
        translations: {...extra, ...translations}, // curated A1 values win
        source: source,
        complete: complete ?? (extra.length > 1 || this.complete),
        machine: machine,
        typedPlural: typedPlural,
      );

  NounEntry withMachineTranslation(String code, List<String> words, String provider) => NounEntry(
        word: word,
        genders: genders,
        plurals: plurals,
        pluralOnly: pluralOnly,
        english: code == 'en' ? words : english,
        translations: code == 'en' ? translations : {...translations, code: words},
        source: source,
        complete: complete,
        machine: {...machine, code: provider},
        typedPlural: typedPlural,
      );

  NounEntry _copy({String? typedPlural}) => NounEntry(
        word: word,
        genders: genders,
        plurals: plurals,
        pluralOnly: pluralOnly,
        english: english,
        translations: translations,
        source: source,
        complete: complete,
        machine: machine,
        typedPlural: typedPlural,
      );

  /// Saved form: the base (singular) entry, without the plural-match marker.
  NounEntry asSaved() => NounEntry(
        word: word,
        genders: genders,
        plurals: plurals,
        pluralOnly: pluralOnly,
        english: english,
        translations: translations,
        source: source == NounSource.wiktionary ? NounSource.saved : source,
        complete: complete,
        machine: machine,
      );

  /// Same shape as assets/nouns.json (plus 'mt' and 'src' for saved entries).
  Map<String, dynamic> toJson() => {
        'word': word,
        'genders': [for (final g in genders) g.name[0]], // m / f / n
        'plural': plurals.isEmpty ? null : plurals.first,
        if (pluralOnly) 'pluralOnly': true,
        'en': english,
        'tr': translations,
        'src': switch (source) { NounSource.a1Vocabulary => 'a1', NounSource.offlineList => 'wiktionary', _ => 'saved' },
        'complete': complete,
        if (machine.isNotEmpty) 'mt': machine,
      };

  /// Entry from the bundled offline list (assets/nouns.json).
  factory NounEntry.fromOfflineJson(Map<String, dynamic> j) {
    final plural = j['plural'] as String?;
    final tr = (j['tr'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, List<String>.from(v as List)));
    final a1 = j['src'] == 'a1';
    final saved = j['src'] == 'saved';
    return NounEntry(
      word: j['word'] as String,
      genders: [for (final g in (j['genders'] as List)) Gender.fromCode(g as String)].whereType<Gender>().toList(),
      plurals: plural == null ? const [] : [plural],
      pluralOnly: j['pluralOnly'] == true,
      english: List<String>.from(j['en'] as List),
      translations: tr,
      source: a1 ? NounSource.a1Vocabulary : (saved ? NounSource.saved : NounSource.offlineList),
      complete: j['complete'] is bool ? j['complete'] as bool : !a1,
      machine: (j['mt'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, '$v')),
    );
  }

  /// Grades a typed article guess. Plural-only nouns take "die".
  bool? isCorrectGuess(Gender? guess) {
    if (guess == null) return null;
    // Plurals (typed plural form or plural-only nouns) always take "die".
    if (pluralOnly || typedPlural != null) return guess == Gender.feminine;
    return genders.contains(guess);
  }
}
