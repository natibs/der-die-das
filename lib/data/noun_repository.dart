import '../core/text_utils.dart';
import 'local_dictionary.dart';
import 'machine_translation.dart';
import 'noun.dart';
import 'saved_words.dart';
import 'wiktionary.dart';

/// Where a lookup goes, in order:
///  1. words saved on this device (fetched before) and the bundled offline list
///     - no network at all when they already have what's needed;
///  2. Wiktionary for words that aren't there (article, plural, translations);
///  3. MyMemory, then LibreTranslate, only when no translation exists for the
///     selected language (or English).
/// Anything fetched is saved to the device for next time.
class NounRepository {
  NounRepository(this.local, this.online, {required this.saved, required this.translators});
  final LocalDictionary local;
  final WiktionaryClient online;
  final SavedWords saved;
  final TranslatorChain translators;
  final _cache = <String, NounEntry?>{};

  int get offlineCount => local.length + saved.length;

  /// Returns null when the word isn't a German noun. Throws [LookupOfflineException]
  /// only when the word isn't stored offline and the network is unreachable.
  Future<NounEntry?> lookup(String word, {String language = 'he'}) async {
    final exact = saved.lookup(word) ?? local.lookup(word);
    // Typed a plural ("Äpfel")? Use its singular, marked so the card says so.
    final viaPlural = exact == null ? (saved.lookupPlural(word) ?? local.lookupPlural(word)) : null;
    final stored = exact ?? viaPlural?.asPluralMatch(word);
    var changed = false;
    NounEntry entry;

    if (stored == null) {
      final fetched = await _wiktionary(word); // may throw offline
      if (fetched == null) return null;
      entry = fetched;
      changed = true;
    } else {
      entry = stored;
      if (!entry.complete && !entry.translations.containsKey(language)) {
        // A1 entries only carry Hebrew: borrow the rest from Wiktionary.
        try {
          final extra = await _wiktionary(entry.word); // the singular, even if a plural was typed
          if (extra != null) {
            entry = entry.withTranslations(extra.translations, complete: true);
            changed = true;
          }
        } on LookupOfflineException {
          // offline: still show article + plural
        }
      }
    }

    // Machine-translation fallback, at most once per word+language
    // (a recorded empty list means "already tried, nothing found").
    final wanted = <String>{
      if (entry.english.isEmpty && !entry.translations.containsKey('en')) 'en',
      if (!entry.translations.containsKey(language)) language,
    };
    for (final code in wanted) {
      try {
        final r = await translators.translate(entry.word, code);
        entry = r == null
            ? entry.withTranslations({code: const []}, complete: entry.complete)
            : entry.withMachineTranslation(code, r.words, r.provider);
        changed = true;
      } on LookupOfflineException {
        break; // try again next time we're online
      }
    }

    if (changed) await saved.put(entry.asSaved());
    return entry;
  }

  List<String> suggest(String text, {int limit = 6}) {
    final q = foldGerman(text.trim());
    if (q.isEmpty) return const [];
    final fromSaved = [for (final w in saved.words) if (foldGerman(w).startsWith(q) && foldGerman(w) != q) w];
    final out = <String>[...fromSaved.take(limit)];
    for (final w in local.suggest(text, limit: limit)) {
      if (out.length >= limit) break;
      if (!out.any((o) => foldGerman(o) == foldGerman(w))) out.add(w);
    }
    return out;
  }

  Future<NounEntry?> _wiktionary(String word) async {
    final key = foldGerman(word);
    if (_cache.containsKey(key)) return _cache[key];
    final result = await online.lookup(word);
    _cache[key] = result;
    return result;
  }
}
