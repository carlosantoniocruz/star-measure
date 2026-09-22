import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'measure/units.dart';

/// App-wide preferences: the unit system, persisted on device and
/// remembered between launches.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._units);

  static const _unitsKey = 'showdist.unit_system';

  final SharedPreferences _prefs;
  UnitSystem _units;

  UnitSystem get units => _units;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Default imperial: feet and inches, not more precise than the AR
    // tracking (roughly a centimetre) can actually back up.
    final units = UnitSystem.values.firstWhere(
      (u) => u.name == prefs.getString(_unitsKey),
      orElse: () => UnitSystem.imperial,
    );
    return AppSettings._(prefs, units);
  }

  Future<void> setUnits(UnitSystem units) async {
    if (units == _units) return;
    _units = units;
    notifyListeners();
    await _prefs.setString(_unitsKey, units.name);
  }
}
