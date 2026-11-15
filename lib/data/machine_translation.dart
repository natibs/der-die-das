import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wiktionary.dart' show LookupOfflineException;

/// Fallback translators, used only when Wiktionary has no translation for the
/// selected language. Tried in order until one returns something usable.
abstract class Translator {
  String get name;

  /// Returns up to 2 clean single-word-ish translations, or [] if none.
  /// Throws [LookupOfflineException] when the network is unreachable.
  Future<List<String>> translate(String germanNoun, String targetCode);
}

class TranslatorChain {
  TranslatorChain(this.translators);
  final List<Translator> translators;

  /// (translations, provider name) or null if no provider found anything.
  Future<({List<String> words, String provider})?> translate(String word, String code) async {
    for (final t in translators) {
      final words = await t.translate(word, code);
      if (words.isNotEmpty) return (words: words, provider: t.name);
    }
    return null;
  }
}

/// Keeps a translation only if it looks like a word, not a sentence or junk.
List<String> cleanCandidates(Iterable<String> raw, String source, {int limit = 2}) {
  final out = <String>[];
  for (var s in raw) {
    s = s
        .replaceAll(RegExp('["“”„«»‚‘’]'), '')
        .replaceAll(RegExp(r'^[\s\-–—.,;:!?¿¡]+|[\s\-–—.,;:!?¿¡]+$'), '')
        .trim();
    if (s.isEmpty || s.length > 40) continue;
    if (RegExp(r'\d').hasMatch(s)) continue;
    if (s.split(RegExp(r'\s+')).length > 3) continue; // a phrase, not a noun
    if (s.toLowerCase() == source.toLowerCase()) continue; // untranslated echo
    if (!out.any((o) => o.toLowerCase() == s.toLowerCase())) out.add(s);
    if (out.length >= limit) break;
  }
  return out;
}

/// MyMemory (api.mymemory.translated.net): free, no key, ~5000 chars/day.
/// Its corpus is noisy (subtitles), so only exact-segment matches are trusted.
class MyMemoryTranslator implements Translator {
  MyMemoryTranslator({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  String get name => 'MyMemory';

  static const _codes = {'nb': 'no', 'zh': 'zh-CN'};

  @override
  Future<List<String>> translate(String word, String code) async {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': word,
      'langpair': 'de|${_codes[code] ?? code}',
    });
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const LookupOfflineException();
    }
    if (res.statusCode != 200) return const [];
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['quotaFinished'] == true) return const [];
      final norm = word.toLowerCase();
      final matches = [
        for (final m in (j['matches'] as List? ?? const []))
          if (m is Map && (m['segment'] as String?)?.trim().toLowerCase() == norm) m,
      ]..sort((a, b) {
          int n(Object? v) => int.tryParse('$v') ?? 0;
          final q = n(b['quality']).compareTo(n(a['quality']));
          return q != 0 ? q : n(b['usage-count']).compareTo(n(a['usage-count']));
        });
      final list = cleanCandidates([for (final m in matches) '${m['translation']}'], word);
      return [for (final w in list) _lowerFirst(w, code)];
    } catch (_) {
      return const [];
    }
  }
}

/// LibreTranslate. libretranslate.com requires a (paid) API key; self-hosted
/// servers don't. Configure at build time:
///   flutter run --dart-define=LIBRETRANSLATE_URL=https://libretranslate.com --dart-define=LIBRETRANSLATE_KEY=xxxx
/// Skipped entirely when no key/URL is configured.
class LibreTranslateTranslator implements Translator {
  LibreTranslateTranslator({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _url = String.fromEnvironment('LIBRETRANSLATE_URL', defaultValue: 'https://libretranslate.com');
  static const _key = String.fromEnvironment('LIBRETRANSLATE_KEY');
  static bool get configured => _key.isNotEmpty || !_url.contains('libretranslate.com');

  @override
  String get name => 'LibreTranslate';

  @override
  Future<List<String>> translate(String word, String code) async {
    if (!configured) return const [];
    final http.Response res;
    try {
      res = await _client
          .post(Uri.parse('$_url/translate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'q': word, 'source': 'de', 'target': code, 'format': 'text', if (_key.isNotEmpty) 'api_key': _key}))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const LookupOfflineException();
    }
    if (res.statusCode != 200) return const [];
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final list = cleanCandidates(['${j['translatedText'] ?? ''}'], word);
      return [for (final w in list) _lowerFirst(w, code)];
    } catch (_) {
      return const [];
    }
  }
}

/// Machine translators capitalize single words ("Papillon"); nouns are only
/// capitalized in German, so lower-case the first letter for Latin/Cyrillic/Greek.
String _lowerFirst(String w, String code) {
  if (w.isEmpty) return w;
  final first = w[0];
  final rest = w.substring(1);
  final simpleCase = first.toLowerCase() != first.toUpperCase();
  return simpleCase && rest == rest.toLowerCase() ? first.toLowerCase() + rest : w;
}
