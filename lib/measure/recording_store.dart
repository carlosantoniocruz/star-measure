import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ar_channel.dart';
import 'recording.dart';

/// Recordings persisted as one JSON file in the app's private storage.
/// Newest first.
class RecordingStore extends ChangeNotifier {
  RecordingStore(this._file);

  final File _file;
  List<Recording> _items = [];

  List<Recording> get items => List.unmodifiable(_items);

  static Future<RecordingStore> open() async {
    final dir = (await ArChannel.dirs()).files;
    return openAt(File('$dir/recordings.json'));
  }

  @visibleForTesting
  static Future<RecordingStore> openAt(File file) async {
    final store = RecordingStore(file);
    await store._load();
    return store;
  }

  Future<void> add(Recording r) async {
    _items = [r, ..._items];
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _items = _items.where((r) => r.id != id).toList();
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    if (!await _file.exists()) return;
    try {
      final data = jsonDecode(await _file.readAsString()) as List;
      _items = [for (final j in data) Recording.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      // Keep an unreadable file for inspection rather than overwriting it.
      await _file.rename('${_file.path}.corrupt');
      _items = [];
    }
  }

  Future<void> _save() async {
    // Write then rename so a crash mid-write can't truncate the saved list.
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final r in _items) r.toJson()]), flush: true);
    await tmp.rename(_file.path);
  }
}
