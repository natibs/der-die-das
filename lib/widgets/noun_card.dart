import 'package:flutter/material.dart';

import '../data/noun.dart';
import '../core/languages.dart';
import '../theme/app_theme.dart';
import '../theme/nati_tokens.dart';
import 'nati_controls.dart';

Color genderColor(NatiTheme t, Gender g) => switch (g) {
      Gender.masculine => t.der,
      Gender.feminine => t.die,
      Gender.neuter => t.das,
    };

List<Color> nounAccent(NatiTheme t, NounEntry e) =>
    e.pluralOnly ? [t.textMuted] : [for (final g in e.genders) genderColor(t, g)];

/// Portrait: headline + details in one card.
class NounCard extends StatelessWidget {
  const NounCard({super.key, required this.entry, required this.language, this.guess});
  final NounEntry entry;
  final Language language;
  final Gender? guess;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 420;
    return NatiCard(
      accent: nounAccent(t, entry),
      padding: EdgeInsets.all(narrow ? NatiSize.space5 : NatiSize.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NounHeadline(entry: entry, guess: guess),
          const SizedBox(height: NatiSize.space5),
          Divider(height: 1, color: t.border),
          const SizedBox(height: NatiSize.space5),
          NounDetails(entry: entry, language: language),
        ],
      ),
    );
  }
}

/// "der Hund", gender pills and the article-guess verdict.
class NounHeadline extends StatelessWidget {
  const NounHeadline({super.key, required this.entry, this.guess});
  final NounEntry entry;
  final Gender? guess;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final verdict = entry.isCorrectGuess(guess);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One line, scaled down for long compounds (Fahrradschlüssel...).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              if (entry.pluralOnly)
                TextSpan(text: 'die ', style: TextStyle(color: t.textMuted))
              else
                for (var i = 0; i < entry.genders.length; i++) ...[
                  if (i > 0) TextSpan(text: '/', style: TextStyle(color: t.textMuted)),
                  TextSpan(text: entry.genders[i].article, style: TextStyle(color: genderColor(t, entry.genders[i]))),
                  if (i == entry.genders.length - 1) const TextSpan(text: ' '),
                ],
              TextSpan(text: entry.word, style: TextStyle(color: t.text)),
            ]),
            maxLines: 1,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.5),
          ),
        ),
        if (entry.typedPlural != null) ...[
          const SizedBox(height: NatiSize.space2),
          _PluralNote(entry: entry),
        ],
        const SizedBox(height: NatiSize.space3),
        Wrap(
          spacing: NatiSize.space2,
          runSpacing: NatiSize.space2,
          children: [
            if (entry.pluralOnly)
              _Pill(color: t.textMuted, text: 'plural only', he: 'רבים בלבד')
            else
              for (final g in entry.genders) _Pill(color: genderColor(t, g), text: g.label, he: g.labelHe),
          ],
        ),
        if (verdict != null) ...[
          const SizedBox(height: NatiSize.space4),
          _Verdict(correct: verdict, guess: guess!, entry: entry),
        ],
      ],
    );
  }
}

