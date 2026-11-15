# Der · Die · Das

A Flutter app for German nouns: type a noun and get its **article (der / die / das)**,
gender, **plural**, the **English** meaning and a translation into a language you pick
(Hebrew by default).

The look comes from [nati-ui-components](https://github.com/natibs/nati-ui-components)
(tokens, input, combobox, card) and the Deutsch-A1 app: a time-of-day gradient
background with a moving sun, a glass header, light/dark themes and a responsive layout
(word on the left, results on the right in landscape and on tablets).

## Features

- **Lookup as you type** (300 ms debounce), with a small loader if the network takes
  longer than 1.2 s.
- **Guess the article**: type "die Hund" and the app tells you whether you were right.
- **Plurals work too**: type "Hunde" or "Gartenzwerge" and the card shows the singular
  (der Hund, der Gartenzwerg) with its article, plus a note that you typed its plural.
- **Any translation language** from a searchable dropdown; the last choice is remembered.
- **Works offline** for about 2,900 common nouns. Anything looked up online is saved, so
  it works offline next time.
- **Offline-friendly**: if a word needs the network and you're offline, you get a
  friendly message and the lookup retries by itself when the connection comes back.
- **Physical keyboard**: Esc clears the input, Ctrl/Cmd+K focuses it.

## How lookups work

1. Saved words and the bundled list (`assets/nouns.json`, common nouns built from
   de.wiktionary.org) are checked first, including a plural → singular index.
2. Otherwise the app reads **de.wiktionary.org**: gender and plural from the
   *Deutsch Substantiv Übersicht* template, translations from `{{Ü|…}}` / `{{Üt|…}}`
   and script templates such as `{{Hebr|…}}`. Inflected-form pages (e.g. "Hunde")
   are followed to their base noun. Swiss `ss` spellings fall back to `ß`.
3. If Wiktionary has no translation for the chosen language, it falls back to
   **MyMemory**, then **LibreTranslate** (only if configured, since the public instance
   needs a key):

   ```
   flutter run --dart-define=LIBRETRANSLATE_URL=https://your-instance --dart-define=LIBRETRANSLATE_KEY=xxxx
   ```

## Run it (Windows)

Double-click a launcher, or run `setup.ps1` directly:

| Launcher         | Command                    | What it does                          |
|------------------|----------------------------|---------------------------------------|
| `run.cmd`        | `setup.ps1`                | Phone-sized Android emulator          |
| `run-tablet.cmd` | `setup.ps1 -Tablet`        | Pixel Tablet emulator                 |
| `run-phone.cmd`  | `setup.ps1 -Phone`         | Connected phone (USB debugging on)    |
|                  | `setup.ps1 -Web`           | Live preview in Chrome                |
|                  | `setup.ps1 -Apk`           | Release APK                           |

The script installs Flutter and the Android SDK/emulator if they're missing, runs the
tests, then starts the app (press `r` in the terminal to hot reload). It logs to
`setup.log`.

On any other setup: `flutter pub get && flutter test && flutter run`.

## Structure

```
lib/theme/     nati tokens (palette, sizes) and light/dark ThemeData
lib/core/      day phases, theme controller, languages, query parsing
lib/data/      noun model, offline dictionary, saved words, Wiktionary client/parser,
               machine translation chain, repository
lib/widgets/   background, glass header, NatiInput/NatiCombobox/NatiButton/NatiCard, noun card
lib/screens/   home screen
tool/          scripts that build assets/nouns.json from Wiktionary
```

## Data and credits

Noun data and translations come from [de.wiktionary.org](https://de.wiktionary.org),
licensed [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Fallback
translations come from [MyMemory](https://mymemory.translated.net).
