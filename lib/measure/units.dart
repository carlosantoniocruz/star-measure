enum UnitSystem { metric, imperial }

/// Formats a length for display. AR tracking is good to about a centimetre,
/// so precision drops as the distance grows.
String formatLength(double meters, UnitSystem system) {
  switch (system) {
    case UnitSystem.metric:
      if (meters < 0.1) return '${(meters * 100).toStringAsFixed(1)} cm';
      if (meters < 1) return '${(meters * 100).round()} cm';
      return '${meters.toStringAsFixed(2)} m';
    case UnitSystem.imperial:
      return _formatImperial(meters);
  }
}

/// Feet and inches, e.g. `4′ 7 1/2″`, rounded to the nearest half inch (about
/// 1.3 cm) — finer than that would claim more precision than the sensor
/// delivers.
String _formatImperial(double meters) {
  final inches = meters / 0.0254;
  final halves = (inches * 2).round().clamp(0, 1 << 30);
  final whole = halves ~/ 2;
  final hasHalf = halves.isOdd;
  final feet = whole ~/ 12;
  final remainder = whole % 12;
  final inchesText = hasHalf ? '$remainder 1/2″' : '$remainder″';
  return feet > 0 ? '$feet′ $inchesText' : inchesText;
}
