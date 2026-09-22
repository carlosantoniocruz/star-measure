import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measure/units.dart';

/// App-wide preferences: theme mode and unit system, persisted on device and
/// remembered between launches.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._themeMode, this._units);

  static const _themeKey = 'showdist.theme_mode';
  static const _unitsKey = 'showdist.unit_system';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  UnitSystem _units;

  ThemeMode get themeMode => _themeMode;
  UnitSystem get units => _units;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    // Default imperial: feet and inches, not more precise than the AR
    // tracking (roughly a centimetre) can actually back up.
    final units = UnitSystem.values.firstWhere(
      (u) => u.name == prefs.getString(_unitsKey),
      orElse: () => UnitSystem.imperial,
    );
    return AppSettings._(prefs, themeMode, units);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setUnits(UnitSystem units) async {
    if (units == _units) return;
    _units = units;
    notifyListeners();
    await _prefs.setString(_unitsKey, units.name);
  }
}
