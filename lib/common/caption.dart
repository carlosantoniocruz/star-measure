import 'package:flutter/material.dart';

import '../theme.dart';

/// Small letter-spaced label used for section titles and quiet status text.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.size = 12, this.spacing = 3, this.color = Sky.dust});

  final String text;
  final double size, spacing;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600, letterSpacing: spacing),
      );
}
