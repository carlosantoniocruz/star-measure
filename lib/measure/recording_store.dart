import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ar_channel.dart';
import 'recording.dart';

/// Recordings persisted as one JSON file in the app's private storage.
/// Newest first.
class RecordingStore extends ChangeNotifier {
  RecordingStore(this._file);

  /// A store that never touches disk, for tests and previews.
  @visibleForTesting
  RecordingStore.inMemory([List<Recording> initial = const []])
      : _file = null,
        _items = List.of(initial);

  final File? _file;
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

  Future<void> remove(String id) => removeMany({id});

  /// Removes every recording whose id is in [ids]. Ids that aren't stored are ignored.
  Future<void> removeMany(Set<String> ids) async {
    final kept = _items.where((r) => !ids.contains(r.id)).toList();
    if (kept.length == _items.length) return;
    _items = kept;
    notifyListeners();
    await _save();
  }

  /// Removes everything.
  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items = [];
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as List;
      _items = [for (final j in data) Recording.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      // Keep an unreadable file for inspection rather than overwriting it.
      await file.rename('${file.path}.corrupt');
      _items = [];
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    // Write then rename so a crash mid-write can't truncate the saved list.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final r in _items) r.toJson()]), flush: true);
    await tmp.rename(file.path);
  }
}
