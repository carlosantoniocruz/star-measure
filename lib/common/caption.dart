import 'package:flutter/material.dart';

import '../theme.dart';

/// Small letter-spaced label used for section titles and quiet status text.
/// Defaults to the muted tone for whichever surface it's on; pass [color] to
/// override (e.g. the brighter primary tone).
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.size = 12, this.spacing = 3, this.color});

  final String text;
  final double size, spacing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? palette.onBaseMuted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: spacing,
      ),
    );
  }
}
