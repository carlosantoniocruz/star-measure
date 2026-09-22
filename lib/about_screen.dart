import 'package:flutter/material.dart';

import 'common/caption.dart';
import 'common/wordmark_painter.dart';
import 'theme.dart';

/// Keep in sync with pubspec.yaml's `version:` — Flutter has no built-in way
/// to read it back at runtime without an extra dependency.
const _appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.bar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.onSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Caption('ABOUT', color: palette.onSurface),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: const CustomPaint(painter: WordmarkPainter()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Showdist',
              style: TextStyle(color: palette.onBase, fontSize: 26, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version $_appVersion',
              style: TextStyle(color: palette.onBaseMuted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'An augmented-reality tape measure for Android, built with Flutter and ARCore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.onBaseMuted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Divider(height: 1, color: palette.onBase.withValues(alpha: 0.08)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('View licenses', style: TextStyle(color: palette.onBase)),
            subtitle: Text(
              'Flutter, ARCore, and JetBrains Mono (OFL-1.1)',
              style: TextStyle(color: palette.onBaseMuted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: palette.onBaseMuted),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Showdist',
              applicationVersion: _appVersion,
            ),
          ),
        ],
      ),
    );
  }
}
