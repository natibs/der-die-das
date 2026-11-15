import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/text_utils.dart';
import 'noun.dart';

/// Offline noun list: the most frequent German nouns + the Deutsch-A1 vocabulary
/// (assets/nouns.json, built by tool/build_common_nouns.py).
class LocalDictionary {
  LocalDictionary(List<NounEntry> entries)
      : _entries = entries,
        _byKey = {for (final e in entries) foldGerman(e.word): e},
        _byPlural = {
          for (final e in entries)
            for (final p in e.plurals)
              if (foldGerman(p) != foldGerman(e.word)) foldGerman(p): e,
        };

  final List<NounEntry> _entries;
  final Map<String, NounEntry> _byKey;
  final Map<String, NounEntry> _byPlural;

  static Future<LocalDictionary> load() async {
    final raw = await rootBundle.loadString('assets/nouns.json');
    return LocalDictionary.fromJson(raw);
  }

  factory LocalDictionary.fromJson(String raw) => LocalDictionary([
        for (final j in jsonDecode(raw) as List) NounEntry.fromOfflineJson(j as Map<String, dynamic>),
      ]);

  int get length => _entries.length;

  NounEntry? lookup(String word) => _byKey[foldGerman(word)];

  /// The noun whose plural is [word] ("Äpfel" -> Apfel), if any.
  NounEntry? lookupPlural(String word) => _byPlural[foldGerman(word)];

  /// Prefix matches first, then words containing the text.
  List<String> suggest(String text, {int limit = 6}) {
    final q = foldGerman(text.trim());
    if (q.isEmpty) return const [];
    final starts = <String>[], contains = <String>[];
    for (final e in _entries) {
      final k = foldGerman(e.word);
      if (k == q) continue;
      if (k.startsWith(q)) {
        starts.add(e.word);
      } else if (q.length >= 3 && k.contains(q)) {
        contains.add(e.word);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }
}
