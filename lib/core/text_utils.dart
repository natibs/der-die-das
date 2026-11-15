import '../data/noun.dart';

/// Strips Hebrew vowel points / cantillation marks (keeps maqaf and punctuation).
String stripNiqqud(String s) => s.replaceAll(RegExp(r'[֑-ׇֽֿׁׂׅׄ]'), '');

/// Case- and ß/ss-insensitive key (Swiss spelling: Strasse == Straße).
String foldGerman(String s) => s.toLowerCase().replaceAll('ß', 'ss');

class LookupQuery {
  const LookupQuery(this.word, this.typedArticle);
  final String word;

  /// If the user typed "die Hund", we remember the guess and grade it.
  final Gender? typedArticle;
}

LookupQuery? parseQuery(String input) {
  var s = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (RegExp(r'^(der|die|das)$', caseSensitive: false).hasMatch(s)) return null; // just an article
  Gender? typed;
  final m = RegExp(r'^(der|die|das)\s+(.+)$', caseSensitive: false).firstMatch(s);
  if (m != null) {
    typed = Gender.fromArticle(m.group(1)!.toLowerCase());
    s = m.group(2)!;
  }
  s = s.replaceAll(RegExp(r'[.,;:!?]+$'), '').trim();
  if (s.isEmpty) return null;
  // German nouns are capitalized; Wiktionary titles are case-sensitive.
  s = s[0].toUpperCase() + s.substring(1);
  return LookupQuery(s, typed);
}
