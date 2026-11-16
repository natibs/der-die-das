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

const _namedEntities = {
  'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
  'ndash': '–', 'mdash': '—', 'lsquo': '‘', 'rsquo': '’', 'ldquo': '“', 'rdquo': '”',
};

/// Decodes HTML entities (&apos;, &#39;, &#x27;, &amp;...) that some
/// translation APIs return inside plain-text results.
String decodeHtmlEntities(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(RegExp(r'&(#[xX][0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final e = m[1]!;
    if (e.startsWith('#')) {
      final hex = e.length > 1 && (e[1] == 'x' || e[1] == 'X');
      final code = int.tryParse(e.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
      return code == null || code > 0x10FFFF ? m[0]! : String.fromCharCode(code);
    }
    return _namedEntities[e.toLowerCase()] ?? m[0]!;
  });
}
