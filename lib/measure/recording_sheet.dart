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
  final copying = choice == ShareChoice.copyText;
  try {
    if (copying) {
      await copyRecordingText(recording, units);
      messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    } else {
      await shareRecording(recording, units);
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not ${copying ? 'copy' : 'share'}: ${shareErrorMessage(e)}')),
    );
  }
}

/// Overflow menu with every [ShareChoice].
class ShareMenuButton extends StatelessWidget {
  const ShareMenuButton({super.key, required this.onSelected});

  final ValueChanged<ShareChoice> onSelected;

  static IconData _icon(ShareChoice c) => switch (c) {
        ShareChoice.shareText => Icons.ios_share_rounded,
        ShareChoice.copyText => Icons.content_copy_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShareChoice>(
      tooltip: 'Share or copy',
      icon: const Icon(Icons.ios_share_rounded, color: Palette.white, size: 22),
      color: Palette.darkTyrianBlue,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final c in ShareChoice.values)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                Icon(_icon(c), size: 18, color: Palette.white.withValues(alpha: 0.8)),
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
    final segments = recording.segments;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Caption(title, color: Palette.warmGray),
              const SizedBox(height: 10),
              Text(
                formatLength(recording.total, units),
                style: const TextStyle(color: Palette.white, fontSize: 44, fontWeight: FontWeight.w200),
              ),
              const SizedBox(height: 4),
              Text(
                '${recording.points.length} points · ${segments.length} segments',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.warmGray, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < segments.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('${i + 1}', style: const TextStyle(color: Palette.warmGray, fontSize: 13)),
                      ),
                      Text(
                        formatLength(segments[i], units),
                        style: TextStyle(
                          color: Palette.white,
                          fontSize: 15,
                          fontFeatures: [...showdistFontFeatures, const FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => onChoice(ShareChoice.shareText),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(ShareChoice.shareText.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.white,
                  side: BorderSide(color: Palette.white.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => onChoice(ShareChoice.copyText),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: Text(ShareChoice.copyText.label),
                style: TextButton.styleFrom(foregroundColor: Palette.white),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Palette.warmGray),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
