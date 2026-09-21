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
      final inches = meters / 0.0254;
      if (inches < 12) return '${inches.toStringAsFixed(1)} in';
      final whole = inches.round();
      return '${whole ~/ 12}′ ${whole % 12}″';
  }
}
