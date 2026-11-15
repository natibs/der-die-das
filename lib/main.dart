import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme_controller.dart';
import 'data/local_dictionary.dart';
import 'data/machine_translation.dart';
import 'data/noun_repository.dart';
import 'data/saved_words.dart';
import 'data/wiktionary.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final dictionary = await LocalDictionary.load();
  runApp(DerDieDasApp(
    prefs: prefs,
    themeController: ThemeController(prefs),
    repository: NounRepository(
      dictionary,
      WiktionaryClient(),
      saved: SavedWords(prefs),
      translators: TranslatorChain([MyMemoryTranslator(), LibreTranslateTranslator()]),
    ),
  ));
}

class DerDieDasApp extends StatelessWidget {
  const DerDieDasApp({super.key, required this.prefs, required this.themeController, required this.repository});
  final SharedPreferences prefs;
  final ThemeController themeController;
  final NounRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Der Die Das',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: HomeScreen(repository: repository, themeController: themeController, prefs: prefs),
      ),
    );
  }
}
