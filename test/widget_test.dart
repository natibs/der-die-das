// Kept as widget_test.dart so `flutter create .` doesn't generate its default
// counter-app test (which references a MyApp class that doesn't exist here).
import 'dart:io';

import 'package:der_die_das/core/text_utils.dart';
import 'package:der_die_das/data/local_dictionary.dart';
import 'package:der_die_das/data/noun.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseQuery', () {
    test('capitalizes and strips punctuation', () {
      final q = parseQuery('  hund. ')!;
      expect(q.word, 'Hund');
      expect(q.typedArticle, isNull);
    });
    test('captures a typed article', () {
      final q = parseQuery('DIE Mädchen')!;
      expect(q.word, 'Mädchen');
      expect(q.typedArticle, Gender.feminine);
    });
    test('empty input', () {
      expect(parseQuery('   '), isNull);
      expect(parseQuery('das '), isNull);
    });
  });

  group('offline A1 dictionary', () {
    final dict = LocalDictionary.fromJson(File('assets/nouns.json').readAsStringSync());

    test('loads all nouns', () => expect(dict.length, greaterThan(300)));

    test('umlaut plurals', () {
      expect(dict.lookup('Apfel')!.plurals, ['Äpfel']);
      expect(dict.lookup('haus')!.plurals, ['Häuser']);
      expect(dict.lookup('Haus')!.genders, [Gender.neuter]);
    });

    test('ß and ss are interchangeable', () {
      expect(dict.lookup('Fussball')!.word, 'Fußball');
    });

    test('plural lookups find the singular', () {
      expect(dict.lookupPlural('Äpfel')!.word, 'Apfel');
      expect(dict.lookupPlural('häuser')!.word, 'Haus');
      expect(dict.lookupPlural('Hund'), isNull); // a singular is not a plural
      expect(dict.lookupPlural('Lehrer'), isNull); // same in both: found by lookup() instead
    });

    test('suggestions by prefix', () {
      expect(dict.suggest('fam'), contains('Familie'));
    });
  });
}
