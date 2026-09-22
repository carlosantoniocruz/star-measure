import 'package:flutter/material.dart';

import 'common/caption.dart';
import 'licenses_screen.dart';
import 'theme.dart';

/// Keep in sync with pubspec.yaml's `version:` — Flutter has no built-in way
/// to read it back at runtime without an extra dependency.
const _appVersion = '1.0.0';

const _developerEmail = 'sh.run.configs@gmail.com';

// Placeholder — replace with an actual developer bio.
const _developerBio = 'Write a short developer bio here.';

/// App info that isn't already on the main menu: version, a developer note,
/// licenses, and a contact address. The main menu already carries the
/// wordmark and a quick-start line for each tool, so neither repeats here.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.darkTyrianBlue,
      appBar: AppBar(
        backgroundColor: Palette.darkTyrianBlue,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Palette.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Caption('SHOWDIST', color: Palette.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          const Center(
            child: Text(
              'Version $_appVersion',
              style: TextStyle(color: Palette.warmGray, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'An augmented-reality tape measure for Android, built with Flutter and ARCore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.warmGray, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Divider(height: 1, color: Palette.white.withValues(alpha: 0.08)),
          const SizedBox(height: 20),
          const Caption('DEVELOPER', color: Palette.warmGray),
          const SizedBox(height: 12),
          const Text(
            _developerBio,
            style: TextStyle(color: Palette.warmGray, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Divider(height: 1, color: Palette.white.withValues(alpha: 0.08)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('View licenses', style: TextStyle(color: Palette.white)),
            subtitle: const Text(
              'Flutter, ARCore, and JetBrains Mono (OFL-1.1)',
              style: TextStyle(color: Palette.warmGray, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Palette.warmGray),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LicensesScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Contact', style: TextStyle(color: Palette.white)),
            subtitle: const SelectableText(
              _developerEmail,
              style: TextStyle(color: Palette.warmGray, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Created with AI assistance',
              style: TextStyle(color: Palette.warmGray, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
