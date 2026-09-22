import 'package:flutter/material.dart';

import 'common/caption.dart';
import 'common/tick_ring_painter.dart';
import 'theme.dart';

/// Keep in sync with pubspec.yaml's `version:` — Flutter has no built-in way
/// to read it back at runtime without an extra dependency.
const _appVersion = '1.0.0';

const _developerEmail = 'sh.run.configs@gmail.com';

// Placeholder — replace with an actual developer bio.
const _developerBio = 'Write a short developer bio here.';

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
        title: const Caption('ABOUT', color: Palette.white),
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
                child: const CustomPaint(painter: TickRingPainter()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Showdist',
              style: TextStyle(color: Palette.lightMauve, fontSize: 26, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Version $_appVersion',
              style: TextStyle(color: Palette.warmGray, fontSize: 14),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'An augmented-reality tape measure for Android, built with Flutter and ARCore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.warmGray, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          Divider(height: 1, color: Palette.white.withValues(alpha: 0.08)),
          const SizedBox(height: 20),
          const Caption('QUICK START', color: Palette.warmGray),
          const SizedBox(height: 12),
          const _GuideEntry(
            tool: 'Measure',
            body: 'Point the camera at a surface, tap to drop a point, then tap again to drop a '
                "second point and see the distance. Hold anywhere on screen once you've got two "
                'or more points to save the measurement.',
          ),
          const SizedBox(height: 14),
          const _GuideEntry(
            tool: 'Leveler',
            body: 'Hold the phone upright and flat against a wall or whatever you\'re checking. '
                'The dot centres and the ring lights up when you\'re within 0.3° of plumb.',
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
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Showdist',
              applicationVersion: _appVersion,
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

/// One tool's quick-start entry: its name, then a short how-to.
class _GuideEntry extends StatelessWidget {
  const _GuideEntry({required this.tool, required this.body});

  final String tool;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // White, not lightMauve: at this size lightMauve falls short of
          // 4.5:1 on darkTyrianBlue, so weight alone carries the emphasis.
          tool,
          style: const TextStyle(color: Palette.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: Palette.warmGray, fontSize: 13, height: 1.45)),
      ],
    );
  }
}
