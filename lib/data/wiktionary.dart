import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/text_utils.dart';
import 'noun.dart';

class LookupOfflineException implements Exception {
  const LookupOfflineException();
}

/// Looks nouns up on de.wiktionary.org (gender, plural, en + he translations).
class WiktionaryClient {
  WiktionaryClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _ua = 'DerDieDas/0.1 (Flutter; https://github.com/natibs)';

  Future<NounEntry?> lookup(String word) async {
    final candidates = <String>[word];
    // Swiss spelling: try "Strasse" -> "Straße" if the ss-form has no page.
    final i = word.lastIndexOf('ss');
    if (i > 0) candidates.add('${word.substring(0, i)}ß${word.substring(i + 2)}');

    for (final c in candidates) {
      final page = await _fetch(c);
      if (page == null) continue;
      final entry = WiktionaryParser.parse(page.title, page.wikitext);
      if (entry != null) return entry;

      // An inflected form ("Hunde"): follow it to the base noun, and accept
      // it only if the typed word really is one of that noun's plurals.
      final base = WiktionaryParser.baseFormOf(page.wikitext);
      if (base != null && foldGerman(base) != foldGerman(c)) {
        final basePage = await _fetch(base);
        final baseEntry = basePage == null ? null : WiktionaryParser.parse(basePage.title, basePage.wikitext);
        if (baseEntry != null && baseEntry.plurals.any((p) => foldGerman(p) == foldGerman(page.title))) {
          return baseEntry.asPluralMatch(page.title);
        }
      }
    }
    return null;
  }

