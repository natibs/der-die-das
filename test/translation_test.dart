import 'package:der_die_das/core/text_utils.dart';
import 'package:der_die_das/data/machine_translation.dart';
import 'package:der_die_das/data/noun.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('machine translations: strips quotes/dashes, rejects sentences and echoes', () {
    expect(cleanCandidates(['"אימא"', '-אימא.'], 'Mutter'), ['אימא']);
    expect(cleanCandidates(['-אני לא יודע מה זה.'], 'Leute'), isEmpty); // real MyMemory junk
    expect(cleanCandidates(['Mutter'], 'Mutter'), isEmpty);
    expect(cleanCandidates(['ג&apos;ונגל', 'ג&#39;ונגל', "ג'ונגל"], 'Jungle'), ['ג\u05F3ונגל']); // entities, Latin apostrophe → geresh
    expect(cleanCandidates(['aujourd’hui', '‘Tom &amp; Jerry’'], 'Heute'), ['aujourd’hui', 'Tom & Jerry']);
    expect(cleanCandidates(['papillon', 'Papillon', 'lépidoptère'], 'Schmetterling'), ['papillon', 'lépidoptère']);
  });

  test('words saved with HTML entities are repaired on load', () {
    final e = NounEntry.fromOfflineJson({
      'word': 'Jungle', 'genders': ['m'], 'en': ['jungle'], 'src': 'saved',
      'tr': {'he': ['ג&apos;ונגל']}, 'mt': {'he': 'MyMemory'},
    });
    expect(e.translations['he'], ['ג\u05F3ונגל']);
  });

  test('Hebrew geresh and gershayim', () {
    expect(hebrewPunctuation('צה"ל'), 'צה\u05F4ל');
    expect(hebrewPunctuation("צ'יפס"), 'צ\u05F3יפס');
    expect(hebrewPunctuation("aujourd'hui"), "aujourd'hui");
  });

  test('saved entries survive a JSON round trip', () {
    const e = NounEntry(
      word: 'Mutter',
      genders: [Gender.feminine],
      plurals: ['Mütter'],
      english: ['mother'],
      translations: {'he': ['אם']},
      source: NounSource.wiktionary,
      complete: true,
    );
    final saved = e.withMachineTranslation('fr', ['mère'], 'MyMemory').asSaved();
    final back = NounEntry.fromOfflineJson(saved.toJson());
    expect(back.source, NounSource.saved);
    expect(back.genders, [Gender.feminine]);
    expect(back.plurals, ['Mütter']);
    expect(back.translationsFor('fr'), ['mère']);
    expect(back.machine, {'fr': 'MyMemory'});
    expect(back.complete, isTrue);
  });
}
