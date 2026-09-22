import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'measure/ar_channel.dart' show arRouteObserver;
import 'menu/main_menu_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  _registerFontLicense();
  final settings = await AppSettings.load();
  runApp(ShowdistApp(settings: settings));
}

/// JetBrains Mono is bundled under the OFL-1.1; this makes its license show
/// up in the standard Flutter "View licenses" page (reached from About).
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['JetBrains Mono'], _jetBrainsMonoOfl);
  });
}

const _jetBrainsMonoOfl = '''
JetBrains Mono is licensed under the SIL Open Font License, Version 1.1.
Copyright 2020 The JetBrains Mono Project Authors
(https://github.com/JetBrains/JetBrainsMono)

Full license text: assets/fonts/JetBrainsMono/OFL.txt
''';

class ShowdistApp extends StatelessWidget {
  const ShowdistApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Showdist',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        navigatorObservers: [arRouteObserver],
        home: MainMenuScreen(settings: settings),
      ),
    );
  }
}
