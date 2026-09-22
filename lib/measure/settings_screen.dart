import 'package:flutter/material.dart';

import '../about_screen.dart';
import '../common/caption.dart';
import '../settings.dart';
import '../theme.dart';
import 'units.dart';

/// Theme (System / Light / Dark) and units (Imperial / Metric), both
/// persisted and remembered between launches. About is one tap away.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

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
        title: Caption('SETTINGS', color: palette.onSurface),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionHeader('THEME', palette: palette),
              _Option(
                label: 'System',
                selected: settings.themeMode == ThemeMode.system,
                onTap: () => settings.setThemeMode(ThemeMode.system),
                palette: palette,
              ),
              _Option(
                label: 'Light',
                selected: settings.themeMode == ThemeMode.light,
                onTap: () => settings.setThemeMode(ThemeMode.light),
                palette: palette,
              ),
              _Option(
                label: 'Dark',
                selected: settings.themeMode == ThemeMode.dark,
                onTap: () => settings.setThemeMode(ThemeMode.dark),
                palette: palette,
              ),
              const SizedBox(height: 24),
              _SectionHeader('UNITS', palette: palette),
              _Option(
                label: 'Imperial (ft, in)',
                selected: settings.units == UnitSystem.imperial,
                onTap: () => settings.setUnits(UnitSystem.imperial),
                palette: palette,
              ),
              _Option(
                label: 'Metric (m, cm)',
                selected: settings.units == UnitSystem.metric,
                onTap: () => settings.setUnits(UnitSystem.metric),
                palette: palette,
              ),
              const SizedBox(height: 24),
              Divider(height: 1, indent: 20, endIndent: 20, color: palette.onBase.withValues(alpha: 0.08)),
              ListTile(
                title: Text('About', style: TextStyle(color: palette.onBase)),
                trailing: Icon(Icons.chevron_right_rounded, color: palette.onBaseMuted),
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
  const _SectionHeader(this.text, {required this.palette});

  final String text;
  final Palette palette;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Caption(text, color: palette.onBaseMuted),
        ),
      );
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap, required this.palette});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: TextStyle(color: palette.onBase, fontSize: 16)),
      trailing: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? palette.emphasis : palette.onBaseMuted,
      ),
    );
  }
}
