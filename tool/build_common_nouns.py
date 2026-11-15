"""Builds assets/nouns.json: the offline noun list.

Sources (in priority order):
  1. Deutsch-A1 vocabulary (assets/nouns_a1.json) - curated Hebrew/English.
  2. de.wiktionary pages for the most frequent German words
     (tool/wiktionary_cache/*.json, downloaded by tool/fetch_wiktionary.ps1).

Wiktionary entries keep translations for every language (max 2 each), so the
app can translate offline into any language without going online.
The parsing mirrors lib/data/wiktionary.dart.
Usage: python tool/build_common_nouns.py   (run from the project folder)
"""
import glob, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NIQQUD = re.compile('[֑-ׇֽֿׁׂׅׄ]')
LANG_LINE = re.compile(r'^\*:?\s*\{\{([a-z-]{2,12})\}\}(.*)$', re.M)
U_ITEM = re.compile(r'\{\{Ü(?:t|xx\d)?\|([a-z-]{2,12})\|([^|}]+)')
SCRIPT_ITEM = re.compile(r'\{\{(?:Hebr|Arab|Pers|Urdu|Jidd)\|([^|}]+)')


def clean(v):
    v = re.sub(r'<!--.*?-->', '', v, flags=re.S)
    v = re.sub(r'<ref[^>]*/>', '', v)
    v = re.sub(r'<ref[^>]*>.*?</ref>', '', v, flags=re.S)
    v = re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', r'\1', v)
    return v.replace('&nbsp;', ' ').strip()


def is_form(v):
    return v not in ('', '—', '-', '–')


def template_params(text, name):
    start = text.find('{{' + name)
    if start < 0:
        return None
    depth, i, parts, buf = 0, start, [], []
    while i < len(text):
        two = text[i:i + 2]
        if two in ('{{', '[['):
            depth += 1
            if depth > 1: buf.append(two)
            i += 2; continue
        if two in ('}}', ']]'):
            depth -= 1
            if depth == 0: break
            buf.append(two); i += 2; continue
        if text[i] == '|' and depth == 1:
            parts.append(''.join(buf)); buf = []
        else:
            buf.append(text[i])
        i += 1
    parts.append(''.join(buf))
    out = {}
    for p in parts[1:]:
        if '=' in p and p.index('=') > 0:
            k, v = p.split('=', 1)
            out[k.strip()] = v.strip()
    return out


def translations(body, limit):
    out = {}
    def add(code, raw):
        w = clean(raw)
        if code in ('he', 'yi'): w = NIQQUD.sub('', w)
        lst = out.setdefault(code, [])
        if w and w not in lst and len(lst) < limit: lst.append(w)
    for m in LANG_LINE.finditer(body):
        line_code, rest = m.group(1), m.group(2)
        for u in U_ITEM.finditer(rest): add(u.group(1), u.group(2))
        for s in SCRIPT_ITEM.finditer(rest): add(line_code, s.group(1))
    return {k: v for k, v in out.items() if v}


def parse(title, text):
    start = re.search(r'^==[^=].*\(\{\{Sprache\|Deutsch\}\}\).*$', text, re.M)
    if not start: return None
    nxt = re.compile(r'^==[^=].*$', re.M).search(text, start.end())
    section = text[start.start():nxt.start() if nxt else len(text)]
    heads = list(re.finditer(r'^===([^=].*?)===\s*$', section, re.M))
    noun = None
    for i, h in enumerate(heads):
        if '{{Wortart|Substantiv|Deutsch}}' not in h.group(1): continue
        # skip proper names / surnames / toponyms flagged in the same heading
        if re.search(r'Wortart\|(Eigenname|Nachname|Vorname|Toponym)', h.group(1)): continue
        end = heads[i + 1].start() if i + 1 < len(heads) else len(section)
        noun = (h.group(1), section[h.end():end]); break
    if not noun: return None
    heading, body = noun
    params = template_params(body, 'Deutsch Substantiv Übersicht')
    genders = []
    if params:
        for k in sorted(k for k in params if re.fullmatch(r'Genus( \d)?', k)):
            g = params[k].strip()
            if g in 'mfn' and g and g not in genders: genders.append(g)
    if not genders:
        for g in re.findall(r'\{\{([mfn])\}\}', heading):
            if g not in genders: genders.append(g)
    plurals, singular = [], title
    if params:
        for k in sorted(k for k in params if re.fullmatch(r'Nominativ Plural( \d)?', k)):
            v = clean(params[k])
            if is_form(v) and v not in plurals: plurals.append(v)
        sg = params.get('Nominativ Singular') or params.get('Nominativ Singular 1')
        if sg is not None: singular = clean(sg)
    plural_only = params is not None and not is_form(singular) and bool(plurals)
    if not genders and not plural_only: return None
    tr = translations(body, 2)
    en = translations(body, 4).get('en', [])
    tr.pop('en', None); tr.pop('de', None)
    return {
        'word': plurals[0] if plural_only else (singular if is_form(singular) else title),
        'genders': [] if plural_only else genders,
        'plural': None if plural_only else (plurals[0] if plurals else None),
        **({'pluralOnly': True, 'plural': plurals[0]} if plural_only else {}),
        'en': en,
        'tr': tr,
        'src': 'wiktionary',
    }


def main():
    by_key = {}
    pages = 0
    for f in sorted(glob.glob(os.path.join(ROOT, 'tool', 'wiktionary_cache', 'batch_*.json'))):
        data = json.load(open(f, encoding='utf-8'))
        for page in data.get('query', {}).get('pages', []):
            pages += 1
            if page.get('missing') or not page.get('revisions'): continue
            text = page['revisions'][0]['slots']['main']['content']
            e = parse(page['title'], text)
            if e and e['word'][:1].isupper():
                by_key.setdefault(e['word'].lower().replace('ß', 'ss'), e)
    wik = len(by_key)
    for a in json.load(open(os.path.join(ROOT, 'assets', 'nouns_a1.json'), encoding='utf-8')):
        key = a['word'].lower().replace('ß', 'ss')
        base = by_key.get(key)
        merged = {
            'word': a['word'], 'genders': a['genders'], 'plural': a.get('plural'),
            **({'pluralOnly': True} if a.get('pluralOnly') else {}),
            'en': a['en'] or (base or {}).get('en', []),
            'tr': {**((base or {}).get('tr', {})), 'he': a['he']},
            'src': 'a1',
            'complete': base is not None,  # has the full Wiktionary translation table
        }
        by_key[key] = merged
    out = sorted(by_key.values(), key=lambda e: e['word'].lower())
    path = os.path.join(ROOT, 'assets', 'nouns.json')
    json.dump(out, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    he = sum(1 for e in out if e['tr'].get('he'))
    print(f'{pages} pages -> {wik} Wiktionary nouns; {len(out)} total; {he} with Hebrew; {os.path.getsize(path)//1024} KB')


if __name__ == '__main__':
    main()
