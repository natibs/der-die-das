import 'package:der_die_das/data/machine_translation.dart';
import 'package:der_die_das/data/noun.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('machine translations: strips quotes/dashes, rejects sentences and echoes', () {
    expect(cleanCandidates(['"אימא"', '-אימא.'], 'Mutter'), ['אימא']);
    expect(cleanCandidates(['-אני לא יודע מה זה.'], 'Leute'), isEmpty); // real MyMemory junk
    expect(cleanCandidates(['Mutter'], 'Mutter'), isEmpty);
    expect(cleanCandidates(['papillon', 'Papillon', 'lépidoptère'], 'Schmetterling'), ['papillon', 'lépidoptère']);
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
