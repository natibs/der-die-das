import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/text_utils.dart';
import 'noun.dart';

/// Words fetched from the internet, stored on the device so the next lookup is
/// instant and works offline. Kept in shared_preferences as one JSON map.
class SavedWords {
  SavedWords(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      for (final j in (jsonDecode(raw) as List)) {
        final e = NounEntry.fromOfflineJson(j as Map<String, dynamic>);
        _byKey[foldGerman(e.word)] = e;
      }
    } catch (_) {
      // corrupt store: start fresh rather than crash
    }
  }

  static const _key = 'saved_words_v1';
  static const _max = 3000;
  final SharedPreferences _prefs;
  final _byKey = <String, NounEntry>{};

  int get length => _byKey.length;
  Iterable<String> get words => _byKey.values.map((e) => e.word);

  NounEntry? lookup(String word) => _byKey[foldGerman(word)];

  NounEntry? lookupPlural(String word) {
    final key = foldGerman(word);
    for (final e in _byKey.values) {
      if (e.plurals.any((p) => foldGerman(p) == key && foldGerman(p) != foldGerman(e.word))) return e;
    }
    return null;
  }

  Future<void> put(NounEntry e) async {
    final key = foldGerman(e.word);
    _byKey.remove(key);
    _byKey[key] = e; // most recent last
    while (_byKey.length > _max) {
      _byKey.remove(_byKey.keys.first);
    }
    await _prefs.setString(_key, jsonEncode([for (final v in _byKey.values) v.toJson()]));
  }
}
