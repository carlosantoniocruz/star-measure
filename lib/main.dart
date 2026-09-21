import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'intro/egg_intro.dart';
import 'measure/measure_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StarMeasureApp());
}

class StarMeasureApp extends StatelessWidget {
  const StarMeasureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Star Measure',
      debugShowCheckedModeBanner: false,
      theme: Sky.theme(),
      home: Builder(
        builder: (context) => EggIntro(
          onLaunch: () => Navigator.of(context).pushReplacement(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 700),
              pageBuilder: (_, _, _) => const MeasureScreen(),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
