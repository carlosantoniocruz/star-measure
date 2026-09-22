import 'package:flutter/material.dart';

import '../about_screen.dart';
import '../common/caption.dart';
import '../settings.dart';
import '../theme.dart';
import 'units.dart';

/// Units (Imperial / Metric), persisted and remembered between launches.
/// About is one tap away.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

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
        title: const Caption('SETTINGS', color: Palette.white),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const _SectionHeader('UNITS'),
              _Option(
                label: 'Imperial (ft, in)',
                selected: settings.units == UnitSystem.imperial,
                onTap: () => settings.setUnits(UnitSystem.imperial),
              ),
              _Option(
                label: 'Metric (m, cm)',
                selected: settings.units == UnitSystem.metric,
                onTap: () => settings.setUnits(UnitSystem.metric),
              ),
              const SizedBox(height: 24),
              Divider(height: 1, indent: 20, endIndent: 20, color: Palette.white.withValues(alpha: 0.08)),
              ListTile(
                title: const Text('About', style: TextStyle(color: Palette.white)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Palette.warmGray),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Caption(text, color: Palette.warmGray),
        ),
      );
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(color: Palette.white, fontSize: 16)),
      trailing: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? Palette.olympicBlue : Palette.warmGray,
      ),
    );
  }
}
