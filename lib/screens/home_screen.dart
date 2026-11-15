import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day_phase.dart';
import '../core/languages.dart';
import '../core/text_utils.dart';
import '../core/theme_controller.dart';
import '../data/noun.dart';
import '../data/noun_repository.dart';
import '../data/wiktionary.dart';
import '../theme/nati_tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/nati_controls.dart';
import '../widgets/noun_card.dart';
import '../widgets/time_of_day_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.themeController, required this.prefs});
  final NounRepository repository;
  final ThemeController themeController;
  final SharedPreferences prefs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

sealed class _View {
  const _View();
}

class _Idle extends _View {
  const _Idle();
}

class _Found extends _View {
  const _Found(this.entry, this.guess);
  final NounEntry entry;
  final Gender? guess;
}

class _NotFound extends _View {
  const _NotFound(this.word);
  final String word;
}

class _Offline extends _View {
  const _Offline(this.word);
  final String word;
}

class _HomeScreenState extends State<HomeScreen> {
  static const _recentKey = 'recent';
  static const _languageKey = 'lang';
  final _controller = TextEditingController();
  final _focus = FocusNode();
  _View _view = const _Idle();
  bool _loading = false;
  int _seq = 0;
  List<String> _suggestions = const [];
  late List<String> _recent = widget.prefs.getStringList(_recentKey) ?? const [];
  DayPhase? _previewPhase;
  late Language _language = languageFor(widget.prefs.getString(_languageKey) ?? defaultLanguageCode);
  Timer? _debounce;
  String? _lastQueryKey;
  static const _debounceTime = Duration(milliseconds: 300);

  // Slow-network loader: only shown when a lookup takes longer than this.
  static const _slowAfter = Duration(milliseconds: 1200);
  Timer? _slowTimer;
  bool _slow = false;
  String _pendingWord = '';

