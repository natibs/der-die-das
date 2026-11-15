import 'package:der_die_das/data/noun.dart';
import 'package:der_die_das/data/wiktionary.dart';
import 'package:flutter_test/flutter_test.dart';

const _hund = '''
{{Siehe auch|[[hund]]}}
== Hund ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{m}} ===

{{Deutsch Substantiv Übersicht
|Genus=m
|Nominativ Singular=Hund
|Nominativ Plural=Hunde
|Genitiv Singular=Hundes
|Genitiv Singular*=Hunds
|Bild=Dog.jpg|mini|1|ein [[Hund]]
}}

==== {{Übersetzungen}} ====
{{Ü-Tabelle|1|G=Haustier|Ü-Liste=
*{{en}}: [1] {{Ü|en|dog}}; [1a] {{Ü|en|hound}}
*{{fr}}: [1] {{Ü|fr|chien}} {{m}}
*{{he}}: [1] {{Üt|he|כֶּלֶב|kelev}} {{m}}
}}

== Hund ({{Sprache|Dänisch}}) ==
=== {{Wortart|Substantiv|Dänisch}}, {{u}} ===
*{{en}}: {{Ü|en|wrong}}
''';

const _eltern = '''
== Eltern ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{Pl.}} ===
{{Deutsch Substantiv Übersicht
|Genus=0
|Nominativ Singular=—
|Nominativ Plural=Eltern
}}
*{{en}}: [1] {{Ü|en|parents}}
*{{he}}: [1] {{Üt|he|הוֹרִים|horim}}
''';

const _teil = '''
== Teil ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{m}}, {{n}} ===
{{Deutsch Substantiv Übersicht
|Genus 1=m
|Genus 2=n
|Nominativ Singular=Teil
|Nominativ Plural 1=Teile
|Nominativ Plural 2=[[Teile]]<ref>Duden</ref>
}}
''';

const _mutter = '''
== Mutter ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{f}}, ''Mütter'' ===
{{Deutsch Substantiv Übersicht
|Genus=f
|Nominativ Singular=Mutter
|Nominativ Plural=Mütter
}}
==== {{Übersetzungen}} ====
{{Ü-Tabelle|1|G=weibliches Elternteil|Ü-Liste=
*{{en}}: {{Ü|en|mother}}
*{{he}}: {{Hebr|אם|v=אֵם|d-heb=ʾēm|Ü}} {{f}}, ''[[Anrede]]:'' {{Hebr|אימא|v=אִמָּא|d-heb=ʾīmāʾ|Ü}} {{f}}
}}
=== {{Wortart|Substantiv|Deutsch}}, {{f}}, ''Muttern'' ===
*{{en}}: {{Ü|en|nut}}
''';

const _hunde = '''
== Hunde ({{Sprache|Deutsch}}) ==
=== {{Wortart|Deklinierte Form|Deutsch}} ===

{{Worttrennung}}
:Hun·de

{{Grammatische Merkmale}}
*Nominativ Plural des Substantivs [[Hund]]
*Genitiv Plural des Substantivs [[Hund]]

{{Grundformverweis Dekl|Hund}}
''';

const _laufen = '''
== laufen ({{Sprache|Deutsch}}) ==
=== {{Wortart|Verb|Deutsch}} ===
''';

const _milch = '''
== Milch ({{Sprache|Deutsch}}) ==
=== {{Wortart|Substantiv|Deutsch}}, {{f}} ===
{{Deutsch Substantiv Übersicht
|Genus=f
|Nominativ Singular=Milch
|Nominativ Plural=—
}}
''';

void main() {
  test('parses gender, plural and only the German translations', () {
    final e = WiktionaryParser.parse('Hund', _hund)!;
    expect(e.genders, [Gender.masculine]);
    expect(e.plurals, ['Hunde']);
    expect(e.english, ['dog', 'hound']);
    expect(e.translationsFor('he'), ['כלב']); // niqqud stripped
    expect(e.translationsFor('fr'), ['chien']);
    expect(e.translations.containsKey('en'), isTrue);
    expect(e.pluralOnly, isFalse);
  });

  test('plural-only nouns', () {
    final e = WiktionaryParser.parse('Eltern', _eltern)!;
    expect(e.pluralOnly, isTrue);
    expect(e.genders, isEmpty);
    expect(e.word, 'Eltern');
    expect(e.isCorrectGuess(Gender.feminine), isTrue);
  });

  test('multiple genders and de-duplicated, cleaned plurals', () {
    final e = WiktionaryParser.parse('Teil', _teil)!;
    expect(e.genders, [Gender.masculine, Gender.neuter]);
    expect(e.plurals, ['Teile']);
    expect(e.isCorrectGuess(Gender.neuter), isTrue);
    expect(e.isCorrectGuess(Gender.feminine), isFalse);
  });

  test('no plural', () {
    final e = WiktionaryParser.parse('Milch', _milch)!;
    expect(e.genders, [Gender.feminine]);
    expect(e.plurals, isEmpty);
  });

  test('Hebrew written with the {{Hebr|...}} script template', () {
    final e = WiktionaryParser.parse('Mutter', _mutter)!;
    expect(e.genders, [Gender.feminine]);
    expect(e.plurals, ['Mütter']);
    expect(e.english, ['mother']); // first noun sense only, not "nut"
    expect(e.translationsFor('he'), ['אם', 'אימא']);
  });

  test('inflected-form pages point to their base noun', () {
    expect(WiktionaryParser.parse('Hunde', _hunde), isNull);
    expect(WiktionaryParser.baseFormOf(_hunde), 'Hund');
    expect(WiktionaryParser.baseFormOf(_hund), isNull);
  });

  test('a typed plural grades article guesses by the plural rule', () {
    final e = WiktionaryParser.parse('Hund', _hund)!.asPluralMatch('Hunde');
    expect(e.word, 'Hund');
    expect(e.typedPlural, 'Hunde');
    expect(e.isCorrectGuess(Gender.feminine), isTrue); // die Hunde
    expect(e.isCorrectGuess(Gender.masculine), isFalse);
    expect(e.asSaved().typedPlural, isNull); // saved as the singular
  });

  test('non-nouns return null', () {
    expect(WiktionaryParser.parse('laufen', _laufen), isNull);
    expect(WiktionaryParser.parse('x', 'no german section'), isNull);
  });
}
