"""Converts the Deutsch-A1 vocabulary (content.json) into assets/nouns_a1.json.

fullForm notation in the A1 content:
  Hund /-e (der)        suffix
  Lehrer /-" (der)      plural identical to singular
  Haus /-(ä)er (das)    umlaut the stem vowel, then suffix
  Datum /Daten (das)    full plural form
  Milch (die, Sing.)    no plural
  Eltern (die, Pl.)     plural-only noun
Usage: python3 tool/build_dictionary.py path/to/content.json assets/nouns_a1.json
"""
import json, re, sys

UML = {'a': 'ä', 'o': 'ö', 'u': 'ü', 'A': 'Ä', 'O': 'Ö', 'U': 'Ü'}
FORM = re.compile(r'^(?P<word>[^/()]+?)\s*(?:/(?P<pl>-\([äöü]\)\S*|\S+))?\s*\((?P<art>der|die|das)(?:,\s*(?P<num>Sing|Pl)\.?)?\)\s*$')


def umlaut(word: str) -> str:
    # Umlaut the last a/o/u (and "au" -> "äu"); 'e' in -el/-er endings is skipped naturally.
    for i in range(len(word) - 1, -1, -1):
        c = word[i]
        if c in UML:
            if c in 'uU' and i > 0 and word[i - 1] in 'aA':  # au -> äu
                return word[:i - 1] + UML[word[i - 1]] + word[i:]
            return word[:i] + UML[c] + word[i + 1:]
    return word


def plural(word: str, spec):
    if spec is None:
        return None
    spec = spec.strip()
    if spec in ('-"', '-'):
        return word
    m = re.fullmatch(r'-\((ä|ö|ü)\)(.*)', spec)
    if m:
        return umlaut(word) + m.group(2)
    if spec.startswith('-'):
        return word + spec[1:]
    return spec  # full form, e.g. "Daten"


def main(src, dst):
    vocab = json.load(open(src, encoding='utf-8'))['vocabulary']
    out, seen = [], set()
    for v in vocab:
        m = FORM.match(v['fullForm'].strip())
        if not m:
            continue
        word = m.group('word').strip()
        num = m.group('num')
        entry = {
            'word': word,
            'genders': [{'der': 'm', 'die': 'f', 'das': 'n'}[m.group('art')]],
            'en': [s.strip() for s in v['en'].split('/') if s.strip()],
            'he': [s.strip() for s in v['he'].split(',') if s.strip()],
        }
        if num == 'Pl':
            entry['pluralOnly'] = True
            entry['genders'] = []
            entry['plural'] = word
        elif num == 'Sing':
            entry['plural'] = None
        else:
            entry['plural'] = plural(word, m.group('pl'))
        key = word.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(entry)
    out.sort(key=lambda e: e['word'].lower())
    json.dump(out, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{len(out)} nouns -> {dst}')


if __name__ == '__main__':
    main(*sys.argv[1:3])
