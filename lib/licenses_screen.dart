import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common/caption.dart';
import 'theme.dart';

/// Flutter's own `showLicensePage` renders with Material's default colours,
/// not the app's — so this walks [LicenseRegistry] itself instead, in the
/// app's usual AppBar/list style. Cached: every open of this screen within
/// the same run reuses the first walk of the registry.
Future<Map<String, List<LicenseParagraph>>>? _licensesFuture;

Future<Map<String, List<LicenseParagraph>>> _loadLicenses() {
  return _licensesFuture ??= () async {
    final byPackage = <String, List<LicenseParagraph>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).addAll(entry.paragraphs);
      }
    }
    return byPackage;
  }();
}

/// Every package with a registered license, alphabetically. Tap one to read it.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

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
        title: const Caption('LICENSES', color: Palette.white),
      ),
      body: FutureBuilder<Map<String, List<LicenseParagraph>>>(
        future: _loadLicenses(),
        builder: (context, snapshot) {
          final byPackage = snapshot.data;
          if (byPackage == null) {
            return const Center(child: CircularProgressIndicator(color: Palette.lightMauve));
          }
          final packages = byPackage.keys.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: packages.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 20, color: Palette.white.withValues(alpha: 0.08)),
            itemBuilder: (context, i) {
              final package = packages[i];
              return ListTile(
                title: Text(package, style: const TextStyle(color: Palette.white)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Palette.warmGray),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _LicenseDetailScreen(package: package, paragraphs: byPackage[package]!),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One package's full license text.
class _LicenseDetailScreen extends StatelessWidget {
  const _LicenseDetailScreen({required this.package, required this.paragraphs});

  final String package;
  final List<LicenseParagraph> paragraphs;

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
        title: const Caption('LICENSE', color: Palette.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Text(
            package,
            style: const TextStyle(color: Palette.lightMauve, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                p.text,
                textAlign: p.indent == LicenseParagraph.centeredIndent ? TextAlign.center : TextAlign.start,
                style: const TextStyle(color: Palette.white, fontSize: 13, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