/// Plural / English / Hebrew tiles + source line.
class NounDetails extends StatelessWidget {
  const NounDetails({super.key, required this.entry, required this.language});
  final NounEntry entry;
  final Language language;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 680 ? 3 : (c.maxWidth >= 440 ? 2 : 1);
          const gap = NatiSize.space4;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(width: w, child: _PluralTile(entry: entry)),
              SizedBox(
                width: w,
                child: _Tile(
                  label: 'ENGLISH',
                  machine: entry.machine['en'],
                  child: _Values(values: entry.english, style: TextStyle(fontSize: 19, color: t.text, fontWeight: FontWeight.w500)),
                ),
              ),
              SizedBox(
                width: w,
                child: _Tile(
                  label: language.native,
                  rtl: language.rtl,
                  machine: entry.machine[language.code],
                  child: Directionality(
                    textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: _Values(
                      values: entry.translationsFor(language.code),
                      style: language.code == 'he' || language.code == 'yi'
                          ? hebrewStyle(size: 21, color: t.text)
                          : TextStyle(fontSize: 19, color: t.text, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: NatiSize.space5),
        Text(
          switch (entry.source) {
            NounSource.a1Vocabulary => 'From your Deutsch A1 vocabulary · works offline',
            NounSource.offlineList => 'Offline list · from de.wiktionary.org (CC BY-SA 4.0)',
            NounSource.wiktionary => 'Source: de.wiktionary.org (CC BY-SA 4.0) · saved for offline use',
            NounSource.saved => 'Saved on this device · from de.wiktionary.org (CC BY-SA 4.0)',
          },
          style: TextStyle(fontSize: NatiSize.fontXs, color: t.textMuted),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.text, required this.he});
  final Color color;
  final String text;
  final String he;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: NatiSize.fontSm)),
        Text('  ·  ', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: NatiSize.fontSm)),
        Text(he, textDirection: TextDirection.rtl, style: hebrewStyle(size: 14, weight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// "„Hunde" is the plural of der Hund."
class _PluralNote extends StatelessWidget {
  const _PluralNote({required this.entry});
  final NounEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final base = TextStyle(fontSize: NatiSize.fontMd, color: t.textMuted);
    return Row(children: [
      Icon(Icons.info_outline_rounded, size: 16, color: t.textMuted),
      const SizedBox(width: 6),
      Flexible(
        child: Text.rich(
          TextSpan(style: base, children: [
            TextSpan(text: '„${entry.typedPlural}"', style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
            const TextSpan(text: ' is the plural of '),
            for (var i = 0; i < entry.genders.length; i++) ...[
              if (i > 0) const TextSpan(text: '/'),
              TextSpan(
                text: entry.genders[i].article,
                style: TextStyle(color: genderColor(t, entry.genders[i]), fontWeight: FontWeight.w700),
              ),
            ],
            TextSpan(text: ' ${entry.word}', style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.correct, required this.guess, required this.entry});
  final bool correct;
  final Gender guess;
  final NounEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final color = correct ? t.success : t.danger;
    final plural = entry.pluralOnly || entry.typedPlural != null;
    final right = plural ? 'die' : entry.genders.map((g) => g.article).join(' / ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NatiSize.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            switch ((correct, entry.typedPlural != null)) {
              (true, true) => 'Richtig! Plurals always take "die".',
              (false, true) => 'You wrote "${guess.article}", but plurals always take "die".',
              (true, false) => 'Richtig! "${guess.article}" is correct.',
              (false, false) => 'You wrote "${guess.article}", it\'s "$right".',
            },
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.child, this.rtl = false, this.machine});
  final String label;
  final Widget child;
  final bool rtl;

  /// Translator name when the value is a machine translation.
  final String? machine;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(NatiSize.space4),
      decoration: BoxDecoration(
        color: t.isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(NatiSize.radiusMd),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: rtl
                  ? hebrewStyle(size: 13, weight: FontWeight.w700, color: t.textMuted)
                  : TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: t.textMuted)),
          const SizedBox(height: NatiSize.space2),
          child,
          if (machine != null) ...[
            const SizedBox(height: 6),
            Text('machine translation · $machine',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: NatiSize.fontXs, color: t.textMuted, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _Values extends StatelessWidget {
  const _Values({required this.values, required this.style});
  final List<String> values;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    if (values.isEmpty) {
      return Text('no translation found', style: style.copyWith(fontSize: 15, color: t.textMuted, fontStyle: FontStyle.italic));
    }
    return Text(values.join(', '), style: style);
  }
}

class _PluralTile extends StatelessWidget {
  const _PluralTile({required this.entry});
  final NounEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final big = TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: t.text);
    final caption = TextStyle(fontSize: NatiSize.fontXs, color: t.textMuted);

    final Widget body;
    if (entry.pluralOnly) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(children: [TextSpan(text: 'die ', style: TextStyle(color: t.textMuted)), TextSpan(text: entry.word)]), style: big),
        const SizedBox(height: 4),
        Text('only exists in the plural', style: caption),
      ]);
    } else if (entry.plurals.isEmpty) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('—', style: big),
        const SizedBox(height: 4),
        Text('no plural (singular only)', style: caption),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final p in entry.plurals)
          Text.rich(TextSpan(children: [TextSpan(text: 'die ', style: TextStyle(color: t.textMuted)), TextSpan(text: p)]), style: big),
        const SizedBox(height: 4),
        Text(entry.plurals.first == entry.word ? 'same as singular · plural article is always "die"' : 'plural article is always "die"',
            style: caption),
      ]);
    }
    return _Tile(label: 'PLURAL', child: body);
  }
}
