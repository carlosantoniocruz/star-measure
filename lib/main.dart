import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'measure/ar_channel.dart' show arRouteObserver;
import 'measure/recording_store.dart';
import 'menu/main_menu_screen.dart';
import 'settings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  _registerFontLicense();
  final settings = await AppSettings.load();
  final store = await RecordingStore.open();
  runApp(ShowdistApp(settings: settings, store: store));
}

/// JetBrains Mono is bundled under the OFL-1.1; this makes its license show
/// up on the app's own licenses screen (`lib/licenses_screen.dart`, reached
/// from About), alongside every package's own registered license.
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
  const ShowdistApp({super.key, required this.settings, required this.store});

  final AppSettings settings;
  final RecordingStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Showdist',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        navigatorObservers: [arRouteObserver],
        home: MainMenuScreen(settings: settings, store: store),
      ),
    );
  }
}