  Future<({String title, String wikitext})?> _fetch(String title) async {
    final uri = Uri.https('de.wiktionary.org', '/w/api.php', {
      'action': 'query',
      'prop': 'revisions',
      'rvprop': 'content',
      'rvslots': 'main',
      'format': 'json',
      'formatversion': '2',
      'redirects': '1',
      'origin': '*',
      'titles': title,
    });
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: kIsWeb ? {'Api-User-Agent': _ua} : {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const LookupOfflineException();
    }
    if (res.statusCode != 200) throw const LookupOfflineException();
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final pages = (json['query']?['pages'] as List?) ?? const [];
      if (pages.isEmpty) return null;
      final page = pages.first as Map<String, dynamic>;
      if (page['missing'] == true || page['invalid'] == true) return null;
      final content = page['revisions']?[0]?['slots']?['main']?['content'] as String?;
      if (content == null) return null;
      return (title: page['title'] as String? ?? title, wikitext: content);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// Pure wikitext parser, unit-tested in test/wiktionary_parser_test.dart.
abstract final class WiktionaryParser {
  static final _level2 = RegExp(r'^==[^=].*$', multiLine: true);
  static final _level3 = RegExp(r'^===([^=].*?)===\s*$', multiLine: true);

  static NounEntry? parse(String title, String wikitext) {
    final german = _germanSection(wikitext);
    if (german == null) return null;
    final noun = _nounSubsection(german);
    if (noun == null) return null;

    final params = templateParams(noun.body, 'Deutsch Substantiv Übersicht');
    final genders = <Gender>[];
    if (params != null) {
      for (final k in params.keys.where((k) => RegExp(r'^Genus( \d)?$').hasMatch(k)).toList()..sort()) {
        final g = Gender.fromCode(params[k]);
        if (g != null && !genders.contains(g)) genders.add(g);
      }
    }
    if (genders.isEmpty) {
      for (final m in RegExp(r'\{\{([mfn])\}\}').allMatches(noun.heading)) {
        final g = Gender.fromCode(m.group(1));
        if (g != null && !genders.contains(g)) genders.add(g);
      }
    }

    final plurals = <String>[];
    var singular = title;
    if (params != null) {
      final keys = params.keys.where((k) => RegExp(r'^Nominativ Plural( \d)?$').hasMatch(k)).toList()..sort();
      for (final k in keys) {
        final v = cleanValue(params[k]!);
        if (_isForm(v) && !plurals.contains(v)) plurals.add(v);
      }
      final sg = params['Nominativ Singular'] ?? params['Nominativ Singular 1'];
      if (sg != null) singular = cleanValue(sg);
    }
    final pluralOnly = params != null && !_isForm(singular) && plurals.isNotEmpty;
    if (genders.isEmpty && !pluralOnly) return null;

    return NounEntry(
      word: pluralOnly ? plurals.first : (_isForm(singular) ? singular : title),
      genders: pluralOnly ? const [] : genders,
      plurals: plurals,
      pluralOnly: pluralOnly,
      english: translations(noun.body, 'en'),
      translations: allTranslations(noun.body),
      source: NounSource.wiktionary,
    );
  }

  static bool _isForm(String v) => v.isNotEmpty && v != '—' && v != '-' && v != '–';

  static String? _germanSection(String text) {
    final start = RegExp(r'^==[^=].*\(\{\{Sprache\|Deutsch\}\}\).*$', multiLine: true).firstMatch(text);
    if (start == null) return null;
    final next = _level2.allMatches(text, start.end).firstOrNull;
    return text.substring(start.start, next?.start ?? text.length);
  }

  static ({String heading, String body})? _nounSubsection(String section) {
    final headings = _level3.allMatches(section).toList();
    for (var i = 0; i < headings.length; i++) {
      final h = headings[i].group(1)!;
      if (!h.contains('{{Wortart|Substantiv|Deutsch}}')) continue;
      // skip proper names (Eigenname/Nachname/Vorname/Toponym) flagged in the same heading
      if (RegExp(r'Wortart\|(Eigenname|Nachname|Vorname|Toponym)').hasMatch(h)) continue;
      final end = i + 1 < headings.length ? headings[i + 1].start : section.length;
      return (heading: h, body: section.substring(headings[i].end, end));
    }
    return null;
  }

  /// For an inflected-form page ("Hunde": `=== {{Wortart|Deklinierte Form|Deutsch}} ===`
  /// with `{{Grundformverweis Dekl|Hund}}`), the base word; otherwise null.
  static String? baseFormOf(String wikitext) {
    final german = _germanSection(wikitext);
    if (german == null || !german.contains('{{Wortart|Deklinierte Form|Deutsch}}')) return null;
    final m = RegExp(r'\{\{Grundformverweis Dekl\|([^|}]+)').firstMatch(german);
    final base = m == null ? null : cleanValue(m.group(1)!);
    return base == null || base.isEmpty ? null : base;
  }

  /// Returns `name`'s parameters (`|key=value`), respecting nested {{ }} / [[ ]].
  static Map<String, String>? templateParams(String text, String name) {
    final start = text.indexOf('{{$name');
    if (start < 0) return null;
    var depth = 0, i = start;
    final parts = <String>[];
    var buf = StringBuffer();
    while (i < text.length) {
      final two = i + 1 < text.length ? text.substring(i, i + 2) : '';
      if (two == '{{' || two == '[[') {
        depth++;
        if (depth > 1) buf.write(two);
        i += 2;
        continue;
      }
      if (two == '}}' || two == ']]') {
        depth--;
        if (depth == 0) break;
        buf.write(two);
        i += 2;
        continue;
      }
      if (text[i] == '|' && depth == 1) {
        parts.add(buf.toString());
        buf = StringBuffer();
      } else {
        buf.write(text[i]);
      }
      i++;
    }
    parts.add(buf.toString());
    final out = <String, String>{};
    for (final p in parts.skip(1)) {
      final eq = p.indexOf('=');
      if (eq <= 0) continue;
      out[p.substring(0, eq).trim()] = p.substring(eq + 1).trim();
    }
    return out;
  }

  static String cleanValue(String v) => v
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<ref[^>]*/>'), '')
      .replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true), '')
      .replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m.group(1)!)
      .replaceAll('&nbsp;', ' ')
      .trim();

  // `*{{he}}: ...` / `*:{{en}} [US]: ...` - the language whose translations follow.
  static final _langLine = RegExp(r'^\*:?\s*\{\{([a-z-]{2,12})\}\}(.*)$', multiLine: true);
  // {{Ü|fr|chien}}, {{Üt|ru|собака|sobaka}}, {{Üxx4|ar|...}}
  static final _uItem = RegExp(r'\{\{Ü(?:t|xx\d)?\|([a-z-]{2,12})\|([^|}]+)');
  // Right-to-left scripts use script templates instead: {{Hebr|אם|v=אֵם|d-heb=ʾēm|Ü}}, {{Arab|...|Ü}}
  static final _scriptItem = RegExp(r'\{\{(?:Hebr|Arab|Pers|Urdu|Jidd)\|([^|}]+)');

  /// Every language in the translation table: code -> up to [limit] words.
  static Map<String, List<String>> allTranslations(String text, {int limit = 4}) {
    final out = <String, List<String>>{};
    void add(String code, String raw) {
      var w = cleanValue(raw);
      if (code == 'he' || code == 'yi') w = stripNiqqud(w);
      final list = out.putIfAbsent(code, () => <String>[]);
      if (w.isNotEmpty && !list.contains(w) && list.length < limit) list.add(w);
    }

    for (final l in _langLine.allMatches(text)) {
      final lineCode = l.group(1)!;
      final body = l.group(2)!;
      for (final m in _uItem.allMatches(body)) {
        add(m.group(1)!, m.group(2)!);
      }
      for (final m in _scriptItem.allMatches(body)) {
        add(lineCode, m.group(1)!);
      }
    }
    out.removeWhere((_, v) => v.isEmpty);
    return out;
  }

  /// Translations for one language (see [allTranslations]).
  static List<String> translations(String text, String lang, {int limit = 4}) =>
      allTranslations(text, limit: limit)[lang] ?? const [];

}