  // Offline: retry automatically when the network comes back (no button).
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _offlinePoll;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (_view is _Offline && !results.contains(ConnectivityResult.none)) _retryOffline();
    });
  }

  void _retryOffline() {
    if (_loading || _view is! _Offline) return;
    _lastQueryKey = null;
    _lookup();
  }

  /// Network-change events only say an interface is up, not that the internet
  /// works, so while offline we also quietly re-try every few seconds.
  void _syncOfflinePolling() {
    if (_view is _Offline) {
      _offlinePoll ??= Timer.periodic(const Duration(seconds: 5), (_) => _retryOffline());
    } else {
      _offlinePoll?.cancel();
      _offlinePoll = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _slowTimer?.cancel();
    _offlinePoll?.cancel();
    _connectivity?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final q = parseQuery(text);
    setState(() => _suggestions = q == null ? const [] : widget.repository.suggest(q.word));
    _debounce?.cancel();
    if (q == null) {
      _seq++; // drop any in-flight result
      _lastQueryKey = null;
      _slowTimer?.cancel();
      setState(() {
        _view = const _Idle();
        _loading = false;
        _slow = false;
      });
      _syncOfflinePolling();
      return;
    }
    _debounce = Timer(_debounceTime, _lookup);
  }

  /// [text] set = picked from a chip. Typing goes through the debounce.
  Future<void> _lookup([String? text]) async {
    _debounce?.cancel();
    if (text != null) {
      _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      _focus.unfocus();
      setState(() => _suggestions = const []);
    }
    final q = parseQuery(_controller.text);
    if (q == null) return;
    final key = '${_language.code}|${q.typedArticle?.article ?? ''}|${foldGerman(q.word)}';
    if (key == _lastQueryKey && _view is! _Offline) return; // nothing new
    _lastQueryKey = key;
    final seq = ++_seq;
    // Previous result stays visible while loading (no flicker while typing);
    // the loader only appears if the answer takes longer than _slowAfter.
    _slowTimer?.cancel();
    _pendingWord = q.word;
    _slowTimer = Timer(_slowAfter, () {
      // background retries while offline keep the friendly offline message instead
      if (mounted && seq == _seq && _loading && _view is! _Offline) setState(() => _slow = true);
    });
    setState(() => _loading = true);
    _View next;
    try {
      final entry = await widget.repository.lookup(q.word, language: _language.code);
      next = entry == null ? _NotFound(q.word) : _Found(entry, q.typedArticle);
      if (entry != null) _remember(entry.word);
    } on LookupOfflineException {
      next = _Offline(q.word);
      _lastQueryKey = null; // allow retry
    }
    if (!mounted || seq != _seq) return;
    _slowTimer?.cancel();
    setState(() {
      _view = next;
      _loading = false;
      _slow = false;
    });
    _syncOfflinePolling();
  }

  /// Remembered across launches; re-fetches the current word's translation.
  void _setLanguage(String code) {
    if (code == _language.code) return;
    setState(() => _language = languageFor(code));
    widget.prefs.setString(_languageKey, code);
    if (_view is _Found) {
      _lastQueryKey = null;
      _lookup();
    }
  }

  void _remember(String word) {
    _recent = [word, ..._recent.where((w) => foldGerman(w) != foldGerman(word))].take(8).toList();
    widget.prefs.setStringList(_recentKey, _recent);
  }

  void _clear() {
    _debounce?.cancel();
    _seq++;
    _lastQueryKey = null;
    _controller.clear();
    _slowTimer?.cancel();
    setState(() {
      _loading = false;
      _slow = false;
      _suggestions = const [];
      _view = const _Idle();
    });
    _focus.requestFocus();
    _syncOfflinePolling();
  }

  void _cyclePhase() {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _previewPhase ?? phaseForHour(DateTime.now().hour);
      final next = DayPhase.values[(current.index + 1) % DayPhase.values.length];
      // Wrapping back around to the real phase turns preview off.
      _previewPhase = next == phaseForHour(DateTime.now().hour) ? null : next;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        content: Text(_previewPhase == null ? 'Back to the real time of day' : 'Preview: ${_previewPhase!.name}'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final landscape = size.width > size.height && size.width >= 560;
    // Wide layouts (tablet, landscape, desktop) focus the input on start, so a
    // physical keyboard works right away. Phones in portrait don't, to avoid
    // popping the on-screen keyboard over the page.
    final inputAutofocus = landscape || size.width >= 600;
    final hPad = size.width < 600 ? 16.0 : 24.0;
    final pad = EdgeInsets.fromLTRB(hPad + insets.left, landscape ? 16 : 20, hPad + insets.right, 24 + insets.bottom);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
      // Hardware-keyboard shortcuts: Esc clears, Ctrl/Cmd+K focuses the search.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _clear,
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focus.requestFocus,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focus.requestFocus,
        },
        child: Focus(
          autofocus: !inputAutofocus, // keeps the shortcuts reachable
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(child: TimeOfDayBackground(overridePhase: _previewPhase)),
                Column(
                  children: [
                    AppHeader(
                      onToggleTheme: () => widget.themeController.toggle(Theme.of(context).brightness),
                      onLogoLongPress: _cyclePhase,
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _focus.unfocus(),
                        child: landscape ? _landscape(t, pad, size) : _portrait(t, pad),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switcher(Widget child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_slow ? 'slow' : _view), child: child),
      );

  Widget _portrait(NatiTheme t, EdgeInsets pad) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: pad,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NatiSize.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchCard(t, autofocus: MediaQuery.sizeOf(context).width >= 600),
              const SizedBox(height: 20),
              _switcher(_body(t)),
            ],
          ),
        ),
      ),
    );
  }

  /// Landscape: search + the word on the left, the details on the right.
  Widget _landscape(NatiTheme t, EdgeInsets pad, Size size) {
    final leftWidth = (size.width * 0.4).clamp(280.0, 440.0);
    final view = _view;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftWidth + pad.left,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad.left, pad.top, 0, pad.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _searchCard(t, autofocus: true),
                    const SizedBox(height: 16),
                    _switcher(view is _Found
                        ? NatiCard(
                            accent: nounAccent(t, view.entry),
                            child: NounHeadline(entry: view.entry, guess: view.guess),
                          )
                        : const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(0, pad.top, pad.right, pad.bottom),
                child: _switcher(view is _Found && !_slow
                    ? NatiCard(padding: const EdgeInsets.all(NatiSize.space5), child: NounDetails(entry: view.entry, language: _language))
                    : _body(t)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchCard(NatiTheme t, {bool autofocus = false}) {
    return NatiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NatiInput(
            controller: _controller,
            focusNode: _focus,
            autofocus: autofocus,
            label: 'German noun',
            hint: 'e.g. Hund, Mädchen, die Zeit',
            onChanged: _onChanged,
            onSubmitted: (_) => _lookup(),
            trailing: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                if (_slow) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
                    ),
                  );
                }
                if (_controller.text.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.search_rounded, size: 20, color: t.placeholder),
                  );
                }
                return IconButton(
                  tooltip: 'Clear (Esc)',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  onPressed: _clear,
                  icon: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
                );
              },
            ),
          ),
          const SizedBox(height: NatiSize.space3),
          _languagePicker(t),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _suggestions.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: NatiSize.space3),
                    child: Wrap(
                      spacing: NatiSize.space2,
                      runSpacing: NatiSize.space2,
                      children: [for (final s in _suggestions) NatiChip(label: s, onTap: () => _lookup(s))],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// nati combobox: same look as the noun input, type to filter ("fr" -> French).
  Widget _languagePicker(NatiTheme t) => NatiCombobox<Language>(
        label: 'Translate to',
        hint: 'Type to search languages',
        items: languages,
        selected: _language,
        itemLabel: (l) => l.label,
        leading: Icon(Icons.translate_rounded, size: 18, color: t.textMuted),
        onSelected: (l) => _setLanguage(l.code),
      );

  Widget _body(NatiTheme t) {
    if (_slow) return _SlowLoader(word: _pendingWord);
    return switch (_view) {
      _Found(:final entry, :final guess) => NounCard(entry: entry, guess: guess, language: _language),
      _NotFound(:final word) => _Message(
          icon: Icons.search_off_rounded,
          title: 'No German noun "$word" found',
          text: 'Check the spelling. Nouns are looked up in the singular, so "Hunde" won\'t match but "Hund" will.',
        ),
      _Offline(:final word) => _Message(
          icon: Icons.wifi_off_rounded,
          title: 'You\'re offline',
          text: '"$word" isn\'t saved on this device yet. No worries: it\'ll be looked up '
              'automatically as soon as you\'re back online.',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.textMuted)),
            const SizedBox(width: 10),
            Text('Waiting for a connection…', style: TextStyle(color: t.textMuted, fontSize: NatiSize.fontSm)),
          ]),
        ),
      _Idle() => _IdleView(
          recent: _recent,
          onPick: _lookup,
          offlineCount: widget.repository.offlineCount,
        ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return NatiCard(
      padding: const EdgeInsets.all(NatiSize.space6),
      child: Column(children: [
        Icon(icon, size: 36, color: t.textMuted),
        const SizedBox(height: NatiSize.space3),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
        const SizedBox(height: NatiSize.space2),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.45)),
        if (action != null) ...[const SizedBox(height: NatiSize.space4), action!],
      ]),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.recent, required this.onPick, required this.offlineCount});
  final List<String> recent;
  final ValueChanged<String> onPick;
  final int offlineCount;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    Widget legend(String a, Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(a, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: t.textMuted)),
        ]);

    return NatiCard(
      padding: const EdgeInsets.all(NatiSize.space6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Type a noun to get its article, plural and translations.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
        const SizedBox(height: 6),
        Text('Add an article ("die Hund") to check your guess. '
            '$offlineCount nouns work offline; anything else is looked up online once, then saved.',
            style: TextStyle(color: t.textMuted, height: 1.45)),
        const SizedBox(height: NatiSize.space5),
        Wrap(spacing: 24, runSpacing: 10, children: [
          legend('der', t.der, 'masculine'),
          legend('die', t.die, 'feminine'),
          legend('das', t.das, 'neuter'),
        ]),
        const SizedBox(height: NatiSize.space5),
        Text(recent.isEmpty ? 'TRY' : 'RECENT',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: t.textMuted)),
        const SizedBox(height: NatiSize.space2),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in recent.isEmpty ? const ['Hund', 'Mädchen', 'Apfel', 'Zeit', 'Eltern'] : recent)
            NatiChip(label: w, icon: recent.isEmpty ? null : Icons.history_rounded, onTap: () => onPick(w)),
        ]),
      ]),
    );
  }
}

/// Shown only when a lookup is slower than 1.2 s.
class _SlowLoader extends StatelessWidget {
  const _SlowLoader({required this.word});
  final String word;

  @override
  Widget build(BuildContext context) {
    final t = NatiTheme.of(context);
    return NatiCard(
      padding: const EdgeInsets.symmetric(horizontal: NatiSize.space5, vertical: NatiSize.space4),
      child: Row(children: [
        SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: t.primary)),
        const SizedBox(width: NatiSize.space3),
        Expanded(
          child: Text('Looking up "$word" on Wiktionary…',
              style: TextStyle(color: t.textMuted, fontSize: NatiSize.fontMd)),
        ),
      ]),
    );
  }
}
