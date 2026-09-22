import 'package:flutter/material.dart';

import '../common/caption.dart';
import '../theme.dart';
import 'recording.dart';
import 'share_recording.dart';
import 'units.dart';

/// Runs a [ShareChoice] and reports the outcome in a snackbar. Never throws.
Future<void> performShareChoice(
  BuildContext context,
  Recording recording,
  UnitSystem units,
  ShareChoice choice,
) async {
  // Grab the messenger first: the sheet that triggered this may already be closed.
  final messenger = ScaffoldMessenger.of(context);
  final format = choice.format;
  try {
    if (format == null) {
      await copyRecordingText(recording, units);
      messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    } else {
      await shareRecording(recording, units, format);
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not ${format == null ? 'copy' : 'share'}: ${shareErrorMessage(e)}')),
    );
  }
}

/// Overflow menu with every [ShareChoice].
class ShareMenuButton extends StatelessWidget {
  const ShareMenuButton({super.key, required this.onSelected});

  final ValueChanged<ShareChoice> onSelected;

  static IconData _icon(ShareChoice c) => switch (c) {
        ShareChoice.csv => Icons.table_chart_outlined,
        ShareChoice.json => Icons.data_object_rounded,
        ShareChoice.copyText => Icons.content_copy_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return PopupMenuButton<ShareChoice>(
      tooltip: 'Share or copy',
      icon: Icon(Icons.ios_share_rounded, color: palette.onBase, size: 22),
      color: palette.card,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final c in ShareChoice.values)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(_icon(c), size: 18, color: palette.onSurface.withValues(alpha: 0.8)),
                const SizedBox(width: 12),
                Text(c.label),
              ],
            ),
          ),
      ],
    );
  }
}

/// One measurement in full: total, every segment, and the share / copy actions.
/// Used right after a long-press save and when opening an item from History.
class RecordingSheet extends StatelessWidget {
  const RecordingSheet({
    super.key,
    required this.title,
    required this.recording,
    required this.units,
    required this.onChoice,
  });

  final String title;
  final Recording recording;
  final UnitSystem units;
  final ValueChanged<ShareChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final segments = recording.segments;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Caption(title, color: palette.onSurfaceMuted),
              const SizedBox(height: 10),
              Text(
                formatLength(recording.total, units),
                style: TextStyle(color: palette.onSurface, fontSize: 44, fontWeight: FontWeight.w200),
              ),
              const SizedBox(height: 4),
              Text(
                '${recording.points.length} points · ${segments.length} segments · ${formatStamp(recording.createdAt)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < segments.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('${i + 1}', style: TextStyle(color: palette.onSurfaceMuted, fontSize: 13)),
                      ),
                      Text(
                        formatLength(segments[i], units),
                        style: TextStyle(
                          color: palette.onSurface,
                          fontSize: 15,
                          fontFeatures: [...showdistFontFeatures, const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final c in [ShareChoice.csv, ShareChoice.json]) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onChoice(c),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(c.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.onSurface,
                          side: BorderSide(color: palette.onSurface.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    if (c == ShareChoice.csv) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => onChoice(ShareChoice.copyText),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: Text(ShareChoice.copyText.label),
                style: TextButton.styleFrom(foregroundColor: palette.onSurface),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: palette.onSurfaceMuted),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
